class_name BattleSim
## 战斗模拟器(离线确定性,固定 20Hz tick)。
## B2 范围: 3vN、三定位 AI、指令队列、弹道/召唤物/区域、MechLang 契约事件广播、战报增强。
## 见 02-battle-system-design.md §5-§9。

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const DefAction := preload("res://core/runtime/sim_actions.gd")
const Chain := preload("res://core/runtime/damage_chain.gd")
const SimContract := preload("res://core/runtime/sim_contract.gd")
const Grid := preload("res://core/runtime/hex_grid.gd")
const Bal := preload("res://core/config/balance.gd")

## 默认棋盘边界(axial 矩形)。表现层可用 configure_board() 为随机战场覆盖边界。
const BOARD_Q_MIN := 0
const BOARD_Q_MAX := 7
const BOARD_R_MIN := 0
const BOARD_R_MAX := 4

var entities: Dictionary = {}        # id -> entity dict
var contracts: Dictionary = {}       # contract_id -> SimContract
var entity_contracts: Dictionary = {}# entity_id -> [contract_id, ...]
var summons: Dictionary = {}         # ref_id -> {"id","owner","lifetime","orbit","kind"}
var projectiles: Array = []          # {"id","owner","speed","homing","ref","target"}
var zones: Dictionary = {}           # ref -> {owner,radius,lifetime,pull,delay,active}
var beams: Array = []                # {owner, remains, dmg}
var walls: Array = []                # {owner,len,lifetime}
var marks: Dictionary = {}           # target_id -> {source_id}
var world_flags: Dictionary = {}     # 环境标记(夜间/水域等)
var input_log: Array = []            # 指令流(确定性)
var tick: int = 0
var events: Array = []
var rng = null
var dmg_bonus := 0.0
var battle_result := ""              # "" | player_win | enemy_win | retreat
var retreat_called := false
var board_q_min := BOARD_Q_MIN
var board_q_max := BOARD_Q_MAX
var board_r_min := BOARD_R_MIN
var board_r_max := BOARD_R_MAX
var blocked_cells: Dictionary = {}
## 格效果(地形/羁绊修饰层): id -> {id, cell, owner, kind, lifetime}(lifetime<0 永续)
var cell_effects: Dictionary = {}
## 延迟命中命令队列(command 化攻击调度): {hit_tick, source_id, target_id, tag, from, to}
var pending_hits: Array = []
## 主动技调度(确定性输入): {"tick", "cmd", "contract_id"}
var pending_cmds: Array = []

const SIM_CONTRACT := SimContract
## 目标粘性窗口(tick): 锁定的目标在窗口内不因距离变化而更换(原目标死亡除外)
const TARGET_STICKY_TICKS := 60
## 远程弹道: 每格飞行 tick(20Hz 下 4 tick = 0.2s/格)
const RANGED_FLIGHT_TICKS := 4


func _init(seed_value: int = 1) -> void:
	rng = preload("res://core/runtime/rng.gd").new(seed_value)


## 配置本场战场边界。未配置时沿用原有 8x5 棋盘，保证旧测试与战斗规则不变。
## bounds: {q_min, q_max, r_min, r_max, blocked?}；blocked 可传 Vector2i 数组。
func configure_board(bounds: Dictionary) -> void:
	board_q_min = int(bounds.get("q_min", BOARD_Q_MIN))
	board_q_max = int(bounds.get("q_max", BOARD_Q_MAX))
	board_r_min = int(bounds.get("r_min", BOARD_R_MIN))
	board_r_max = int(bounds.get("r_max", BOARD_R_MAX))
	blocked_cells.clear()
	for cell in bounds.get("blocked", []):
		if cell is Vector2i:
			blocked_cells[cell] = true


func is_inside_board(c: Vector2i) -> bool:
	return c.x >= board_q_min and c.x <= board_q_max \
			and c.y >= board_r_min and c.y <= board_r_max


## ---------------- 格效果(棋盘修饰层) ----------------

## 在格子上放置效果(如火坑/淬火格/诅咒地);lifetime<0 永续。返回效果 id。
func add_cell_effect(cell: Vector2i, owner_id: String, kind: String, lifetime: int = -1) -> String:
	var eid := "ce_%d" % (cell_effects.size() + 1)
	cell_effects[eid] = {"id": eid, "cell": cell, "owner": owner_id,
		"kind": kind, "lifetime": lifetime}
	return eid


func remove_cell_effect(eid: String) -> void:
	cell_effects.erase(eid)


func has_cell_effect(cell: Vector2i, kind: String) -> bool:
	for fx in cell_effects.values():
		if fx.cell == cell and fx.kind == kind:
			return true
	return false


## 该格的全部效果简要列表(供契约/表现使用)
func cell_effects_of(cell: Vector2i) -> Array:
	var out: Array = []
	for fx in cell_effects.values():
		if fx.cell == cell:
			out.append({"id": fx.id, "kind": fx.kind, "owner": fx.owner})
	return out


func _effects_by_cell(cell: Vector2i) -> Array:
	return cell_effects_of(cell)


## 每 tick 衰减格效果寿命
func _tick_cell_effects() -> void:
	if cell_effects.is_empty():
		return
	for eid in cell_effects.keys().duplicate():
		var fx: Dictionary = cell_effects[eid]
		if int(fx.lifetime) < 0:
			continue
		fx.lifetime = int(fx.lifetime) - 1
		if int(fx.lifetime) <= 0:
			cell_effects.erase(eid)


