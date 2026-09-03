## 出征场景: 杀戮尖塔式分支地图(每层多节点,选择一条路线前进)。
## 节点类型: 战斗 / 精英 / 事件 / 篝火 / 宝箱 / 首领;敌人随层数变强(ExpeditionRules)。
## 战斗与远征通过 run.expedition 接缝: 本场景写 awaiting_battle,战斗场景回写 battle_result。
## 状态全部在 RunState.expedition(唯一事实来源),场景只做输入与渲染。

extends Control

const ExpeditionMap := preload("res://domain/expedition/expedition_map.gd")
const ExpeditionRules := preload("res://domain/expedition/expedition_rules.gd")
const EnemyPacks := preload("res://domain/battle/enemy_packs.gd")

const FLOOR_NAMES := ["山脚小径", "岔路林地", "断垣荒坡", "山脊关道", "隘口残垒", "熔核之巢"]
const FLOOR_COLORS := [
	Color("6f7a55"), Color("8a7a4d"), Color("7a5f52"),
	Color("5f6a7a"), Color("7a5252"), Color("b06030"),
]
const TYPE_COLORS := {
	"combat": Color("a8433a"), "elite": Color("7a4a9a"), "event": Color("a8833a"),
	"rest": Color("44708f"), "treasure": Color("9a7d34"), "boss": Color("b05a30"),
}

var node_pos: Dictionary = {}     # node_id -> Vector2(屏幕坐标)
var node_buttons: Dictionary = {} # node_id -> Button
var modal_panel: PanelContainer = null
var modal_content: VBoxContainer = null
var info_label: Label = null
var title_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	var run = GameApp.run
	# 没有进行中的远征 -> 开一张新图(种子: run seed + 天数)
	if not run.expedition.has("active") or not bool(run.expedition.get("active", false)):
		_start_expedition(run)
	# 战斗归来 -> 先处理结果
	if str(run.expedition.get("battle_result", "")) != "":
		_handle_battle_back()
	_build_ui()
	_refresh_nodes()
	_refresh_info()
	queue_redraw()


func _draw() -> void:
	# 远征氛围: 夜空渐变 + 远山剪影 + 底层雪地
	draw_rect(Rect2(Vector2.ZERO, size), Color("131622"))
	for i in range(9):
		var t := float(i) / 8.0
		var y0 := 90.0 + t * 40.0
		var col := Color(0.12, 0.15, 0.22).lerp(Color(0.2, 0.22, 0.3), t)
		draw_rect(Rect2(0, y0, size.x, 60.0), col)
	# 远山
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 260), Vector2(180, 170), Vector2(360, 250), Vector2(560, 160),
		Vector2(760, 255), Vector2(980, 165), Vector2(1200, 250), Vector2(1280, 240), Vector2(1280, 340), Vector2(0, 340)]),
		Color("1d2233"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 330), Vector2(300, 250), Vector2(620, 320), Vector2(940, 255), Vector2(1280, 315), Vector2(1280, 420), Vector2(0, 420)]),
		Color("232a3d"))
	draw_rect(Rect2(0, 400, size.x, size.y - 400), Color("1a1d2a"))
	# 地图顶栏底线
	draw_line(Vector2(0, 64), Vector2(size.x, 64), Color("b8794d"), 2.0)
	# 节点连线
	_draw_edges()


func _draw_edges() -> void:
	var map_data: Dictionary = GameApp.run.expedition.get("map", {})
	var done: Dictionary = GameApp.run.expedition.get("done", {})
	for e in map_data.get("edges", []):
		var a: Vector2 = node_pos.get(str(e.from), Vector2(-999, -999))
		var b: Vector2 = node_pos.get(str(e.to), Vector2(-999, -999))
		if a.x < -100 or b.x < -100:
			continue
		var lit := done.has(str(e.from)) and done.has(str(e.to))
		var col := Color(0.9, 0.7, 0.35, 0.85) if lit else Color(0.45, 0.42, 0.5, 0.4)
		draw_line(a, b, col, 3.0 if lit else 1.5)


## ---------------- 状态 ----------------

func _start_expedition(run) -> void:
	var seed_value := int(run.run_seed) + int(run.current_day) * 97
	run.expedition = {
		"active": true,
		"map": ExpeditionMap.generate(seed_value),
		"floor": 1,
		"done": {},
		"awaiting_battle": "",
		"battle_result": "",
		"battle_floor": 1,
		"battle_type": "combat",
		"last_report": {},
		"outcome": "",
	}


