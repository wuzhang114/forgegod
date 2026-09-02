## 战斗播放器 v2(随机战场 · 左右部署 · 六边形棋盘 · HD-2D 氛围)—— B3.7
## 运行: godot --path godot-prototype scenes/battle/battle_demo.tscn
## 流程: 布阵(拖动勇者排兵)→ 开始战斗 → 离线确定性模拟 → 逐 tick 快照 → 播放(变速/暂停/跳结束)。
## 表现: 背景图只提供平整战斗地面与环境；六边形棋盘由程序后置叠加。
##       单位左右分区(中央空列)、纸片人(转向/攻击时绕 Y 轴翻面 + 挥击)、事件飘字、契约 HUD。

extends Node2D

const BattleSim := preload("res://core/runtime/battle_sim.gd")
const DefEntity := preload("res://core/runtime/sim_entity.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")
const Grid := preload("res://core/runtime/hex_grid.gd")

const SRC_BULWARK := """
device 蓄能盾击 {
  budget: { steps: 24, cooldown: 120 }
  state: { charge: 0 }
  on block {
    charge = min(charge + blocked_damage * 0.2, 8)
  }
  on heavy_blow {
    if charge >= 8 {
      damage(target, "impact", 12)
      charge = 0
    }
  }
  on overload {
    if charge >= 4 {
      damage(target, "impact", 30)
      charge = 0
      damage_weapon(4)
    }
  }
}
"""

const HEX_SIZE := 50.0
const Y_SQUASH := 0.54
const BOARD_CENTER := Vector2(640, 430)  # 兜底;实际每张地图用 ground_y(贴地面带)
## 单位统一造型基准: 视觉身高/身宽(局部原点=格心,脚踩在 y=0)
const UNIT_H := 46.0
const UNIT_W := 18.0
const UNIT_HEAD_R := 7.0

## 每张图只承担环境与平整地面，中心棋盘由 _draw_board() 叠加。
const BATTLE_BACKGROUNDS := {
	"forge_courtyard": preload("res://assets/battle/forge-courtyard.png"),
	"ruined_road": preload("res://assets/battle/ruined-road.png"),
	"crystal_mine": preload("res://assets/battle/crystal-mine.png"),
	"autumn_shrine": preload("res://assets/battle/autumn-shrine.png"),
}

## q 是左右列，r 是上下行。每个模板都保留至少 2x3 的双方部署空间，
## gap_q 是中央空列：棋盘会画出该列，但布阵不会把单位放入其中。
const BATTLE_MAPS := [
	{"id": "forge_courtyard", "label": "熔炉庭院", "q_min": 0, "q_max": 8,
		"r_min": 0, "r_max": 4, "player_q_min": 0, "player_q_max": 2,
		"enemy_q_min": 6, "enemy_q_max": 8, "gap_q": 4, "ground_y": 420},
	{"id": "ruined_road", "label": "断垣关道", "q_min": 0, "q_max": 7,
		"r_min": 0, "r_max": 4, "player_q_min": 0, "player_q_max": 1,
		"enemy_q_min": 6, "enemy_q_max": 7, "gap_q": 4, "ground_y": 468},
	{"id": "crystal_mine", "label": "蓝晶矿窟", "q_min": 0, "q_max": 6,
		"r_min": 0, "r_max": 3, "player_q_min": 0, "player_q_max": 1,
		"enemy_q_min": 5, "enemy_q_max": 6, "gap_q": 3, "ground_y": 395},
	{"id": "autumn_shrine", "label": "秋枫神台", "q_min": 0, "q_max": 8,
		"r_min": 0, "r_max": 3, "player_q_min": 0, "player_q_max": 2,
		"enemy_q_min": 6, "enemy_q_max": 8, "gap_q": 4, "ground_y": 434},
]

const HERO_COLORS := {"guard": Color(0.35, 0.65, 1.0), "duelist": Color(1.0, 0.55, 0.2),
	"ranger": Color(0.35, 0.9, 0.5)}