## DoT 跳伤: burning/poisoned/bleeding/withering 按各自 interval 跳伤,伤害 = dot × 层数
func _tick_dots() -> void:
	for ent in entities.values():
		if not ent.alive:
			continue
		for sid in ent.statuses.keys():
			var cfg: Dictionary = Bal.status_cfg(sid)
			var dot: float = float(cfg.get("dot", 0.0))
			if dot <= 0.0:
				continue
			var interval: int = int(cfg.get("interval", 20))
			if tick % interval != 0:
				continue
			var stacks: int = int(ent.statuses[sid].get("stacks", 1))
			mechanic_damage("", ent, sid, dot * stacks, "")
			break


## 单位从 from 移动到 to: 触发格子进出效果事件(仅有格效果时才广播,零开销)
func _emit_cell_events(u: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if cell_effects.is_empty() or from == to:
		return
	var out_fx := _effects_by_cell(from)
	if not out_fx.is_empty():
		push_event({"kind": "cell_exit", "source_id": u.id, "target_id": u.id,
			"cell": from, "effects": out_fx, "tick": tick})
		_broadcast_for(u.id, "cell_exit", {"unit": u, "cell": from, "effects": out_fx, "tick": tick})
	var in_fx := _effects_by_cell(to)
	if not in_fx.is_empty():
		push_event({"kind": "cell_enter", "source_id": u.id, "target_id": u.id,
			"cell": to, "effects": in_fx, "tick": tick})
		_broadcast_for(u.id, "cell_enter", {"unit": u, "cell": to, "effects": in_fx, "tick": tick})


## 灼烧格(scorch 原语): 在持有者"当前攻击目标"的格子放置持续灼烧地面
## 返回被灼烧的格(无目标时返回 (-999,-999))
func scorch_cell(holder_id: String, lifetime: int) -> Vector2i:
	var h: Dictionary = entities.get(holder_id, {})
	if h.is_empty():
		return Vector2i(-999, -999)
	var tid: String = str(h.get("cur_target", ""))
	if tid.is_empty() or not entities.has(tid) or not entities[tid].alive:
		tid = str(h.get("focus_target", ""))
	if tid.is_empty() or not entities.has(tid) or not entities[tid].alive:
		var t := DefEntity.nearest_enemy_of(h, entities, 99999)
		tid = t.get("id", "")
	if tid.is_empty():
		return Vector2i(-999, -999)
	var cell: Vector2i = entities[tid].grid
	add_cell_effect(cell, holder_id, "burning_ground", lifetime)
	push_event({"kind": "scorch", "source_id": holder_id, "cell": cell, "tick": tick,
		"lifetime": lifetime})
	return cell


## 指定格上的活体(可选排除阵营;供 scorched_units 查询)
func units_on_cell(cell: Vector2i, exclude_faction: String = "") -> Array:
	var out: Array = []
	for e in entities.values():
		if not e.alive:
			continue
		if exclude_faction != "" and e.faction == exclude_faction:
			continue
		if e.grid == cell:
			out.append({"id": e.id})
	return out


## 治疗(含治疗事件,表现层绿字)
func heal_entity(t: Dictionary, amount: float) -> void:
	if t.is_empty() or not t.alive or amount <= 0.0:
		return
	var healed: float = minf(t.hp + amount, t.max_hp) - t.hp
	if healed <= 0.0:
		return
	t.hp = t.hp + healed
	push_event({"kind": "healed", "source_id": "", "target_id": t.id,
		"amount": healed, "tick": tick})


## 最近友军(不含自身;供 nearest_ally 查询)
func nearest_ally_of(center: Dictionary) -> Dictionary:
	var best := {}
	var best_d := 999999
	for e in entities.values():
		if not e.alive or e.id == center.id or e.faction != center.faction:
			continue
		var d := Grid.dist(center.grid, e.grid)
		if d < best_d:
			best_d = d
			best = {"id": e.id}
	return best


## ---------------- 实体与注册 ----------------

func add_entity(ent: Dictionary) -> void:
	entities[ent.id] = ent
	if not ent.has("tags"):
		ent.tags = []


func get_entity(id: String) -> Dictionary:
	return entities.get(id, {})


func add_contract(cid: String, ast: Dictionary, holder_id: String, weapon: Dictionary) -> void:
	var c = SIM_CONTRACT.new(cid, ast, holder_id, weapon, self)
	contracts[cid] = c
	if not entity_contracts.has(holder_id):
		entity_contracts[holder_id] = []
	entity_contracts[holder_id].append(cid)


## ---------------- 指令队列 ----------------

func cmd_focus(entity_id: String, target_id: String) -> void:
	if entities.has(entity_id):
		entities[entity_id].focus_target = target_id
	input_log.append({"tick": tick, "cmd": "focus", "a": entity_id, "b": target_id})


func cmd_protect(entity_id: String, guard_id: String) -> void:
	if entities.has(entity_id):
		entities[entity_id].protect_target = guard_id
	input_log.append({"tick": tick, "cmd": "protect", "a": entity_id, "b": guard_id})


func cmd_overload(contract_id: String) -> void:
	if contracts.has(contract_id):
		var c = contracts[contract_id]
		var holder: Dictionary = entities.get(c.host.holder_id, {})
		# 过载目标: 集火目标优先,否则最近敌人
		var target_id: String = holder.get("focus_target", "")
		if target_id.is_empty() or not entities.has(target_id) or not entities[target_id].alive:
			var t := DefEntity.nearest_enemy_of(holder, entities, 99999)
			target_id = t.get("id", "")
		c.on_event("overload", {"target": {"id": target_id}, "tick": tick})
	input_log.append({"tick": tick, "cmd": "overload", "a": contract_id})


## 主动技调度(玩家手动释放): 在 at_tick 触发契约 right_click
## 确定性: 指令进入 input_log,由同 seed 重模拟可精确复现
func schedule_active(contract_id: String, at_tick: int) -> void:
	pending_cmds.append({"tick": maxi(at_tick, 1), "cmd": "active", "contract_id": contract_id})
	pending_cmds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.tick) < int(b.tick))
	input_log.append({"tick": -1, "cmd": "active", "a": contract_id, "at": maxi(at_tick, 1)})