func _handle_battle_back() -> void:
	var run = GameApp.run
	var res := str(run.expedition.get("battle_result", "timeout"))
	var node_id := str(run.expedition.get("awaiting_battle", ""))
	run.expedition["battle_result"] = ""
	run.expedition["awaiting_battle"] = ""
	if node_id == "":
		return
	var out: Dictionary = ExpeditionRules.resolve_battle(run, res, node_id, run.expedition.get("map", {}))
	match str(out.get("type", "none")):
		"won":
			_show_modal("战斗胜利", "%s\n\n金币 +%.0f\n声望 +%.0f\n\n部队向第 %d 层进发。" % [
				str(out.get("text", "")), float(out.money), float(out.reputation), int(out.get("floor", 2))],
				[["继续行进", func() -> void: _close_modal()]])
		"victory":
			_show_modal("凯旋", "%s" % str(out.get("text", "")),
				[["返回铁匠铺", func() -> void: GameApp.goto("workshop")]])
		"lost":
			_on_battle_lost(node_id)


func _on_battle_lost(node_id: String) -> void:
	var run = GameApp.run
	_show_modal("败退", "队伍在血肉与砂石间退了下来。医师在伤兵中间忙到天亮。\n\n要么背水再战,要么撤回铁匠铺重整旗鼓。",
		[
			["背水再战", func() -> void:
				var node := ExpeditionMap.node_of(run.expedition.get("map", {}), node_id)
				run.expedition["awaiting_battle"] = node_id
				run.expedition["battle_floor"] = int(node.get("floor", 1))
				run.expedition["battle_type"] = str(node.get("type", "combat"))
				GameApp.goto("battle")],
			["撤回铁匠铺", func() -> void:
				run.expedition["active"] = false
				run.expedition["outcome"] = "retreat"
				GameApp.goto("workshop")],
		])


## ---------------- UI 构建 ----------------

func _build_ui() -> void:
	var run = GameApp.run
	var map_data: Dictionary = run.expedition.get("map", {})
	var floors := int(map_data.get("floors", 6))
	# 顶部栏
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.05, 0.09, 0.9)
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 64)
	add_child(bar)
	title_label = Label.new()
	title_label.text = "出征 · 余烬山脉"
	title_label.position = Vector2(28, 16)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("f0bd76"))
	add_child(title_label)
	info_label = Label.new()
	info_label.position = Vector2(360, 22)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.modulate = Color("d8ccb4")
	add_child(info_label)
	var retreat := Button.new()
	retreat.text = "◀ 撤退"
	retreat.position = Vector2(1120, 14)
	retreat.custom_minimum_size = Vector2(130, 34)
	retreat.pressed.connect(_on_retreat_pressed)
	add_child(retreat)
	# 层标签与节点
	var rows: Array = map_data.get("rows", [])
	for row in rows:
		var floor_num := int(row.get("floor", 1))
		var y := _floor_y(floor_num, floors)
		var fl := Label.new()
		fl.text = "F%d\n%s" % [floor_num, FLOOR_NAMES[(floor_num - 1) % FLOOR_NAMES.size()]]
		fl.position = Vector2(60, y - 16)
		fl.add_theme_font_size_override("font_size", 13)
		fl.modulate = FLOOR_COLORS[(floor_num - 1) % FLOOR_COLORS.size()].lerp(Color.WHITE, 0.35)
		add_child(fl)
		for node in row.nodes:
			var pos := _node_px(node, floors)
			node_pos[str(node.id)] = pos
			var b := _node_button(node)
			b.position = pos - Vector2(52, 34)
			b.pressed.connect(_on_node_pressed.bind(str(node.id)))
			add_child(b)
			node_buttons[str(node.id)] = b


func _floor_y(floor_num: int, floors: int) -> float:
	if floors <= 1:
		return 360.0
	return 120.0 + float(floor_num - 1) * (460.0 / float(floors - 1))


func _node_px(node: Dictionary, floors: int) -> Vector2:
	var col := int(node.get("col", 1))
	var x := 240.0 + float(col) * 320.0
	return Vector2(x, _floor_y(int(node.get("floor", 1)), floors))


