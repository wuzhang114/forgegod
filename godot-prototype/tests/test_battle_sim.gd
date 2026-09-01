## B1 战斗 sim 测试: 实体 / 动作帧 / 判定链(六区公式) / 事件对象 / 1v1 全流程。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const DefAction := preload("res://core/runtime/sim_actions.gd")
const Chain := preload("res://core/runtime/damage_chain.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")
const SeedRng := preload("res://core/runtime/rng.gd")

## 可注入的确定性随机源(覆盖 rng.rand_range(0,1) 的返回序列)
class FakeRng:
	var seq: Array = []
	var calls := 0
	func _init(s: Array) -> void:
		seq = s
	func rand_range(_a: float, _b: float) -> float:
		calls += 1
		if seq.is_empty():
			return 0.5
		return seq.pop_front()


var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_entity()
	_test_action_frames()
	_test_damage_chain_hit()
	_test_damage_chain_miss_block()
	_test_damage_chain_formula()
	_test_battle_1v1()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("B1 FAIL: " + label)


## 快速造一个勇者/敌人
func _mk_hero() -> Dictionary:
	return DefEntity.make("hero_1", "hero", "player", "守卫·布兰特", "guard",
		{"hp": 100.0, "atk": 10.0, "armor": 5.0, "hit": 0.9, "evade": 0.05,
			"grid": Vector2i(0, 2)})


func _mk_mob() -> Dictionary:
	return DefEntity.make("mob_1", "enemy", "enemy", "石甲傀儡", "brute",
		{"hp": 60.0, "atk": 5.0, "armor": 8.0, "hit": 0.85, "evade": 0.02,
			"grid": Vector2i(3, 2)})


func _test_entity() -> void:
	var e := _mk_hero()
	_check(e.id == "hero_1" and e.kind == "hero" and e.faction == "player", "实体基础字段")
	_check(e.hp == 100.0 and e.max_hp == 100.0 and e.armor == 5.0, "实体数值字段")
	_check(e.alive and e.statuses.is_empty() and e.current_action.is_empty(), "实体初始状态")
	# 状态挂载/到期
	DefEntity.apply_status(e, "burning", 20, "hero_1")
	_check(DefEntity.has_status(e, "burning"), "状态挂载成功")
	for i in 20:
		DefEntity.tick_statuses(e)
	_check(not DefEntity.has_status(e, "burning"), "状态到期移除")


func _test_action_frames() -> void:
	var e := _mk_hero()
	var sim := BattleSim.new(1)
	sim.add_entity(e)
	# basic: windup 12 / active 6 / recover 14(空目标: 不触发目标中断检查)
	sim.start_action(e, "basic", "")
	_check(e.current_action.phase == "windup", "动作从前摇开始")
	for i in 11:
		sim.decide_all()
		sim.tick_once()
	_check(e.current_action.phase == "windup", "前摇 12 tick 内未进入判定窗")
	sim.tick_once()
	_check(e.current_action.phase == "active", "第 12 tick 进入判定窗")
	for i in 6:
		sim.tick_once()
	_check(e.current_action.phase == "recover", "判定窗结束后进入后摇")
	for i in 14:
		sim.tick_once()
	_check(e.current_action.is_empty(), "后摇结束回到空闲")


func _test_damage_chain_hit() -> void:
	# 命中(roll 0.1 < 0.85) + 暴击(roll 0.99 ≥ 0.85, crit_mult 1.5)
	var attacker := _mk_hero()
	var target := _mk_mob()
	var rng := FakeRng.new([0.1, 0.99])
	var r := Chain.resolve_attack(attacker, target, "basic", rng, 0.0, 0.0, {})
	_check(r.landed and not r.blocked, "命中且未被格挡")
	_check(r.crit_tier == 1.5, "暴击档 1.5")
	# base = 10×1.0; armor_after = 8; defense = 100/108; dmg = 10×1.5×100/108 ≈ 13.888...
	_check(abs(r.final_damage - 10.0 * 1.5 * 100.0 / 108.0) < 0.01,
		"暴击伤害公式 " + str(r.final_damage))
	# 刮痧(roll 0.05 ≤ 0.15)
	var rng2 := FakeRng.new([0.1, 0.05])
	var r2 := Chain.resolve_attack(attacker, target, "basic", rng2, 0.0, 0.0, {})
	_check(r2.crit_tier == 0.7, "刮痧档 0.7")
	# guaranteed_hit 短路 roll
	var rng3 := FakeRng.new([0.99, 0.99])
	var r3 := Chain.resolve_attack(attacker, target, "basic", rng3, 0.0, 0.0,
		{"guaranteed_hit": {"value": true}})
	_check(r3.landed, "guaranteed_hit 必中")