## 执行到期的主动指令(在 tick_once 开头)
func _run_scheduled() -> void:
	if pending_cmds.is_empty():
		return
	for c in pending_cmds.duplicate():
		if int(c.tick) > tick:
			continue
		pending_cmds.erase(c)
		if c.cmd != "active" or not contracts.has(c.contract_id):
			continue
		var ct = contracts[c.contract_id]
		var holder: Dictionary = entities.get(ct.host.holder_id, {})
		var t := {}
		if not holder.is_empty():
			t = DefEntity.nearest_enemy_of(holder, entities, 99999)
		var res: Dictionary = ct.on_event("right_click", {"target": t, "tick": tick})
		# 事件仅在成功触发时广播(冷却门控的尝试不产生表现事件)
		if res.triggered:
			push_event({"kind": "active_cast", "source_id": ct.host.holder_id,
				"contract_id": c.contract_id, "tick": tick})
		input_log.append({"tick": tick, "cmd": "active", "a": c.contract_id})


func cmd_retreat() -> void:
	retreat_called = true
	battle_result = "retreat"
	input_log.append({"tick": tick, "cmd": "retreat"})


## ---------------- 主循环 ----------------

func run(max_ticks: int = 2400) -> int:
	while tick < max_ticks:
		tick_once()
		var p := 0
		var e := 0
		for ent in entities.values():
			if not ent.alive or ent.kind != "hero":
				continue
			p += 1
		if p == 0 and battle_result.is_empty():
			battle_result = "enemy_win"
			break
		if e == 0 and _enemy_alive() == 0 and battle_result.is_empty():
			battle_result = "player_win"
			break
		if retreat_called:
			break
	# 超时上限: 无判定结果的战斗标记 timeout(报告层可区分 draw/timeout)
	if battle_result.is_empty():
		battle_result = "timeout"
	_settle_all()
	return tick


## 战斗结算收尾: 存活单位回到站姿(避免时间轴定格在"最后一击"的空中姿势)
func _settle_all() -> void:
	for ent in entities.values():
		if ent.alive:
			ent.current_action = {}
			ent.move_t = 0


func _enemy_alive() -> int:
	var n := 0
	for ent in entities.values():
		if ent.alive and ent.kind == "enemy":
			n += 1
	return n


func tick_once() -> void:
	tick += 1
	# 主动技调度(确定性输入)在单位行动前执行
	_run_scheduled()
	# 实体动作与移动
	for id in entities.keys():
		var ent: Dictionary = entities[id]
		if ent.alive:
			_progress_action(ent)
			_move_toward_target(ent)
	# 决策(idle 实体)
	for ent in entities.values():
		if ent.alive and ent.current_action.is_empty():
			decide(ent)
	# 弹道/区域/光束/墙/召唤物/格效果/延迟命中命令
	_tick_projectiles()
	_tick_zones()
	_tick_beams()
	_tick_walls()
	_tick_summons()
	_tick_cell_effects()
	_tick_pending_hits()
	# 状态到期(每 tick 衰减;ticks 语义 = 20Hz tick,如 60 = 3 秒)
	for ent in entities.values():
		DefEntity.tick_statuses(ent)
	# DoT 跳伤(按状态 interval 调度;伤害 = dot × 层数)
	_tick_dots()
	# 契约定时器(每 20 tick)
	if tick % 20 == 0:
		_broadcast("timer", {"tick": tick})


## ---------------- 动作帧 ----------------

func start_action(e: Dictionary, tag: String, target_id: String = "") -> void:
	var def: Dictionary = DefAction.get_def(tag)
	var mult: float = DefEntity.frame_mult(e)
	# 攻速强化(empower): 剩余次数内动作帧缩短
	if int(e.get("empower_left", 0)) > 0:
		mult /= maxf(float(e.get("empower_mult", 1.0)), 1.0)
	e.current_action = {
		"tag": tag, "target_id": target_id, "phase": "windup", "t": 0,
		"windup": maxi(int(float(def.windup) * mult), 1),
		"active": maxi(int(float(def.active) * mult), 1),
		"recover": maxi(int(float(def.recover) * mult), 1),
	}