func _node_button(node: Dictionary) -> Button:
	var type := str(node.get("type", "combat"))
	var b := Button.new()
	var icon: String = ExpeditionMap.TYPE_ICON.get(type, "?")
	var label: String = ExpeditionMap.TYPE_LABEL.get(type, type)
	var floor_num := int(node.get("floor", 1))
	b.text = "%s %s\nF%d" % [icon, label, floor_num]
	b.custom_minimum_size = Vector2(104, 62)
	b.add_theme_font_size_override("font_size", 14)
	var c: Color = TYPE_COLORS.get(type, Color("888888"))
	b.add_theme_stylebox_override("normal", _node_style(c.darkened(0.25), c, 1))
	b.add_theme_stylebox_override("hover", _node_style(c, c.lightened(0.25), 2))
	b.add_theme_stylebox_override("pressed", _node_style(c.lightened(0.1), Color.WHITE, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	return b


func _node_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg.r, bg.g, bg.b, 0.94)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(6)
	return s


func _refresh_nodes() -> void:
	var run = GameApp.run
	var cur := int(run.expedition.get("floor", 1))
	var done: Dictionary = run.expedition.get("done", {})
	for id in node_buttons.keys():
		var b: Button = node_buttons[id]
		var node := ExpeditionMap.node_of(run.expedition.get("map", {}), str(id))
		if node.is_empty():
			continue
		var nf := int(node.get("floor", 1))
		var is_done := done.has(str(id))
		b.disabled = nf != cur or is_done
		b.text = ("✓ %s\nF%d" % [ExpeditionMap.TYPE_LABEL.get(str(node.get("type", "")), "?"), nf]) if is_done \
			else ("%s %s\nF%d" % [ExpeditionMap.TYPE_ICON.get(str(node.get("type", "")), "?"),
				ExpeditionMap.TYPE_LABEL.get(str(node.get("type", "")), "?"), nf])


func _refresh_info() -> void:
	if info_label == null:
		return
	var run = GameApp.run
	var Inventory = preload("res://domain/economy/inventory.gd")
	var rep := float(run.world_flags.get("reputation", 0.0))
	info_label.text = "第 %d 层 · 金币 %.0f · 声望 %.0f · %s" % [
		int(run.expedition.get("floor", 1)), run.money, rep, Inventory.describe(run)]


## ---------------- 节点交互 ----------------

func _on_node_pressed(id: String) -> void:
	var run = GameApp.run
	var node := ExpeditionMap.node_of(run.expedition.get("map", {}), id)
	if node.is_empty():
		return
	if int(node.get("floor", 1)) != int(run.expedition.get("floor", 1)):
		return
	if (run.expedition.get("done", {}) as Dictionary).has(id):
		return
	match str(node.get("type", "")):
		"combat", "elite", "boss":
			_show_battle_prep(node)
		"event":
			_show_event(node)
		"rest":
			_show_rest(node)
		"treasure":
			_show_treasure(node)


func _show_battle_prep(node: Dictionary) -> void:
	var floor_num := int(node.get("floor", 1))
	var type := str(node.get("type", ""))
	var pack_id := ExpeditionRules.pack_for(floor_num, type)
	var pack := EnemyPacks.get_pack(pack_id)
	var sc := ExpeditionRules.scale_for_floor(floor_num)
	var type_label: String = ExpeditionMap.TYPE_LABEL.get(type, type)
	var html := "第 %d 层 · %s\n\n敌群: %s(%d 单位)\n当前强度: 血量 ×%.2f · 攻击 ×%.2f\n\n一层更比一层狠——锻造与神裁的功夫,都用在这里。" % [
		floor_num, type_label, str(pack.get("label", "?")), (pack.get("slots", []) as Array).size(),
		float(sc.hp), float(sc.atk)]
	_show_modal("遭遇敌情,是否出击?", html, [
		["进入战斗", func() -> void:
			var run = GameApp.run
			run.expedition["awaiting_battle"] = str(node.id)
			run.expedition["battle_floor"] = floor_num
			run.expedition["battle_type"] = type
			GameApp.goto("battle")],
		["按兵不动", func() -> void: _close_modal()],
	])


func _show_event(node: Dictionary) -> void:
	var run = GameApp.run
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run.run_seed) + int(node.get("floor", 1)) * 131 + str(node.id).hash()
	var ev := ExpeditionRules.random_event(rng)
	var opts: Array = []
	for opt in ev.get("options", []):
		var label := str(opt.get("label", ""))
		var eff: Dictionary = opt.get("effect", {})
		opts.append([label, func() -> void:
			var r = GameApp.run
			var res := ExpeditionRules.apply_effect(r, eff)
			var done: Dictionary = r.expedition.get("done", {})
			done[str(node.id)] = true
			r.expedition["done"] = done
			r.expedition["floor"] = int(node.get("floor", 1)) + 1
			var txt := _effect_text(eff) + ("" if not bool(res.ambush) else "\n\n——黑暗中,刀光扑来!这竟是个埋伏!你仓皇迎战!")
			_close_modal()
			if bool(res.ambush):
				# 伏击: 直接进入战斗(敌群按当前层)
				var f := int(node.get("floor", 1))
				r.expedition["awaiting_battle"] = str(node.id)
				r.expedition["battle_floor"] = f
				r.expedition["battle_type"] = "combat"
				_show_modal("埋伏!", txt, [["殊死一战", func() -> void: GameApp.goto("battle")]])
			else:
				_show_modal("事件: %s" % str(ev.title), txt, [["继续", func() -> void: _close_modal()]])])
	_show_modal("事件 · %s" % str(ev.title), str(ev.text), opts)