const ENEMY_COLOR := Color(0.75, 0.42, 0.38)

var phase := "deploy"
var sim = null
var snapshots: Array = []
var effects: Array = []
var play_tick := 0
var speed := 1.0
var paused := false
var total_ticks := 0
var ui: Dictionary = {}
var contract_src := ""          # 从 GameSession 读取的契约(若无则内置蓄能盾击)
var contract_name := "蓄能盾击"
var battle_map: Dictionary = {}
var map_rng := RandomNumberGenerator.new()
var background_texture: Texture2D
var board_origin := BOARD_CENTER

## 布阵
var deploy_entities: Array = []
var drag_index := -1
var drag_pos := Vector2.ZERO

## 播放态单位视觉
var unit_nodes: Dictionary = {}      # eid -> UnitNode


func _ready() -> void:
	# 背景和单位都按最近邻采样，保留像素簇的硬边缘。
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ready_contract()
	_build_ui()
	map_rng.randomize()
	_select_battle_map()
	_setup_deploy()
	_process_ui()


## 从会话读契约(全流程);否则用内置演示契约
func _ready_contract() -> void:
	contract_src = SRC_BULWARK
	var Session := preload("res://core/flow/game_session.gd")
	if not Session.divine_contract.is_empty() and str(Session.divine_contract.get("source", "")).strip_edges() != "":
		contract_src = str(Session.divine_contract.source)
		contract_name = "玩家神赐契约"


## ---------------- 坐标 ----------------

func px_of(grid: Vector2i) -> Vector2:
	var p := Grid.to_pixel(grid, HEX_SIZE)
	return board_origin + Vector2(p.x, p.y * Y_SQUASH)


func pick_grid(mouse_px: Vector2) -> Vector2i:
	var best := Vector2i(int(battle_map.get("player_q_min", 0)), int(battle_map.get("r_min", 0)))
	var best_d := INF
	for q in range(int(battle_map.get("q_min", 0)), int(battle_map.get("q_max", 0)) + 1):
		for r in range(int(battle_map.get("r_min", 0)), int(battle_map.get("r_max", 0)) + 1):
			var c := Vector2i(q, r)
			var d := px_of(c).distance_to(mouse_px)
			if d < best_d:
				best_d = d
				best = c
	return best


## ---------------- 布阵 ----------------

func _select_battle_map(index: int = -1) -> void:
	var map_index := index
	if map_index < 0:
		map_index = map_rng.randi_range(0, BATTLE_MAPS.size() - 1)
	battle_map = BATTLE_MAPS[clampi(map_index, 0, BATTLE_MAPS.size() - 1)].duplicate(true)
	background_texture = BATTLE_BACKGROUNDS.get(str(battle_map.id))
	_recenter_board()
	if ui.has("map"):
		ui.map.text = "战场 · " + str(battle_map.label)


func _recenter_board() -> void:
	if battle_map.is_empty():
		board_origin = BOARD_CENTER
		return
	var min_px := Grid.to_pixel(Vector2i(int(battle_map.q_min), int(battle_map.r_min)), HEX_SIZE)
	var max_px := Grid.to_pixel(Vector2i(int(battle_map.q_max), int(battle_map.r_max)), HEX_SIZE)
	var center := Vector2((min_px.x + max_px.x) * 0.5, (min_px.y + max_px.y) * 0.5 * Y_SQUASH)
	# 中心竖坐标跟随该地图的地面带(由背景采样定标),让棋盘与地面贴合
	var ground_y := float(battle_map.get("ground_y", int(BOARD_CENTER.y)))
	board_origin = Vector2(BOARD_CENTER.x, ground_y) - center


func _board_bounds() -> Dictionary:
	return {"q_min": int(battle_map.get("q_min", 0)), "q_max": int(battle_map.get("q_max", 7)),
		"r_min": int(battle_map.get("r_min", 0)), "r_max": int(battle_map.get("r_max", 4))}