func _progress_action(e: Dictionary) -> void:
	var a: Dictionary = e.current_action
	if a.is_empty():
		return
	# 硬控打断(金铲铲对照): 眩晕/冻结等立即中止当前动作
	if DefEntity.is_hard_cc(e):
		e.current_action = {}
		push_event({"kind": "interrupt", "source_id": e.id, "target_id": e.id,
			"reason": "hard_cc", "tick": tick})
		return
	# 前摇期间目标死亡 -> 立即中断并交还决策(不空打)
	if a.phase == "windup" and not a.target_id.is_empty():
		var tgt: Dictionary = entities.get(a.target_id, {})
		if tgt.is_empty() or not tgt.alive:
			e.current_action = {}
			return
	a.t += 1
	match a.phase:
		"windup":
			if a.t >= a.windup:
				a.phase = "active"
				a.t = 0
				_on_active_begin(e)
		"active":
			if a.t >= a.active:
				a.phase = "recover"
				a.t = 0
		"recover":
			if a.t >= a.recover:
				e.current_action = {}
				# 攻速强化次数随"完成一次动作"递减(empower 剩余攻击次数)
				if int(e.get("empower_left", 0)) > 0:
					e.empower_left = int(e.empower_left) - 1


## 判定窗开始: 结算一次攻击(远程且目标距离>1 时改为发射弹道,延迟到命中 tick 结算)
func _on_active_begin(e: Dictionary) -> void:
	var a: Dictionary = e.current_action
	if DefAction.is_block_tag(a.tag):
		push_event({"kind": "block_ready", "source_id": e.id, "target_id": "", "action_tag": a.tag, "tick": tick})
		return
	var target: Dictionary = entities.get(a.target_id, {})
	if target.is_empty() or not target.alive:
		_attack_missed(e, a)
		return
	# 远程弹道: 距离>1 时发射(飞行 tick 后命中);近战/贴脸立即结算(旧行为不变)
	if a.tag == "ranged" and Grid.dist(e.grid, target.grid) > 1:
		var flight: int = maxi(Grid.dist(e.grid, target.grid) - 1, 1) * RANGED_FLIGHT_TICKS
		pending_hits.append({"hit_tick": tick + flight, "source_id": e.id,
			"target_id": a.target_id, "tag": a.tag, "from": e.grid, "to": target.grid})
		push_event({"kind": "projectile_launch", "source_id": e.id, "target_id": a.target_id,
			"tick": tick, "flight": flight, "from": e.grid, "to": target.grid})
		return
	_resolve_hit(e, target, a)


## 目标缺失/已死亡的空攻击事件(出手落空)
func _attack_missed(e: Dictionary, a: Dictionary) -> void:
	_broadcast_for(e.id, "attack", {"target": {"id": a.target_id}, "attack_damage": e.atk,
		"hit_landed": 0, "hit_crit": 0.0, "tick": tick})
	push_event({"kind": "attack", "source_id": e.id, "target_id": a.target_id, "action_tag": a.tag,
		"tick": tick, "hit_landed": 0, "crit_tier": 0.0, "base": 0.0,
		"final_damage": 0.0, "blocked": false, "blocked_damage": 0.0,
		"armor_after": 0.0, "statuses": [], "cause_ids": []})


## 攻击命中结算(近战在判定窗开始时;弹道在命中 tick 被命令队列触发)
func _resolve_hit(e: Dictionary, target: Dictionary, a: Dictionary) -> void:
	var result := Chain.resolve_attack(_atk_source(e), target, a.tag, rng, dmg_bonus,
		_vulnerability_of(target), _traits_of(e))
	var damage_done: float = result.final_damage if result.landed else 0.0
	# 契约事件(定向): attack(无论命中) -> 攻击者; block -> 格挡者; hurt -> 受击者
	_broadcast_for(e.id, "attack", {"target": target, "attack_damage": e.atk,
		"hit_landed": 1 if result.landed else 0, "hit_crit": result.crit_tier, "tick": tick})
	if a.tag == "heavy_blow":
		_broadcast_for(e.id, "heavy_blow", {"target": target, "attack_damage": damage_done, "tick": tick})
	if result.blocked:
		_broadcast_for(target.id, "block", {"blocked_damage": result.blocked_damage,
			"attacker": e, "tick": tick})
	# 受击转火(金铲铲对照): 被攻击者若未被手动集火,优先反击攻击者
	if result.landed and target.alive and not target.focus_manual:
		target.focus_target = e.id
	if result.landed:
		target.hp = maxf(target.hp - result.final_damage, 0.0)
		_broadcast_for(target.id, "hurt", {"target": target, "attacker": e,
			"hurt_damage": result.final_damage, "tick": tick})
		if not result.blocked:
			_broadcast_for(e.id, "hit", {"target": target, "attack_damage": result.final_damage, "tick": tick})
	push_event({
		"kind": "attack", "source_id": e.id, "target_id": target.id, "action_tag": a.tag,
		"tick": tick, "hit_landed": 1 if result.landed else 0, "crit_tier": result.crit_tier,
		"base": result.base, "final_damage": result.final_damage, "blocked": result.blocked,
		"blocked_damage": result.blocked_damage, "armor_after": result.armor_after,
		"statuses": [], "cause_ids": [],
	})
	if result.landed and target.hp <= 0.0 and target.alive:
		_kill(e, target)


## 延迟命中命令到期结算(远程弹道到达)
func _tick_pending_hits() -> void:
	if pending_hits.is_empty():
		return
	for h in pending_hits.duplicate():
		if int(h.hit_tick) > tick:
			continue
		pending_hits.erase(h)
		var src: Dictionary = entities.get(h.source_id, {})
		var tgt: Dictionary = entities.get(h.target_id, {})
		if src.is_empty():
			push_event({"kind": "attack", "source_id": h.source_id, "target_id": h.target_id,
				"action_tag": h.tag, "tick": tick, "hit_landed": 0, "crit_tier": 0.0,
				"base": 0.0, "final_damage": 0.0, "blocked": false, "blocked_damage": 0.0,
				"armor_after": 0.0, "statuses": [], "cause_ids": []})
			continue
		if tgt.is_empty() or not tgt.alive:
			_attack_missed(src, {"tag": h.tag, "target_id": h.target_id})
			continue
		_resolve_hit(src, tgt, {"tag": h.tag, "target_id": h.target_id})