func _show_rest(node: Dictionary) -> void:
	var run = GameApp.run
	var opts: Array = []
	opts.append(["修补武器(全部耐久 +25)", func() -> void:
		for w in run.weapons:
			w["durability"] = minf(float(w.get("durability", 100.0)) + 25.0, 100.0)
		_finish_simple(node, "篝火旁磨着刃口,筋骨的疲乏与武器的豁口一起被热度抚平。全部武器耐久 +25。")])
	opts.append(["向火祈祷(声望 +2)", func() -> void:
		run.world_flags["reputation"] = float(run.world_flags.get("reputation", 0.0)) + 2.0
		_finish_simple(node, "你向余烬祈祷。火光似乎亮了一瞬——神明记住了你的名字。声望 +2。")])
	_show_modal("篝火 · 休整", "一个还算安全的避风处。火焰噼啪,疲惫的队员围火而坐。", opts)


func _show_treasure(node: Dictionary) -> void:
	var run = GameApp.run
	var r := ExpeditionRules.reward_for_treasure(int(node.get("floor", 1)))
	_show_modal("宝箱 · 战利品", "半埋在冻土里的铁箱,锁扣早已锈断。\n\n内藏: 金币 +%.0f,铁锭 +1%s" % [
		float(r.money), (",晶石 +1" if r.grant.has("charm_crystal") else "")], [
		["开启", func() -> void:
			run.money += float(r.money)
			var Inventory = preload("res://domain/economy/inventory.gd")
			Inventory.grant(run, r.grant)
			_finish_simple(node, "战利品入囊: 金币 +%.0f,铁锭 +1%s。" % [float(r.money), (",晶石 +1" if r.grant.has("charm_crystal") else "")])]])


func _finish_simple(node: Dictionary, message: String) -> void:
	var run = GameApp.run
	var done: Dictionary = run.expedition.get("done", {})
	done[str(node.id)] = true
	run.expedition["done"] = done
	run.expedition["floor"] = int(node.get("floor", 1)) + 1
	_refresh_nodes()
	_refresh_info()
	_show_modal("继续前进", message, [["继续", func() -> void: _close_modal()]])


func _effect_text(eff: Dictionary) -> String:
	var parts: Array = []
	if eff.has("money"):
		var m := float(eff.money)
		parts.append(("+%.0f 金币" % m) if m >= 0.0 else ("%.0f 金币" % m))
	if eff.has("reputation"):
		var rep := float(eff.reputation)
		parts.append(("+%.0f 声望" % rep) if rep >= 0.0 else ("%.0f 声望" % rep))
	if eff.has("grant"):
		for k in eff.grant.keys():
			parts.append("获得 %s×%d" % [str(k), int(eff.grant[k])])
	if eff.has("consume"):
		for k in eff.consume.keys():
			parts.append("消耗 %s×%d" % [str(k), int(eff.consume[k])])
	return ("结果: " + " · ".join(parts)) if not parts.is_empty() else "你离开了这里,什么都没发生。"


func _on_retreat_pressed() -> void:
	_show_modal("撤退出征", "就此返回铁匠铺吗?已走的路线会被放弃,不会结算远征奖励。", [
		["继续行军", func() -> void: _close_modal()],
		["撤退", func() -> void:
			var run = GameApp.run
			run.expedition["active"] = false
			run.expedition["outcome"] = "retreat"
			GameApp.goto("workshop")],
	])


## ---------------- 弹窗 ----------------

func _close_modal() -> void:
	if modal_panel != null:
		modal_panel.queue_free()
		modal_panel = null
		modal_content = null


func _show_modal(title: String, body: String, opts: Array) -> void:
	_close_modal()
	modal_panel = PanelContainer.new()
	modal_panel.position = Vector2(360, 170)
	modal_panel.custom_minimum_size = Vector2(560, 360)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.07, 0.06, 0.1, 0.97)
	frame.border_color = Color("b8794d")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(8)
	frame.content_margin_left = 24.0
	frame.content_margin_right = 24.0
	frame.content_margin_top = 20.0
	frame.content_margin_bottom = 20.0
	modal_panel.add_theme_stylebox_override("panel", frame)
	add_child(modal_panel)
	modal_content = VBoxContainer.new()
	modal_content.add_theme_constant_override("separation", 10)
	modal_panel.add_child(modal_content)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Color("f0bd76"))
	modal_content.add_child(t)
	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(500, 120)
	body_label.add_theme_font_size_override("font_size", 15)
	modal_content.add_child(body_label)
	for opt in opts:
		var b := Button.new()
		b.text = str(opt[0])
		b.custom_minimum_size = Vector2(500, 38)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(opt[1])
		modal_content.add_child(b)
	_refresh_nodes()
	_refresh_info()