func _is_player_cell(g: Vector2i) -> bool:
	return g.x >= int(battle_map.get("player_q_min", 0)) \
			and g.x <= int(battle_map.get("player_q_max", 0)) \
			and g.y >= int(battle_map.get("r_min", 0)) \
			and g.y <= int(battle_map.get("r_max", 4))


func _is_enemy_cell(g: Vector2i) -> bool:
	return g.x >= int(battle_map.get("enemy_q_min", 0)) \
			and g.x <= int(battle_map.get("enemy_q_max", 0)) \
			and g.y >= int(battle_map.get("r_min", 0)) \
			and g.y <= int(battle_map.get("r_max", 4))


func _is_gap_cell(g: Vector2i) -> bool:
	return g.x == int(battle_map.get("gap_q", -999))

func _setup_deploy() -> void:
	if battle_map.is_empty():
		_select_battle_map(0)
	var pq := int(battle_map.player_q_min)
	var eq := int(battle_map.enemy_q_min)
	var r_min := int(battle_map.r_min)
	var r_max := int(battle_map.r_max)
	var r_mid := floori(float(r_min + r_max) / 2.0)
	deploy_entities = [
		# 默认 2 前排 + 1 后排，全部落在左侧 2x3 部署区内。
		{"id": "hero_1", "role": "guard", "name": "守卫·布兰特", "grid": Vector2i(pq + 1, r_mid)},
		{"id": "hero_2", "role": "duelist", "name": "连击手·莉娅", "grid": Vector2i(pq, r_mid)},
		{"id": "hero_3", "role": "ranger", "name": "射手·锡拉", "grid": Vector2i(pq, r_min)},
	]
	var enemy_cells := [
		Vector2i(eq, r_min), Vector2i(eq + 1, r_min),
		Vector2i(eq, r_mid), Vector2i(eq + 1, r_mid),
		Vector2i(eq + 1, r_max),
	]
	for i in enemy_cells.size():
		deploy_entities.append({"id": "enemy_%d" % (i + 1), "role": "brute",
			"name": "石甲傀儡 %d" % (i + 1), "grid": enemy_cells[i]})
	phase = "deploy"


func _input(event: InputEvent) -> void:
	if phase != "deploy":
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if drag_index >= 0:
			var e: Dictionary = deploy_entities[drag_index]
			var g := pick_grid(get_viewport().get_mouse_position())
			if _is_player_cell(g) and not _is_gap_cell(g) and not _deploy_occupied(g):
				e.grid = g
			drag_index = -1
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in deploy_entities.size():
			var e: Dictionary = deploy_entities[i]
			if not e.id.begins_with("hero_"):
				continue
			if px_of(e.grid).distance_to(event.position) < 40.0:
				drag_index = i
				break
		queue_redraw()
	elif event is InputEventMouseMotion and drag_index >= 0:
		queue_redraw()


func _deploy_occupied(g: Vector2i) -> bool:
	for e in deploy_entities:
		if e.grid == g:
			return true
	return false