func _kill(attacker: Dictionary, target: Dictionary) -> void:
	target.alive = false
	target.deaths += 1
	_clear_focus_on(target.id)
	push_event({"kind": "kill", "source_id": attacker.id, "target_id": target.id,
		"action_tag": attacker.current_action.get("tag", ""), "tick": tick, "final_damage": 0.0})
	_broadcast_for(attacker.id, "kill", {"target": target, "attacker": attacker, "tick": tick})


## 目标死亡时,立即清除指向它的非手动 focus(转火更即时)
func _clear_focus_on(target_id: String) -> void:
	for e in entities.values():
		if e.get("focus_target", "") == target_id and not e.get("focus_manual", false):
			e.focus_target = ""


## 契约机制伤害(绕过命中判定,契约公式自算)
func mechanic_damage(source_id: String, target: Dictionary, dmg_type: String, amount: float, contract_id: String) -> void:
	if target.is_empty() or not target.alive or amount <= 0.0:
		return
	target.hp = maxf(target.hp - amount, 0.0)
	push_event({"kind": "mechanic_damage", "source_id": source_id, "target_id": target.id,
		"damage_type": dmg_type, "amount": amount, "tick": tick, "contract_id": contract_id})
	if target.hp <= 0.0 and target.alive:
		target.alive = false
		target.deaths += 1
		_clear_focus_on(target.id)
		push_event({"kind": "kill", "source_id": source_id, "target_id": target.id,
			"action_tag": "mechanic", "tick": tick, "final_damage": amount,
			"contract_id": contract_id})
		_broadcast_for(source_id, "kill", {"target": target, "attacker": {}, "tick": tick})


## ---------------- 移动 ----------------

func _move_toward_target(e: Dictionary) -> void:
	if not e.alive:
		return
	if not e.current_action.is_empty():
		return
	var mult: float = DefEntity.move_speed_mult(e)
	# 定身/硬控(眩晕/冻结/麻痹/浮空): 不能自主移动(外力位移仍可生效,如击退/拉拽)
	if DefEntity.has_status(e, "rooted") or DefEntity.is_hard_cc(e):
		return
	var foes := DefEntity.nearest_enemy_of(e, entities, 999)
	# 恐惧: 背离最近敌人移动
	if DefEntity.is_feared(e):
		_step_away(e, foes, int(maxf(e.move_interval, 1.0) / maxf(mult, 0.1)))
		return
	if foes.is_empty():
		return
	# 移动目标: 粘性目标优先(不再每 tick 重算最近敌,避免目标摇摆)
	var target: Dictionary = _move_target_of(e)
	if target.is_empty():
		return
	var d := Grid.dist(e.grid, target.grid)
	# 射程内: 无需移动(攻击中的目标锁定不消耗粘性窗口,死亡/转火才换)
	if d <= int(e.range_hex):
		return
	# 需要移动追逐: 消耗粘性窗口(过期后 decide 重新绑定最近敌,防摇摆)
	if int(e.get("sticky_ticks", 0)) > 0:
		e.sticky_ticks = int(e.sticky_ticks) - 1
	_step_toward(e, target.grid, int(maxf(e.move_interval, 1.0) / maxf(mult, 0.1)))
	# 射手被贴近到近战格 -> 后撤(每 2 个移动节拍反向)
	if e.role == "ranger" and e.kind == "hero" and d == 1 and _enemy_alive() > 0:
		if e.move_t == 0:
			_step_toward(e, _retreat_grid(e), int(maxf(e.move_interval, 1.0) / maxf(mult, 0.1)))


var _retreat_t := 0


func _retreat_grid(e: Dictionary) -> Vector2i:
	var foes := DefEntity.nearest_enemy_of(e, entities, 999)
	if foes.is_empty():
		return e.grid
	# 远离最近敌人的方向
	var dir_i := Grid.direction_toward(foes.grid, e.grid)
	if dir_i == -1:
		return e.grid
	var n: Vector2i = e.grid + Grid.DIRS[dir_i]
	if _cell_free(n):
		return n
	return e.grid


## 向目标格方向移动一格(带节奏节拍;目标格被占时绕行一格,仍无路则等待)
func _step_toward(e: Dictionary, goal: Vector2i, interval: int) -> void:
	e.move_t += 1
	if e.move_t < interval:
		return
	e.move_t = 0
	var dir_i := Grid.direction_toward(e.grid, goal)
	if dir_i != -1:
		var n: Vector2i = e.grid + Grid.DIRS[dir_i]
		if _cell_free(n):
			_emit_cell_events(e, e.grid, n)
			e.grid = n
			return
	# 绕行: 找"距离不增加"的邻居空位(否则等待)
	var best: Vector2i = e.grid
	var best_d := Grid.dist(e.grid, goal)
	for i in 6:
		var cand: Vector2i = e.grid + Grid.DIRS[i]
		if _cell_free(cand) and Grid.dist(cand, goal) <= best_d:
			best = cand
			best_d = Grid.dist(cand, goal)
	if best != e.grid:
		_emit_cell_events(e, e.grid, best)
		e.grid = best


