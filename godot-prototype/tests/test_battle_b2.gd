## B2 战斗 sim 测试: 3vN、三定位、契约接入(事件驱动)、指令、确定性。
## 由 run_headless.gd 调用。

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")

const SRC_QI := """
device 罡气 {
  budget: { steps: 16, cooldown: 0 }
  on attack {
    if hit_landed > 0 {
      damage(target, "impact", 2)
    }
  }
}
"""

const SRC_BULWARK := """
device 蓄能盾击 {
  auth: item
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

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_compile_contracts()
	_test_contract_event_drive()
	_test_battle_3vn()
	_test_commands()
	_test_determinism()
	_test_tft_rules()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("B2 FAIL: " + label)


func _compile(src: String) -> Dictionary:
	var p := Parser.new()
	var parsed := p.parse(src)
	if not parsed.ok:
		return {"ok": false, "errors": parsed.errors}
	var c := Checker.new()
	var checked := c.check(parsed.ast)
	return {"ok": checked.ok, "errors": checked.errors, "ast": checked.ast}


func _mk_team() -> Array:
	var guard := DefEntity.make("hero_1", "hero", "player", "守卫·布兰特", "guard",
		{"hp": 100.0, "atk": 10.0, "armor": 5.0, "grid": Vector2i(1, 1)})
	var duelist := DefEntity.make("hero_2", "hero", "player", "连击手·莉娅", "duelist",
		{"hp": 90.0, "atk": 8.0, "armor": 3.0, "hit": 0.92, "grid": Vector2i(3, 1)})
	var ranger := DefEntity.make("hero_3", "hero", "player", "射手·锡拉", "ranger",
		{"hp": 80.0, "atk": 11.0, "armor": 2.0, "hit": 0.95, "range_hex": 4, "grid": Vector2i(5, 0)})
	return [guard, duelist, ranger]


func _mk_mobs(count: int = 5) -> Array:
	var out: Array = []
	for i in count:
		out.append(DefEntity.make("enemy_%d" % (i + 1), "enemy", "enemy", "石甲傀儡", "brute",
			{"hp": 40.0, "atk": 4.0, "armor": 3.0, "hit": 0.85, "evade": 0.02,
				"grid": Vector2i(i, 3)}))
	return out


func _make_sim(world_flags: Dictionary = {}) -> Dictionary:
	var sim := BattleSim.new(7)
	var team := _mk_team()
	for e in team:
		sim.add_entity(e)
	for m in _mk_mobs():
		sim.add_entity(m)
	for f in world_flags.keys():
		sim.world_flags[f] = world_flags[f]
	return {"sim": sim, "team": team}


func _test_compile_contracts() -> void:
	var r := _compile(SRC_QI)
	_check(r.ok, "罡气契约通过校验 " + str(r.get("errors", [])))
	var r2 := _compile(SRC_BULWARK)
	_check(r2.ok, "蓄能盾击契约通过校验 " + str(r2.get("errors", [])))


func _test_contract_event_drive() -> void:
	print("-- B2 契约事件驱动 --")
	var setup := _make_sim()
	var sim = setup.sim
	var guard: Dictionary = setup.team[0]
	# 注册两个契约到守卫
	sim.add_contract("c_qi", _compile(SRC_QI).ast, guard.id, {"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []})
	sim.add_contract("c_bulwark", _compile(SRC_BULWARK).ast, guard.id, {"id": "w_2", "max_durability": 100.0, "durability": 100.0, "defects": []})
	# 直接喂 block 事件(确定性): 两次 20 伤害格挡 -> charge 8
	sim.contracts["c_bulwark"].on_event("block", {"blocked_damage": 20.0, "tick": 1})
	sim.contracts["c_bulwark"].on_event("block", {"blocked_damage": 20.0, "tick": 2})
	var charge: float = sim.contracts["c_bulwark"].vm.get_state().charge
	_check(charge == 8.0, "两次格挡积满 charge=8, 实际 %s" % str(charge))
	# heavy_blow 释放 -> 12 机制伤害
	var mob: Dictionary = sim.get_entity("enemy_1")
	sim.contracts["c_bulwark"].on_event("heavy_blow", {"target": mob, "tick": 3})
	var mech_count := 0
	var mech_total := 0.0
	for ev in sim.events:
		if ev.get("kind") == "mechanic_damage":
			mech_count += 1
			mech_total += ev.amount
	_check(mech_count == 1 and mech_total == 12.0, "蓄能盾击释放 12 伤 (count=%d)" % mech_count)
	_check(sim.contracts["c_bulwark"].vm.get_state().charge == 0.0, "释放后清零")
	_check(mob.hp == 40.0 - 12.0, "目标受到 12 伤害, 剩余 %s" % str(mob.hp))
	# 过载(charge 未满 4 不触发; 再喂 2 次 block 后触发 30 伤 + 4 耐久)
	sim.contracts["c_bulwark"].on_event("block", {"blocked_damage": 10.0, "tick": 4})
	sim.contracts["c_bulwark"].on_event("block", {"blocked_damage": 10.0, "tick": 5})
	sim.cmd_overload("c_bulwark")
	var mech2 := 0.0
	for ev in sim.events:
		if ev.get("kind") == "mechanic_damage" and ev.amount == 30.0:
			mech2 = ev.amount
	_check(mech2 == 30.0, "过载第二形态 30 伤")
	var w_cost := 0.0
	for ev in sim.events:
		if ev.get("kind") == "weapon_cost" and ev.amount == 4.0:
			w_cost = ev.amount
	_check(w_cost == 4.0, "过载代价 4 耐久")
	# 罡气: 喂一次命中攻击 -> 追加 2 点机制伤害(用活目标 enemy_2)
	var mob2: Dictionary = sim.get_entity("enemy_2")
	sim.contracts["c_qi"].on_event("attack", {"target": mob2, "attack_damage": 10.0, "hit_landed": 1, "hit_crit": 1.0, "tick": 5})
	var qi_events := 0
	for ev in sim.events:
		if ev.get("kind") == "mechanic_damage" and ev.amount == 2.0:
			qi_events += 1
	_check(qi_events == 1, "罡气命中追加 2 伤")


func _test_battle_3vn() -> void:
	print("-- B2 3vN 全流程(守卫+连击+射手 vs 5 敌) --")
	var setup := _make_sim()
	var sim = setup.sim
	var guard: Dictionary = setup.team[0]
	sim.add_contract("c_qi", _compile(SRC_QI).ast, guard.id,
		{"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []})
	var ticks: int = sim.run(3000)
	_check(ticks < 3000, "战斗 3000 tick 内结束(实际 %d)" % ticks)
	_check(sim.battle_result == "player_win", "玩家胜利(实际 %s)" % sim.battle_result)
	_check(sim._enemy_alive() == 0, "敌人全灭")
	var heroes_alive := 0
	for e in sim.entities.values():
		if e.kind == "hero" and e.alive:
			heroes_alive += 1
	_check(heroes_alive > 0, "至少一名勇士存活")
	# 契约运行时统计
	var report: Dictionary = sim.summary_report()
	var contracts_stat: Dictionary = report.get("contracts", {})
	_check(contracts_stat.has("c_qi"), "战报含契约统计")
	if contracts_stat.has("c_qi"):
		_check(contracts_stat.c_qi.trigger_total > 0, "罡气在战斗中实际触发 %d 次" % contracts_stat.c_qi.trigger_total)
	# 战斗事件流有攻击与击杀
	var attack_count := 0
	var kill_count := 0
	for ev in sim.events:
		if ev.get("kind") == "attack":
			attack_count += 1
		if ev.get("kind") == "kill":
			kill_count += 1
	_check(attack_count > 10, "攻击事件丰富(%d)" % attack_count)
	_check(kill_count >= 5, "至少 5 次击杀(%d)" % kill_count)


func _test_commands() -> void:
	print("-- B2 指令队列 --")
	var setup := _make_sim()
	var sim = setup.sim
	var guard: Dictionary = setup.team[0]
	sim.cmd_focus(guard.id, "enemy_3")
	_check(guard.focus_target == "enemy_3", "集火指令写入倾向目标")
	_check(sim.input_log.size() == 1 and sim.input_log[0].cmd == "focus", "指令进入输入流(确定性)")
	var duelist: Dictionary = setup.team[1]
	sim.cmd_protect(duelist.id, guard.id)
	_check(duelist.protect_target == guard.id, "保护指令写入")
	sim.cmd_retreat()
	_check(sim.battle_result == "retreat", "撤退指令生效")


func _test_determinism() -> void:
	print("-- B2 确定性 --")
	var run_once := func() -> int:
		var setup := _make_sim()
		var g: Dictionary = setup.team[0]
		setup.sim.add_contract("c_qi", _compile(SRC_QI).ast, g.id,
			{"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []})
		setup.sim.cmd_focus(g.id, "enemy_2")
		setup.sim.run(3000)
		return setup.sim.events.size()
	var n1: int = run_once.call()
	var n2: int = run_once.call()
	_check(n1 == n2, "同 seed + 同指令 → 事件流一致(%d/%d)" % [n1, n2])


## 金铲铲对照修复验证(索敌/打断/状态接线/攻速)
func _test_tft_rules() -> void:
	print("-- B2.5 金铲铲对照: 受击转火/打断/状态接线/攻速 --")
	var setup := _make_sim()
	var sim = setup.sim
	var guard: Dictionary = setup.team[0]
	var duelist: Dictionary = setup.team[1]
	var mob: Dictionary = sim.get_entity("enemy_1")
	# 1) 受击转火: 敌人被打后(无手动集火)优先反击攻击者
	mob.focus_manual = false
	sim.start_action(duelist, "basic", mob.id)
	# 推进到判定窗(basic 前摇 12 tick)
	for i in 18:
		sim.tick_once()
	_check(mob.focus_target == duelist.id, "受击转火: 反击攻击者 (实际 %s)" % mob.focus_target)
	# 手动集火不被覆盖
	mob.focus_manual = true
	mob.focus_target = "enemy_2"
	sim.start_action(duelist, "basic", mob.id)
	for i in 12:
		sim.tick_once()
	_check(mob.focus_target == "enemy_2", "手动集火不被受击转火覆盖")
	mob.focus_manual = false
	# 2) 硬控打断: 攻击中被打晕 -> 动作清空 + interrupt 事件
	var fresh := _make_sim()
	sim = fresh.sim
	guard = fresh.team[0]
	var mobA: Dictionary = sim.get_entity("enemy_1")
	sim.start_action(guard, "heavy_blow", mobA.id)
	for i in 5:
		sim.tick_once()
	DefEntity.apply_status(guard, "stunned", 30, "enemy_1")
	sim.tick_once()
	_check(guard.current_action.is_empty(), "眩晕打断当前动作")
	var interrupt_count := 0
	for ev in sim.events:
		if ev.get("kind") == "interrupt":
			interrupt_count += 1
	_check(interrupt_count == 1, "打断事件记录")
	# 3) 嘲讽: 强制攻击嘲讽来源(即使距离内有其他敌人)
	sim = _make_sim().sim
	var duelist2: Dictionary = sim.get_entity("hero_2")
	var mob_a: Dictionary = sim.get_entity("enemy_1")
	var mob_b: Dictionary = sim.get_entity("enemy_2")
	mob_a.grid = Vector2i(1, 2)   # 相邻的敌人
	mob_b.grid = Vector2i(4, 1)   # 远处的嘲讽来源
	DefEntity.apply_status(duelist2, "taunted", 60, mob_b.id)
	# 触发决策
	sim.decide(duelist2)
	_check(duelist2.current_action.get("target_id", "") == mob_b.id, "嘲讽强制索敌(而不是最近的 enemy_1)")
	# 4) 缄默: 远程被缄默后降级为普攻
	sim = _make_sim().sim
	var ranger: Dictionary = sim.get_entity("hero_3")
	DefEntity.apply_status(ranger, "silenced", 90, "enemy_1")
	ranger.current_action = {}
	sim.decide(ranger)
	_check(ranger.current_action.get("tag", "") == "basic", "缄默: 远程降级普攻 (实际 %s)" % ranger.current_action.get("tag", ""))
	# 5) 缴械: 禁攻击
	DefEntity.apply_status(ranger, "disarmed", 90, "enemy_1")
	ranger.current_action = {}
	sim.decide(ranger)
	_check(ranger.current_action.is_empty(), "缴械: 无法攻击")
	# 6) 攻速: 急速状态缩短动作帧
	var sim6 := BattleSim.new(3)
	var fast := DefEntity.make("f", "hero", "player", "快", "duelist",
		{"hp": 100.0, "atk": 8.0, "grid": Vector2i(0, 0), "atk_speed": 1.5})
	DefEntity.apply_status(fast, "haste", 120, "self")
	sim6.add_entity(fast)
	sim6.start_action(fast, "basic", "x")
	var base_windup := int(12.0 * DefEntity.frame_mult(fast))
	_check(base_windup < 12, "急速缩短动作帧(前摇 %d < 12)" % base_windup)
	# 缓慢: slowed 延长
	DefEntity.apply_status(fast, "slowed", 120, "self")
	sim6.start_action(fast, "basic", "x")
	var slow_windup := int(12.0 * DefEntity.frame_mult(fast))
	_check(slow_windup > base_windup, "减速延长动作帧(%d > %d)" % [slow_windup, base_windup])
	# 7) 目标死亡中断: 前摇中目标死亡 -> 动作清空(不空打)
	sim = _make_sim().sim
	var guard2: Dictionary = sim.get_entity("hero_1")
	var mob1: Dictionary = sim.get_entity("enemy_1")
	sim.start_action(guard2, "heavy_blow", mob1.id)
	for i in 5:
		sim.tick_once()
	mob1.alive = false
	sim.tick_once()
	_check(guard2.current_action.is_empty(), "目标死亡: 前摇中断,立即重新索敌")
	# 8) 堵路绕行: 前排被友军占住仍能绕行接近敌人目标
	sim = BattleSim.new(3)
	var h := DefEntity.make("h", "hero", "player", "测试", "duelist",
		{"hp": 100.0, "atk": 1.0, "grid": Vector2i(3, 1)})
	var blocker := DefEntity.make("bl", "hero", "player", "友军", "guard",
		{"hp": 99999.0, "atk": 0.1, "grid": Vector2i(3, 2)})
	var goal := DefEntity.make("gl", "enemy", "enemy", "目标", "brute",
		{"hp": 99999.0, "atk": 0.1, "grid": Vector2i(3, 4)})
	for ent in [h, blocker, goal]:
		sim.add_entity(ent)
	# 两个站桩(超长前摇,不移动不攻击)
	blocker.current_action = {"tag": "basic", "target_id": "", "phase": "windup", "t": 0, "windup": 99999, "active": 0, "recover": 0}
	goal.current_action = {"tag": "basic", "target_id": "", "phase": "windup", "t": 0, "windup": 99999, "active": 0, "recover": 0}
	var start_grid: Vector2i = h.grid
	for i in 300:
		sim.tick_once()
	_check(h.grid != start_grid, "堵路绕行: 单位成功移动(从 %s 到 %s)" % [str(start_grid), str(h.grid)])
	_check(Grid2.dist(h.grid, goal.grid) <= 1, "绕行后抵达目标旁边(距离 %d)" % Grid2.dist(h.grid, goal.grid))
	# 9) 目标死亡: 非手动 focus 即时清空(转火走位)
	sim = _make_sim().sim
	var duel9: Dictionary = sim.get_entity("hero_2")
	var eA: Dictionary = sim.get_entity("enemy_1")
	duel9.focus_target = eA.id
	eA.alive = false
	sim._kill(sim.get_entity("hero_1"), eA)
	_check(duel9.focus_target == "", "目标死亡 → 非手动 focus 即时清空(转火)")


const Grid2 := preload("res://core/runtime/hex_grid.gd")