func _test_damage_chain_miss_block() -> void:
	var attacker := _mk_hero()
	var target := _mk_mob()
	# miss(roll 0.95 > 0.85)
	var rng := FakeRng.new([0.95])
	var r := Chain.resolve_attack(attacker, target, "basic", rng, 0.0, 0.0, {})
	_check(not r.landed and r.final_damage == 0.0, "miss 判定: 未命中无伤害")
	# 格挡(guaranteed 命中 + 目标处于 block active)
	var rng2 := FakeRng.new([0.5])
	target.current_action = {"tag": "block", "phase": "active", "t": 0, "windup": 0, "active": 20, "recover": 0}
	var r2 := Chain.resolve_attack(attacker, target, "basic", rng2, 0.0, 0.0,
		{"guaranteed_hit": {"value": true}})
	_check(r2.landed and r2.blocked and r2.final_damage == 0.0, "格挡判定: 伤害归零")
	_check(r2.blocked_damage == 10.0, "格挡记录原始伤害")


func _test_damage_chain_formula() -> void:
	# 六区精确公式: atk 10 × mult 1.0 × (1+0.5 增伤) × crit 1.0 × 100/(100+100 甲) × (1+0.25 独立)
	var attacker := _mk_hero()
	var target := _mk_mob()
	target.armor = 100.0
	var rng := FakeRng.new([0.1, 0.5])
	var r := Chain.resolve_attack(attacker, target, "basic", rng, 0.5, 0.25, {})
	var expected := 10.0 * 1.0 * 1.5 * 1.0 * (100.0 / 200.0) * 1.25
	_check(abs(r.final_damage - expected) < 0.001, "六区公式 9.375, 实际 %s" % str(r.final_damage))
	# 增伤区上限 +100%: dmg_bonus 2.0 应被 clamp 到 1.0
	var rng2 := FakeRng.new([0.1, 0.5])
	var r2 := Chain.resolve_attack(attacker, target, "basic", rng2, 2.0, 0.0, {})
	_check(abs(r2.final_damage - 10.0 * 1.0 * 2.0 * 1.0 * 0.5 * 1.0) < 0.001,
		"增伤区上限 100% 生效")


func _test_battle_1v1() -> void:
	print("-- B1 战斗 1v1 全流程 --")
	var sim := BattleSim.new(42)
	var hero := _mk_hero()
	var mob := _mk_mob()
	sim.add_entity(hero)
	sim.add_entity(mob)
	sim.decide_all()
	var ticks := sim.run(3000)
	_check(ticks < 3000, "战斗在 3000 tick 内结束(实际 %d)" % ticks)
	_check(not mob.alive, "傀儡被击败")
	_check(hero.alive, "守卫存活")
	# 事件对象字段完备性
	var attack_events: Array = []
	for ev in sim.events:
		if ev.get("kind") == "attack":
			attack_events.append(ev)
	_check(attack_events.size() > 0, "存在攻击事件")
	var first: Dictionary = attack_events[0]
	_check(first.has("tick") and first.has("source_id") and first.has("target_id"), "事件: 时间/来源/目标")
	_check(first.has("hit_landed") and first.has("crit_tier") and first.has("base"), "事件: 判定字段")
	_check(first.has("final_damage") and first.has("blocked") and first.has("armor_after"), "事件: 结果字段")
	_check(first.has("statuses") and first.has("cause_ids"), "事件: 状态/因果字段")
	# kill 事件
	var kill_count := 0
	for ev in sim.events:
		if ev.get("kind") == "kill":
			kill_count += 1
	_check(kill_count == 1, "1 次击杀事件")
	# 战报雏形(新结构: units/contracts)
	var report := sim.summary_report()
	var hero_report: Dictionary = report.get("units", {}).get("hero_1", {})
	_check(hero_report.get("hits", 0) > 0, "战报: 守卫有命中记录")
	_check(float(hero_report.get("total_damage", 0.0)) >= mob.max_hp - 1.0, "战报: 总伤害覆盖傀儡血量")
	# 确定性: 相同 seed 复跑, 事件数一致
	var sim2 := BattleSim.new(42)
	var hero2 := _mk_hero()
	var mob2 := _mk_mob()
	sim2.add_entity(hero2)
	sim2.add_entity(mob2)
	sim2.decide_all()
	sim2.run(3000)
	_check(sim2.events.size() == sim.events.size(), "同 seed 事件流一致(%d/%d)" % [sim2.events.size(), sim.events.size()])