## 反向移动(恐惧)
func _step_away(e: Dictionary, foes: Dictionary, interval: int) -> void:
	if foes.is_empty():
		return
	e.move_t += 1
	if e.move_t < interval:
		return
	e.move_t = 0
	var dir_i := Grid.direction_toward(foes.grid, e.grid)
	if dir_i == -1:
		return
	var n: Vector2i = e.grid + Grid.DIRS[dir_i]
	if _cell_free(n):
		_emit_cell_events(e, e.grid, n)
		e.grid = n


func _cell_free(c: Vector2i) -> bool:
	if not is_inside_board(c) or blocked_cells.has(c):
		return false
	for other in entities.values():
		if other.alive and other.grid == c:
			return false
	return true


## ---------------- 决策(B2 三定位) ----------------

func decide(e: Dictionary) -> void:
	if not e.alive:
		return
	# 麻痹: 25% 概率本次无法出手(动作被"抽搐"跳过)
	if DefEntity.has_status(e, "paralyzed") and rng.rand_range(0.0, 1.0) < 0.25:
		return
	# 硬控/恐惧: 不主动攻击
	if DefEntity.is_hard_cc(e) or DefEntity.is_feared(e):
		return
	# 嘲讽: 强制攻击嘲讽来源
	var taunt_id := _taunt_source_of(e)
	if not taunt_id.is_empty():
		var ttag := _attack_tag_for(e)
		if not ttag.is_empty():
			start_action(e, ttag, taunt_id)
		return
	var target_id: String = _pick_target(e)
	if target_id.is_empty():
		return
	var target: Dictionary = entities[target_id]
	var are_range_close: int = Grid.dist(e.grid, target.grid)
	var is_ranged: bool = e.role == "ranger" and e.kind == "hero"
	# 守卫: 保护目标存在且受影响时贴身格挡(简化:hp 低且近距离格挡,上限3次)
	if e.role == "guard" and e.hp < e.max_hp * 0.5 and are_range_close <= 1 \
			and int(e.get("blocks_used", 0)) < 3:
		e.blocks_used = int(e.get("blocks_used", 0)) + 1
		start_action(e, "block")
		return
	if is_ranged:
		if are_range_close <= int(e.range_hex):
			var rtag := _attack_tag_for(e)
			if rtag.is_empty():
				return
			start_action(e, rtag, target_id)
		return
	# 近战: 射程内才出手
	if are_range_close <= int(e.range_hex):
		var tag := _attack_tag_for(e)
		if tag.is_empty():
			return
		start_action(e, tag, target_id)


## 攻击标签选择: 缄默时技能类(重击/远程)降为普攻;缴械时返回空(不攻击)
func _attack_tag_for(e: Dictionary) -> String:
	if DefEntity.is_disarmed(e):
		return ""
	if DefEntity.is_silenced(e):
		return "basic"
	if e.role == "guard":
		return "heavy_blow"
	if e.role == "ranger" and e.kind == "hero":
		return "ranged"
	return "basic"


## 嘲讽来源(状态 source_id)
func _taunt_source_of(e: Dictionary) -> String:
	if DefEntity.has_status(e, "taunted"):
		var sid: String = e.statuses.taunted.get("source_id", "")
		if not sid.is_empty() and entities.has(sid) and entities[sid].alive:
			return sid
	return ""


## 目标选择: 集火倾向 -> 目标粘性(cur_target,窗口内锁定) -> 距离最近敌
func _pick_target(e: Dictionary) -> String:
	var focus_id: String = e.get("focus_target", "")
	if not focus_id.is_empty() and entities.has(focus_id) and entities[focus_id].alive:
		e.cur_target = focus_id
		e.sticky_ticks = TARGET_STICKY_TICKS
		return focus_id
	var ct: String = e.get("cur_target", "")
	if not ct.is_empty() and entities.has(ct) and entities[ct].alive \
			and int(e.get("sticky_ticks", 0)) > 0:
		return ct
	var t := DefEntity.nearest_enemy_of(e, entities, 99999)
	var tid: String = t.get("id", "")
	if not tid.is_empty():
		e.cur_target = tid
		e.sticky_ticks = TARGET_STICKY_TICKS
	else:
		e.cur_target = ""
	return tid


## 朝当前粘性目标移动;无有效粘性目标时退回 focus/最近敌并重新锁定
func _move_target_of(e: Dictionary) -> Dictionary:
	var ct: String = e.get("cur_target", "")
	if not ct.is_empty() and entities.has(ct) and entities[ct].alive:
		return entities[ct]
	return get_focus_or_nearest(e)


func get_focus_or_nearest(e: Dictionary) -> Dictionary:
	var focus_id: String = e.get("focus_target", "")
	if not focus_id.is_empty() and entities.has(focus_id) and entities[focus_id].alive:
		return entities[focus_id]
	return DefEntity.nearest_enemy_of(e, entities, 99999)


## 每 tick 决策辅助(公开 API;tick_once 内部已自动决策)
func decide_all() -> void:
	for ent in entities.values():
		if ent.alive and ent.current_action.is_empty():
			decide(ent)


## ---------------- 契约事件广播 ----------------

## 广播给指定实体的契约(定向事件)
func _broadcast_for(entity_id: String, event: String, ctx: Dictionary) -> void:
	if not entity_contracts.has(entity_id):
		return
	for cid in entity_contracts[entity_id]:
		contracts[cid].on_event(event, ctx)