func _begin_battle() -> void:
	sim = BattleSim.new(7)
	sim.configure_board(_board_bounds())
	for e in deploy_entities:
		sim.add_entity(_make_entity(e))
	var ast := Parser.new().parse(contract_src)
	var checked := Checker.new().check(ast.ast)
	sim.add_contract("c_bulwark", checked.ast, "hero_1",
		{"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []})
	sim.run(2400)
	total_ticks = maxi(sim.tick, 1)
	effects = sim.events.duplicate(true)
	# 快照重放(末尾一条为"结算收尾"状态: 存活单位回到站姿)
	var run := BattleSim.new(7)
	run.configure_board(_board_bounds())
	for e in deploy_entities:
		run.add_entity(_make_entity(e))
	run.add_contract("c_bulwark", checked.ast, "hero_1",
		{"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []})
	snapshots = []
	# 清理上一次战斗残留的纸片人(重开战斗时必须释放旧节点,否则幽灵残影叠加)
	for u in unit_nodes.values():
		if is_instance_valid(u):
			u.queue_free()
	unit_nodes = {}
	for _t in range(total_ticks):
		run.tick_once()
		snapshots.append(_snap_of(run))
	run._settle_all()
	snapshots.append(_snap_of(run))
	# 创建纸片人(guard 使用精灵素材,其余程序绘制)
	for eid in snapshots[0].keys():
		if eid.begins_with("__"):
			continue
		var role: String = snapshots[0][eid].get("role", "")
		var col: Color = HERO_COLORS.get(role, ENEMY_COLOR)
		var u = UnitNode.new(eid, col, px_of(snapshots[0][eid].grid), _sprite_for(eid, role))
		add_child(u)
		unit_nodes[eid] = u
	# 时间轴范围 = 实际战斗长度
	if ui.has("slider"):
		ui.slider.max_value = total_ticks
		ui.slider.set_value_no_signal(0)
	phase = "playing"


## 生成单帧快照
func _snap_of(run_) -> Dictionary:
	var snap := {}
	for e in run_.entities.values():
		snap[e.id] = {"grid": e.grid, "hp": e.hp, "max_hp": e.max_hp,
			"phase": e.current_action.get("phase", ""),
			"tag": e.current_action.get("tag", ""),
			"alive": e.alive, "role": e.get("role", "")}
	snap["__contract"] = {}
	if run_.contracts.has("c_bulwark"):
		snap["__contract"]["charge"] = float(run_.contracts["c_bulwark"].vm.get_state().get("charge", 0.0))
	return snap


func _make_entity(e: Dictionary) -> Dictionary:
	var is_hero: bool = e.id.begins_with("hero_")
	var role: String = e.role
	var Bal := preload("res://core/config/balance.gd")
	var opt: Dictionary = Bal.hero_tpl(role) if is_hero else Bal.enemy_tpl(role)
	opt = opt.duplicate()
	opt.grid = e.grid
	return DefEntity.make(e.id, ("hero" if is_hero else "enemy"),
		("player" if is_hero else "enemy"), e.name, role, opt)


## ---------------- 播放 ----------------

var _acc := 0.0


func _process(delta: float) -> void:
	if phase == "playing" and not paused and play_tick < total_ticks:
		_acc += delta * speed
		while _acc >= 0.05 and play_tick < total_ticks:
			_acc -= 0.05
			play_tick += 1
			_update_units()
			_dispatch_effects(play_tick)
		if ui.has("slider") and ui.slider.value != play_tick:
			ui.slider.set_value_no_signal(play_tick)
	_process_ui()
	queue_redraw()


## 重放: 跳转到任意 tick(立即刷新单位与特效,不播移动动画;跳转即暂停,便于细看)
func _set_tick(t: int) -> void:
	paused = true
	play_tick = clampi(t, 0, total_ticks)
	_update_units(false)
	_dispatch_effects(play_tick)


func _update_units(animate: bool = true) -> void:
	if snapshots.is_empty():
		return
	var snap: Dictionary = snapshots[clampi(play_tick, 0, snapshots.size() - 1)]
	for eid in unit_nodes.keys():
		var u = unit_nodes[eid]
		var e: Dictionary = snap.get(eid, {})
		if e.is_empty():
			continue
		u.sync(e, px_of(e.grid), animate)


func _dispatch_effects(t: int) -> void:
	for ev in effects:
		if int(ev.get("tick", -1)) == t:
			_add_effect(ev)


func _add_effect(ev: Dictionary) -> void:
	var kind: String = ev.get("kind", "")
	var pos := _px_of_eid(ev.get("target_id", ""))
	match kind:
		"attack":
			if ev.get("hit_landed", 0) == 0:
				_float(pos, "MISS", Color(0.85, 0.85, 0.85))
			elif ev.get("blocked", false):
				_float(pos, "格挡!", Color(0.6, 0.9, 1.0))
			else:
				_float(pos, "-%d" % int(ev.get("final_damage", 0.0)), Color(1.0, 0.45, 0.35))
		"mechanic_damage":
			_float(pos, "-%d" % int(ev.get("amount", 0.0)), Color(1.0, 0.8, 0.2))
		"kill":
			_float(pos, "击倒!", Color(1.0, 0.4, 0.8))
		"interrupt":
			_float(pos, "打断!", Color(0.95, 0.5, 1.0))
		"armor_break":
			_float(pos, "破甲!", Color(1.0, 0.7, 0.4))
		"status_apply":
			_float(pos, "+" + str(ev.get("status", "")), Color(0.9, 0.6, 0.4))
		"projectile_launch":
			_spawn_projectile_fx(ev)


## 弹道飞行表现: 金矢从发射格滑向目标格(飞行时长与 sim 一致)
func _spawn_projectile_fx(ev: Dictionary) -> void:
	var from: Vector2 = px_of(ev.get("from", Vector2i.ZERO))
	var to: Vector2 = px_of(ev.get("to", Vector2i.ZERO))
	var flight := maxf(float(ev.get("flight", 4)), 1.0) / 20.0  # tick -> 秒
	var proj := ProjFX.new()
	proj.position = from
	proj.rotation = (to - from).angle()
	ui.layer.add_child(proj)
	var tw := create_tween()
	tw.tween_property(proj, "position", to, flight).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(proj.queue_free)


## 弹道节点: 金箭头(短尾线 + 箭头)
class ProjFX:
	extends Node2D
	var color := Color(1.0, 0.85, 0.4)

	func _init() -> void:
		z_index = 12

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 3.5, color)
		draw_line(Vector2(-4, 0), Vector2(-15, 0), color, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(5, 0), Vector2(-1, -3.5), Vector2(-1, 3.5)]), color)


func _px_of_eid(eid: String) -> Vector2:
	if snapshots.is_empty():
		return board_origin
	var snap: Dictionary = snapshots[clampi(play_tick, 0, snapshots.size() - 1)]
	var e: Dictionary = snap.get(eid, {})
	if e.is_empty():
		return board_origin
	return px_of(e.grid)


func _float(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.position = pos + Vector2(-24, -38)
	ui.layer.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -36), 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


## ---------------- 绘制(背景/棋盘/布阵单位) ----------------

func _draw() -> void:
	_draw_hd2d_bg()
	_draw_board()
	if phase == "deploy":
		_draw_deploy_units()


func _draw_hd2d_bg() -> void:
	if background_texture:
		# 生成素材为 3:2，采用 cover 裁切填满 16:9 视口，避免横向拉伸。
		var viewport_size := Vector2(1280, 720)
		var texture_size := Vector2(background_texture.get_size())
		var scale := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
		var draw_size := texture_size * scale
		var draw_pos := (viewport_size - draw_size) * 0.5
		draw_texture_rect(background_texture, Rect2(draw_pos, draw_size), false,
			Color(1.0, 1.0, 1.0, 0.92))
	else:
		# 资源缺失时保留一个不影响布局的平整地面兜底。
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0.12, 0.1, 0.12))
		draw_rect(Rect2(Vector2(0, 250), Vector2(1280, 470)), Color(0.24, 0.19, 0.14))


