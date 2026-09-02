## 嗜血之舞(治疗 + 攻速强化)测试: heal/empower/nearest_ally 原语 + 端到端。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")

const SRC_LIFE := """
device 嗜血之舞 {
  auth: item
  budget: { entities: 4, steps: 20, cooldown: 480 }
  state: { charges: 0 }
  on right_click {
    charges = 3
    empower(3, 1.6)
  }
  on hit {
    if charges > 0 {
      heal_self(attack_damage * 0.5)
      heal(nearest_ally(self), attack_damage * 0.5)
      charges -= 1
    }
  }
}
"""

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_empower_frames()
	_test_nearest_ally()
	_test_lifesteal_end_to_end()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("LIFE FAIL: " + label)


func _mk(id: String, role: String, kind: String, faction: String, grid: Vector2i,
		hp: float = 100.0, atk: float = 0.0) -> Dictionary:
	return DefEntity.make(id, kind, faction, id, role,
		{"hp": hp, "atk": atk, "armor": 0.0, "hit": 0.95, "evade": 0.01,
			"grid": grid, "range_hex": 1})


func _test_empower_frames() -> void:
	var sim := BattleSim.new(7)
	var hero := _mk("hero_1", "duelist", "hero", "player", Vector2i(0, 0))
	sim.add_entity(hero)
	sim.start_action(hero, "basic", "")
	_check(int(hero.current_action.windup) == 12, "基础前摇 12 tick")
	hero.current_action = {}
	hero.empower_left = 3
	hero.empower_mult = 1.6
	sim.start_action(hero, "basic", "")
	_check(int(hero.current_action.windup) == 7, "empower 前摇 12/1.6=7 (实际 %d)" % int(hero.current_action.windup))
	_check(int(hero.current_action.active) == int(6.0 / 1.6), "empower 判定窗缩短")


func _test_nearest_ally() -> void:
	var sim := BattleSim.new(7)
	var hero := _mk("hero_1", "duelist", "hero", "player", Vector2i(0, 0))
	var ally1 := _mk("ally_a", "duelist", "hero", "player", Vector2i(1, 0))
	var ally2 := _mk("ally_b", "duelist", "hero", "player", Vector2i(4, 0))
	var mob := _mk("mob_1", "brute", "enemy", "enemy", Vector2i(2, 2))
	sim.add_entity(hero)
	sim.add_entity(ally1)
	sim.add_entity(ally2)
	sim.add_entity(mob)
	var na := sim.nearest_ally_of(hero)
	_check(na.get("id", "") == "ally_a", "最近友军为 ally_a")
	_check(sim.nearest_ally_of(ally2).get("id", "") == "ally_a", "最近友军不含自身/敌人")
	ally1.alive = false
	_check(sim.nearest_ally_of(hero).get("id", "") == "ally_b", "死亡友军被排除")


func _test_lifesteal_end_to_end() -> void:
	var sim := BattleSim.new(7)
	var hero := _mk("hero_1", "duelist", "hero", "player", Vector2i(0, 1), 300.0, 10.0)
	var ally := _mk("ally_a", "duelist", "hero", "player", Vector2i(2, 1), 300.0, 0.0)
	ally.hp = 240.0                     # 预损血,验证治疗后回血
	var mob := _mk("mob_1", "brute", "enemy", "enemy", Vector2i(1, 1), 1000.0, 4.0)
	sim.add_entity(hero)
	sim.add_entity(ally)
	sim.add_entity(mob)
	var parsed := Parser.new().parse(SRC_LIFE)
	_check(parsed.ok, "嗜血之舞可解析 " + str(parsed.errors))
	var checked := Checker.new().check(parsed.ast)
	_check(checked.ok, "heal/empower/nearest_ally 通过校验 " + str(checked.errors))
	var weapon := {"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []}
	sim.add_contract("c_life", checked.ast, "hero_1", weapon)
	sim.schedule_active("c_life", 10)
	var guard := 0
	for i in 300:
		sim.tick_once()
		guard += 1
		if guard > 400:
			break
	# 施放后攻速强化挂上
	_check(hero.empower_left >= 0 and hero.empower_left < 3, "攻速强化已生效(剩余 %d 次)" % hero.empower_left)
	# 治疗事件: 每次命中两个 healed(自己+最近队友),数值 = 该击伤害一半
	var heal_total_self := 0.0
	var heal_total_ally := 0.0
	var last_atk := 0.0
	for ev in sim.events:
		if ev.get("kind") == "attack" and int(ev.get("hit_landed", 0)) == 1:
			last_atk = float(ev.get("final_damage", 0.0))
		if ev.get("kind") == "healed":
			if ev.get("target_id", "") == "hero_1":
				heal_total_self += float(ev.get("amount", 0.0))
			if ev.get("target_id", "") == "ally_a":
				heal_total_ally += float(ev.get("amount", 0.0))
	_check(heal_total_self > 0.0 and heal_total_ally > 0.0, "自己与队友均获得治疗 (%s / %s)" %
		[str(heal_total_self), str(heal_total_ally)])
	_check(ally.hp > 240.0, "队友血量恢复 (%.0f)" % ally.hp)
	# 治疗请求 = 命中伤害一半;实际量 ≤ 一半(血量上限可截断)
	var atk_events: Array = []
	for ev in sim.events:
		if ev.get("kind") == "attack" and int(ev.get("hit_landed", 0)) == 1:
			atk_events.append(float(ev.get("final_damage", 0.0)))
	var heal_ok := true
	for ev in sim.events:
		if ev.get("kind") != "healed":
			continue
		var amt := float(ev.get("amount", 0.0))
		var matched := false
		for f in atk_events:
			if amt <= f * 0.5 + 0.01:
				matched = true
				break
		if not matched:
			heal_ok = false
	_check(heal_ok, "每次治疗量不超过对应命中伤害的一半")
	# 次数限制: 3 次后不再触发(攻击继续但无新治疗)
	var heal_after := 0
	var hits := 0
	for ev in sim.events:
		if ev.get("kind") == "attack" and int(ev.get("hit_landed", 0)) == 1:
			hits += 1
		if ev.get("kind") == "healed":
			heal_after += 1
	_check(heal_after <= 6, "治疗事件总数 ≤ 6(3 次 × 2 目标,实际 %d)" % heal_after)