## 广播给全部契约(全局事件: timer / 环境)
func _broadcast(event: String, ctx: Dictionary) -> void:
	for cid in contracts.keys():
		contracts[cid].on_event(event, ctx)


## ---------------- 弹道/区域/召唤物/光束/墙 ----------------

func spawn_projectile(owner_id: String, speed: float, homing: bool) -> Dictionary:
	var ref := {"id": "proj_%d" % (projectiles.size() + 1)}
	var own: Dictionary = entities.get(owner_id, {})
	projectiles.append({"id": ref.id, "owner": owner_id, "speed": speed, "homing": homing,
		"ref": ref, "grid": own.get("grid", Vector2i.ZERO), "move_t": 0})
	return ref


func spawn_summon(owner_id: String, count: int, lifetime: int, orbit: float) -> Dictionary:
	var ref := {"id": "summon_%d" % (summons.size() + 1)}
	var own: Dictionary = entities.get(owner_id, {})
	var ent := DefEntity.make(ref.id, "summon", own.get("faction", "enemy"),
		"召唤物", "minion", {"hp": 3.0, "atk": 0.0, "armor": 0.0, "hit": 1.0, "evade": 0.0,
			"grid": own.get("grid", Vector2i.ZERO)})
	ent.tags = ["summon"]
	ent.owner_id = owner_id
	ent.lifetime = lifetime
	ent.orbit = orbit
	ent.visual_phase = 0.0
	entities[ref.id] = ent
	summons[ref.id] = {"owner": owner_id, "lifetime": lifetime, "orbit": orbit}
	return ref


func create_zone(owner_id: String, radius: float, lifetime: int, pull: float, delay: int) -> Dictionary:
	var ref := {"id": "zone_%d" % (zones.size() + 1)}
	var own: Dictionary = entities.get(owner_id, {})
	zones[ref.id] = {"owner": owner_id, "radius": int(radius), "lifetime": lifetime,
		"pull": pull, "delay": delay, "active": false, "grid": own.get("grid", Vector2i.ZERO)}
	return ref


func create_wall(owner_id: String, len: float, lifetime: int) -> void:
	var own: Dictionary = entities.get(owner_id, {})
	walls.append({"owner": owner_id, "len": int(len), "grid": own.get("grid", Vector2i.ZERO), "lifetime": lifetime})


func spawn_beam(owner_id: String, duration: int, dmg: float) -> void:
	var own: Dictionary = entities.get(owner_id, {})
	beams.append({"owner": owner_id, "remains": duration, "dmg": dmg, "grid": own.get("grid", Vector2i.ZERO)})


func destroy_entity(ref_v: Variant) -> void:
	var rid := str(ref_v.get("id", "")) if typeof(ref_v) == TYPE_DICTIONARY else str(ref_v)
	if entities.has(rid):
		entities[rid].alive = false
	if summons.has(rid):
		summons.erase(rid)


func zone_is_active(ref_v: Variant) -> bool:
	var rid := str(ref_v.get("id", "")) if typeof(ref_v) == TYPE_DICTIONARY else str(ref_v)
	return zones.has(rid) and zones[rid].active


func set_mark(target_id: String, source_id: String) -> void:
	marks[target_id] = {"source_id": source_id}


func clear_mark(target_id: String) -> void:
	marks.erase(target_id)


func get_marks(target_id: String) -> int:
	return 1 if marks.has(target_id) else 0


## 半径(格)内活敌列表(供 MechLang enemies_in_range 查询)
func enemies_in_radius(center: Dictionary, radius: int) -> Array:
	var out: Array = []
	for e in entities.values():
		if not e.alive or e.faction == center.faction:
			continue
		if Grid.dist(center.grid, e.grid) <= radius:
			out.append({"id": e.id})
	return out


## 半径(格)内全部活体(不分阵营;供主动 AOE units_in_range 查询)
func units_in_radius(center: Dictionary, radius: int) -> Array:
	var out: Array = []
	for e in entities.values():
		if not e.alive:
			continue
		if Grid.dist(center.grid, e.grid) <= radius:
			out.append({"id": e.id})
	return out


## 半径内最近活敌(平局取遍历首个含 deterministic 顺序)
func closest_enemy_in_radius(center: Dictionary, radius: int) -> Dictionary:
	var best := {}
	var best_d := 999999
	for e in entities.values():
		if not e.alive or e.faction == center.faction:
			continue
		var d := Grid.dist(center.grid, e.grid)
		if d <= radius and d < best_d:
			best_d = d
			best = {"id": e.id}
	return best


## 击退落点: 从 origin 沿 dir_idx 方向最多 steps 格,遇墙/越界/占用处截断(返回实际到达格)
func find_knockback_cell(origin: Vector2i, dir_idx: int, steps: int) -> Vector2i:
	var cur := origin
	var d: Vector2i = Grid.DIRS[wrapi(dir_idx, 0, 6)]
	for i in steps:
		var nxt: Vector2i = origin + d * (i + 1)
		if not is_inside_board(nxt) or blocked_cells.has(nxt):
			break
		cur = nxt
	return cur


## 全部活敌(供 all_enemies 查询)
func all_enemies_of(center: Dictionary) -> Array:
	var out: Array = []
	for e in entities.values():
		if e.alive and e.faction != center.faction:
			out.append({"id": e.id})
	return out


func _vulnerability_of(target: Dictionary) -> float:
	var v := 0.0
	if DefEntity.has_status(target, "weak_point"):
		v += 0.10
	return v