func _draw_board() -> void:
	# 只画六边形(无大矩形底框)
	for q in range(int(battle_map.get("q_min", 0)), int(battle_map.get("q_max", 7)) + 1):
		for r in range(int(battle_map.get("r_min", 0)), int(battle_map.get("r_max", 4)) + 1):
			var c := Vector2i(q, r)
			var p := px_of(c)
			var pts := _hex_pts(p)
			var base := Color(0.33, 0.28, 0.22, 0.48) if (q + r) % 2 == 0 \
				else Color(0.27, 0.24, 0.2, 0.48)
			if _is_player_cell(c):
				base = Color(0.22, 0.42, 0.65, 0.42)
			elif _is_enemy_cell(c):
				base = Color(0.58, 0.27, 0.25, 0.42)
			elif _is_gap_cell(c):
				base = Color(0.16, 0.15, 0.16, 0.32)
			draw_colored_polygon(pts, base)
			var edge := Color(0.7, 0.82, 0.95, 0.56) if _is_player_cell(c) \
				else Color(0.95, 0.62, 0.52, 0.56) if _is_enemy_cell(c) \
				else Color(0.76, 0.7, 0.58, 0.32)
			draw_polyline(pts, edge, 1.0)


func _hex_pts(p: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		var ang := deg_to_rad(60.0 * i - 30.0)
		out.append(p + Vector2(cos(ang), sin(ang) * Y_SQUASH) * (HEX_SIZE - 2.0))
	return out


func _draw_deploy_units() -> void:
	for e in deploy_entities:
		var p := px_of(e.grid)
		var is_hero: bool = e.id.begins_with("hero_")
		var col: Color = HERO_COLORS.get(e.role, ENEMY_COLOR) if is_hero else ENEMY_COLOR
		if drag_index >= 0 and deploy_entities[drag_index].id == e.id:
			p = get_viewport().get_mouse_position()
		# 与战斗纸片人同一造型基准: 脚底=格心(y=0),头在肩上方
		var head_y := -(UNIT_H - UNIT_HEAD_R)               # 头圆心
		var body_top := -(UNIT_H - UNIT_HEAD_R) + UNIT_HEAD_R - 2.0  # 肩下 2px
		var body_h := UNIT_H - UNIT_HEAD_R - 5.0
		draw_circle(p + Vector2(0, head_y), UNIT_HEAD_R, col.darkened(0.15))
		draw_rect(Rect2(p + Vector2(-UNIT_W / 2.0, body_top), Vector2(UNIT_W, body_h)), col)
		draw_rect(Rect2(p + Vector2(-UNIT_W / 2.0, body_top), Vector2(UNIT_W, body_h)), Color(0, 0, 0, 0.5), false, 1.0)


## 角色精灵素材(守卫已接入;后续可按角色扩充)
const SPRITES := {
	"guard": preload("res://assets/battle/hero-guard.png"),
}


func _sprite_for(eid: String, role: String) -> Texture2D:
	if eid.begins_with("hero_") and SPRITES.has(role):
		return SPRITES[role]
	return null


## ---------------- 纸片人单位节点 ----------------

class UnitNode:
	extends Node2D
	var eid := ""
	var color: Color
	var facing := 1.0
	var grid := Vector2i.ZERO
	var hp_ratio := 1.0
	var max_hp := 1.0
	var phase := ""
	var tag := ""
	var alive := true
	var bob := 0.0
	var texture: Texture2D = null
	var mv_tween: Tween = null

	func _init(id: String, c: Color, p: Vector2, tex: Texture2D = null) -> void:
		eid = id
		color = c
		texture = tex
		z_index = 10
		position = p

	func sync(e: Dictionary, px: Vector2, animate: bool = true) -> void:
		hp_ratio = clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
		max_hp = e.max_hp
		phase = e.phase
		tag = e.tag
		alive = e.alive
		# 死亡单位彻底隐藏(重放时同样生效)
		visible = alive
		# 仅当位置即将被重新定义(换格/跳转)才杀在途 tween;
		# 播放中的静止 sync 必须放行动画,否则移动 tween 会在起步 1 tick 后被冻结(单位卡在两格之间)
		if e.grid != grid:
			if mv_tween and mv_tween.is_valid():
				mv_tween.kill()
				mv_tween = null
			var dir := 1.0 if e.grid.x >= grid.x else -1.0
			if dir != facing:
				_flip()
			grid = e.grid
			if animate:
				mv_tween = create_tween()
				mv_tween.tween_property(self, "position", px, 0.22).set_trans(Tween.TRANS_SINE)
			else:
				position = px
		elif not animate:
			if mv_tween and mv_tween.is_valid():
				mv_tween.kill()
				mv_tween = null
			position = px
		queue_redraw()

	func _flip() -> void:
		# 纸片翻面: scale.x 1 -> 0.12 -> -1(绕竖轴)
		var target := 1.0 if facing < 0 else -1.0
		facing = target
		var tw := create_tween()
		tw.tween_property(self, "scale:x", 0.12 * facing, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(self, "scale:x", 1.0 * facing, 0.1).set_trans(Tween.TRANS_QUAD)

	func _draw() -> void:
		if not alive:
			return
		# 待机浮动(纸片呼吸,轻微,脚底基本不离地)
		bob = sin(Time.get_ticks_msec() * 0.004) * 1.0
		var base_y := bob
		# 攻击摆动
		var rot := 0.0
		if phase == "active":
			rot = sin(Time.get_ticks_msec() * 0.03) * 0.35
		elif phase == "windup":
			rot = -0.15
		# 统一基准: 局部原点=格心,脚底=y0,身高 UNIT_H(与布阵占位一致)
		draw_set_transform(Vector2(0, base_y), rot, Vector2.ONE)
		if texture != null:
			var tsize := Vector2(texture.get_size())
			var target_h := UNIT_H
			var target_w := tsize.x * (target_h / tsize.y)
			draw_texture_rect(texture, Rect2(Vector2(-target_w / 2.0, -target_h), Vector2(target_w, target_h)), false)
			# 攻击挥击流光(肩部高度)
			if phase == "active":
				draw_line(Vector2(12 * facing, -30), Vector2(26 * facing, -18), Color(1.0, 0.85, 0.4), 2.0)
		else:
			# 头(肩上方)
			var head_y := -(UNIT_H - UNIT_HEAD_R)
			draw_circle(Vector2(0, head_y), UNIT_HEAD_R, color.darkened(0.15))
			# 身体: 脚底=格心(y=0);攻击时压缩/拉长都保持脚踩原地
			var h := UNIT_H - UNIT_HEAD_R - 5.0
			var body_top := -h
			if phase == "windup":
				h = h - 8.0
				body_top = -h
			elif phase == "active":
				h = UNIT_H - 8.0
				body_top = -h
			draw_rect(Rect2(Vector2(-UNIT_W / 2.0, body_top), Vector2(UNIT_W, h)), color)
			draw_rect(Rect2(Vector2(-UNIT_W / 2.0, body_top), Vector2(UNIT_W, h)), Color(0, 0, 0, 0.5), false, 1.0)
			# 武器(朝向侧,持于肩下)
			var wx := 10.0 * facing
			var shoulder_y := head_y + UNIT_HEAD_R - 1.0
			draw_line(Vector2(wx, shoulder_y + 6.0), Vector2(wx + 14 * facing, shoulder_y),
				Color(0.85, 0.8, 0.7), 2.5)
			if phase == "active":
				draw_line(Vector2(wx + 14 * facing, shoulder_y), Vector2(wx + 20 * facing, shoulder_y + 14.0),
					Color(1.0, 0.85, 0.4), 2.0)
		if tag == "block" and phase == "active":
			draw_circle(Vector2(12 * facing, -26), 9.0, Color(0.6, 0.85, 1.0, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 血条(头顶上方,不随体摆动)
		var bar_y := -UNIT_H - 6.0
		draw_rect(Rect2(Vector2(-15, bar_y), Vector2(30, 4)), Color(0.1, 0.08, 0.1))
		var hc := Color(0.9, 0.3, 0.3) if color == ENEMY_COLOR else Color(0.3, 0.9, 0.4)
		draw_rect(Rect2(Vector2(-15, bar_y), Vector2(30 * hp_ratio, 4)), hc)


## ---------------- UI ----------------

func _build_ui() -> void:
	ui.layer = Node2D.new()
	add_child(ui.layer)
	var bar := PanelContainer.new()
	bar.position = Vector2(24, 630)
	add_child(bar)
	var hbox := HBoxContainer.new()
	bar.add_child(hbox)
	var add_btn := func(txt: String, cb: Callable) -> void:
		var b := Button.new()
		b.text = txt
		b.pressed.connect(cb)
		hbox.add_child(b)
	add_btn.call("开始战斗", _begin_battle)
	add_btn.call("随机换战场", func():
		if phase == "deploy":
			_select_battle_map()
			_setup_deploy()
			queue_redraw())
	add_btn.call("0.5×", func(): speed = 0.5)
	add_btn.call("1×", func(): speed = 1.0)
	add_btn.call("2×", func(): speed = 2.0)
	add_btn.call("暂停/继续", func(): paused = not paused)
	# 重放控制
	add_btn.call("⏮ 开头", func(): _set_tick(0))
	add_btn.call("⏪ -3s", func(): _set_tick(play_tick - 60))
	add_btn.call("⏩ +3s", func(): _set_tick(play_tick + 60))
	add_btn.call("跳到结束", func(): _set_tick(total_ticks))
	add_btn.call("← 返回铁匠铺", func():
		get_tree().change_scene_to_file("res://scenes/forge/forge_scene.tscn"))
	# 时间轴滑杆(重放: 拖动任意跳转)
	ui.slider = HSlider.new()
	ui.slider.min_value = 0.0
	ui.slider.max_value = 2400.0
	ui.slider.step = 1.0
	ui.slider.custom_minimum_size = Vector2(900, 20)
	ui.slider.value_changed.connect(func(v: float) -> void:
		paused = true
		_set_tick(int(v)))
	ui.slider.position = Vector2(24, 550)
	add_child(ui.slider)
	ui.status = Label.new()
	ui.status.position = Vector2(24, 605)
	add_child(ui.status)
	ui.tip = Label.new()
	ui.tip.text = "布阵阶段: 拖动勇者到左侧蓝区，中央列留空"
	ui.tip.position = Vector2(24, 583)
	ui.tip.modulate = Color(0.85, 0.85, 0.85)
	add_child(ui.tip)
	ui.title = Label.new()
	ui.title.text = "B3.7 随机战场 · 左右部署 · 自走棋战斗"
	ui.title.position = Vector2(24, 12)
	add_child(ui.title)
	ui.map = Label.new()
	ui.map.position = Vector2(1030, 14)
	ui.map.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.map.custom_minimum_size = Vector2(220, 24)
	add_child(ui.map)
	ui.contract = Label.new()
	ui.contract.position = Vector2(950, 42)
	add_child(ui.contract)


func _process_ui() -> void:
	if ui.is_empty():
		return
	if phase == "playing":
		var st := "进行中…"
		if play_tick >= total_ticks:
			st = "战斗结束: " + str(sim.battle_result)
		ui.status.text = "tick %d/%d · %s · ×%s" % [play_tick, total_ticks, st, str(speed)]
		var charge := 0.0
		if not snapshots.is_empty():
			var snap: Dictionary = snapshots[clampi(play_tick, 0, snapshots.size() - 1)]
			charge = float(snap.get("__contract", {}).get("charge", 0.0))
		ui.contract.text = "【蓄能盾击】储能 %.1f/8" % charge
		# 重放提示
		ui.tip.text = "拖动下方时间轴可回看任意时刻(自动暂停);⏮/⏪/⏩ 跳跃浏览"
	else:
		ui.status.text = "布阵阶段: 左侧部署区 2×3 起步 · 中央空列 · 右侧敌方部署区"
		ui.contract.text = ""