## 收集持有者所有契约的 traits(guaranteed_hit / ignores_evade / crit_mult ...)
## —— 让 MechLang 设备特性在攻击判定中真实生效(优先级高于武器面板)
func _traits_of(e: Dictionary) -> Dictionary:
	var out := {}
	if entity_contracts.has(e.id):
		for cid in entity_contracts[e.id]:
			var c = contracts.get(cid)
			if c == null:
				continue
			var tr: Dictionary = c.get_traits()
			for k in tr.keys():
				out[k] = tr[k]
	return out


## 攻击者输出修正(weakened -20%) -> 构造临时副本供判定链使用
func _atk_source(attacker: Dictionary) -> Dictionary:
	var mult: float = DefEntity.atk_mult(attacker)
	if mult >= 1.0:
		return attacker
	var copy: Dictionary = attacker.duplicate(true)
	copy.atk = attacker.atk * mult
	return copy


func _tick_projectiles() -> void:
	for p in projectiles.duplicate():
		var owner: Dictionary = entities.get(p.owner, {})
		if owner.is_empty() or not owner.alive:
			projectiles.erase(p)
			continue
		var t := get_focus_or_nearest(owner)
		if t.is_empty():
			continue
		# 格级移动: 每 speed/2 tick 向目标格走一格(速度折半)
		p.move_t = int(p.get("move_t", 0)) + 1
		if p.move_t < maxi(int(p.speed / 2.0), 1):
			continue
		p.move_t = 0
		var g: Vector2i = p.grid
		var dir_i := Grid.direction_toward(g, t.grid)
		if dir_i == -1 or Grid.dist(g, t.grid) <= 1:
			# 命中
			var ent: Dictionary = entities.get(t.id, {})
			if not ent.is_empty() and ent.alive:
				push_event({"kind": "projectile_hit", "source_id": owner.id, "target_id": ent.id, "tick": tick})
				_broadcast("projectile_hit", {"target": ent, "attacker": owner, "tick": tick})
			projectiles.erase(p)
			continue
		p.grid = g + Grid.DIRS[dir_i]


func spawn_projectile_grid(p: Dictionary, grid: Vector2i) -> void:
	p.grid = grid
	p.move_t = 0


func _tick_zones() -> void:
	for zid in zones.keys().duplicate():
		var z: Dictionary = zones[zid]
		if not z.active:
			z.delay -= 1
			if z.delay <= 0:
				z.active = true
			continue
		z.lifetime -= 1
		if z.lifetime <= 0:
			zones.erase(zid)
			continue
		# 拉拽(格级): 区域内敌人每 2 tick 向区域中心拉一格
		if z.pull > 0.0:
			for ent in entities.values():
				if ent.alive and ent.kind in ["hero", "enemy"] and ent.faction != "player" \
						and Grid.dist(ent.grid, z.grid) <= int(z.radius):
					if tick % 2 == 0:
						var dir_i := Grid.direction_toward(ent.grid, z.grid)
						if dir_i != -1:
							var n: Vector2i = ent.grid + Grid.DIRS[dir_i]
							if _cell_free(n):
								_emit_cell_events(ent, ent.grid, n)
								ent.grid = n


func _tick_beams() -> void:
	for b in beams.duplicate():
		b.remains -= 1
		if b.remains <= 0:
			beams.erase(b)
			continue
		if b.remains % 20 == 0:
			var owner: Dictionary = entities.get(b.owner, {})
			if owner.is_empty():
				continue
			var t := get_focus_or_nearest(owner)
			if not t.is_empty() and Grid.dist(t.grid, b.grid) <= 6:
				mechanic_damage(owner.id, t, "beam", b.dmg, "")


func _tick_walls() -> void:
	for w in walls.duplicate():
		w.lifetime -= 1
		if w.lifetime <= 0:
			walls.erase(w)


func _tick_summons() -> void:
	for sid in summons.keys().duplicate():
		var s: Dictionary = summons[sid]
		s.lifetime -= 1
		var ent: Dictionary = entities.get(sid, {})
		if s.lifetime <= 0:
			destroy_entity(sid)
			continue
		if ent.alive and entities.has(s.owner):
			var owner: Dictionary = entities[s.owner]
			# 召唤物跟随主人格(视觉环绕由播放器相位表现)
			ent.grid = owner.grid


## ---------------- 事件与战报 ----------------

func push_event(ev: Dictionary) -> void:
	events.append(ev)


func summary_report() -> Dictionary:
	var out: Dictionary = {}
	for ev in events:
		if ev.get("kind") != "attack":
			continue
		var sid: String = ev.source_id
		if not out.has(sid):
			out[sid] = {"attacks": 0, "hits": 0, "misses": 0, "blocks": 0, "crits": 0, "total_damage": 0.0}
		out[sid].attacks += 1
		if ev.hit_landed == 0:
			out[sid].misses += 1
		elif ev.blocked:
			out[sid].blocks += 1
		else:
			out[sid].hits += 1
			out[sid].total_damage += ev.final_damage
			if ev.crit_tier >= 1.5:
				out[sid].crits += 1
	# 契约统计
	var contract_report: Dictionary = {}
	for cid in contracts.keys():
		var c = contracts[cid]
		var st: Dictionary = c.stats
		var total := 0
		var breached := 0
		for ev_name in st.keys():
			total += int(st[ev_name].count)
			breached += int(st[ev_name].breached)
		contract_report[cid] = {"trigger_total": total, "breaches": breached}
	return {"units": out, "contracts": contract_report}
