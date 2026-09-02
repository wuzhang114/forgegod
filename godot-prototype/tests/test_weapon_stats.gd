## 武器面板(锻造->战斗生效)测试: 数值映射 / 缺陷 / apply_to_opt / 端到端伤害 / 契约 traits 接缝。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")
const Chain := preload("res://core/runtime/damage_chain.gd")
const Forge := preload("res://core/forge/forge_core.gd")
const WeaponStats := preload("res://core/forge/weapon_stats.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_numbers()
	_test_defects()
	_test_apply_opt()
	_test_end_to_end_damage()
	_test_traits_seam()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("WSTATS FAIL: " + label)


class FakeRng:
	var seq: Array = []
	func _init(s: Array) -> void:
		seq = s
	func rand_range(_a: float, _b: float) -> float:
		if seq.is_empty():
			return 0.5
		return seq.pop_front()


func _test_numbers() -> void:
	# 顶级锻造: 四维 90
	var hi := WeaponStats.from_facts({"craft": {"purity": 90.0, "structure": 90.0,
		"temper": 90.0, "balance": 90.0}, "defects": []})
	_check(absf(hi.atk_mult - (0.75 + 0.5 * 0.9)) < 0.001, "atk_mult 顶级 (实际 %s)" % str(hi.atk_mult))
	_check(absf(hi.crit_mult - (1.10 + 0.6 * 0.9)) < 0.001, "crit_mult 顶级 (实际 %s)" % str(hi.crit_mult))
	_check(absf(hi.shred - (90 - 50) * 0.02) < 0.001, "shred 破甲 (实际 %s)" % str(hi.shred))
	_check(absf(hi.wbonus - (90 - 55) / 100.0 * 0.6) < 0.001, "wbonus 独立区 (实际 %s)" % str(hi.wbonus))
	_check(absf(hi.durability - (50 + 0.5 * 90)) < 0.001, "耐久 (实际 %s)" % str(hi.durability))
	_check(absf(hi.hit - (0.75 + 0.25 * 0.9)) < 0.001, "命中 (实际 %s)" % str(hi.hit))
	# 锻造产物真实路径: build -> stats
	var parts := {"action": "yellow_steel", "bearing": "grey_iron", "control": "grey_iron", "medium": ""}
	var size := {"length": 0.5, "thickness": 0.5, "balance": 0.5}
	var facts := Forge.build("t1", "sword", "试剑", parts, size,
		{"purity_roll": 0.95, "quench": "salt", "temper": false, "keep_stress": false,
			"techniques": ["fold", "crystal"], "balance_bias": false, "style": "steady"})
	var ws := WeaponStats.from_facts(facts)
	_check(ws.durability > 0.0 and ws.atk_mult > 0.0 and ws.crit_mult > 1.0,
		"forge产物可换算面板 %s" % str(facts.craft))
	_check(ws.defects is Array, "MechLang 兼容 defects 数组")


func _test_defects() -> void:
	var wd := WeaponStats.from_facts({"craft": {"purity": 90.0, "structure": 90.0,
		"temper": 90.0, "balance": 90.0}, "defects": [
		{"id": "defect.impurity"}, {"id": "defect.weak_structure"},
		{"id": "defect.off_balance"}, {"id": "defect.stress_crack"}]})
	_check("impurity" in wd.defects and "stress_crack" in wd.defects, "缺陷词进 MechLang 数组")
	_check(wd.hit < 0.75 + 0.25 * 0.9, "杂质降低命中 (实际 %s)" % str(wd.hit))
	_check(wd.durability < 50 + 0.5 * 90, "松散降低耐久 (实际 %s)" % str(wd.durability))
	_check(wd.speed_mult < 0.9 + 0.2 * 0.9, "偏重降低攻速 (实际 %s)" % str(wd.speed_mult))
	# 全部缺陷的武器应当全面劣化
	var wd_all := WeaponStats.from_facts({"craft": {"purity": 90.0, "structure": 90.0,
		"temper": 90.0, "balance": 90.0}, "defects": [
		{"id": "defect.impurity"}, {"id": "defect.weak_structure"},
		{"id": "defect.off_balance"}]})
	var clean := WeaponStats.from_facts({"craft": {"purity": 90.0, "structure": 90.0,
		"temper": 90.0, "balance": 90.0}, "defects": []})
	_check(wd_all.hit < clean.hit and wd_all.durability < clean.durability
		and wd_all.speed_mult < clean.speed_mult, "缺陷全面劣化")


func _test_apply_opt() -> void:
	var ws := WeaponStats.from_facts({"craft": {"purity": 80.0, "structure": 70.0,
		"temper": 90.0, "balance": 80.0}, "defects": []})
	var opt := {"atk": 10.0, "hit": 0.9, "crit_mult": 1.5, "atk_speed": 1.0}
	WeaponStats.apply_to_opt(opt, ws)
	_check(absf(opt.atk - 10.0 * ws.atk_mult) < 0.001, "攻击进基础攻击区")
	_check(absf(opt.hit - 0.9 * ws.hit) < 0.001, "命中乘入")
	_check(absf(opt.crit_mult - ws.crit_mult) < 0.001, "暴击档=武器面板")
	_check(absf(opt.weapon_shred - ws.shred) < 0.001, "武器破甲注入")
	_check(absf(opt.weapon_bonus - ws.wbonus) < 0.001, "武器独立区注入")
	_check(absf(opt.atk_speed - ws.speed_mult) < 0.001, "攻速注入")


func _test_end_to_end_damage() -> void:
	# 同一位攻击者, 有/无武器面板 -> 基础攻击区生效(伤害按比例提升)
	var ws := WeaponStats.from_facts({"craft": {"purity": 96.0, "structure": 92.0,
		"temper": 90.0, "balance": 88.0}, "defects": []})
	var opt_no := {"atk": 10.0, "hit": 0.9, "armor": 5.0, "grid": Vector2i(0, 2), "range_hex": 1}
	var opt_yes := opt_no.duplicate()
	WeaponStats.apply_to_opt(opt_yes, ws)
	var a := DefEntity.make("a", "hero", "player", "a", "guard", opt_no)
	var b := DefEntity.make("b", "hero", "player", "b", "guard", opt_yes)
	var tgt := DefEntity.make("t", "enemy", "enemy", "t", "brute", {"hp": 1000.0, "armor": 8.0,
		"hit": 0.85, "evade": 0.02, "grid": Vector2i(3, 2), "range_hex": 1})
	var r1 := Chain.resolve_attack(a, tgt, "basic", FakeRng.new([0.5, 0.5]), 0.0, 0.0, {})
	var r2 := Chain.resolve_attack(b, tgt, "basic", FakeRng.new([0.5, 0.5]), 0.0, 0.0, {})
	_check(r1.landed and r2.landed, "双方命中")
	_check(r2.final_damage > r1.final_damage, "武器提升伤害: %s > %s" % [str(r2.final_damage), str(r1.final_damage)])
	_check(r2.base > r1.base, "提升发生在基础攻击区")
	_check(r2.final_damage / r1.final_damage > ws.atk_mult * 0.95, "伤害比≈atk_mult×独立区")


## traits 接缝: 契约 traits(guaranteed_hit)在战斗结算中真实生效
const SRC_GHIT := """
device 锁定圣剑 {
  auth: item
  traits: { guaranteed_hit: true }
  budget: { steps: 16, cooldown: 0 }
  on attack {
    if hit_landed > 0 {
      damage(target, "radiant", 5)
    }
  }
}
"""


func _test_traits_seam() -> void:
	var sim := BattleSim.new(7)
	var hero := DefEntity.make("hero_1", "hero", "player", "勇者", "duelist",
		{"hp": 100.0, "atk": 8.0, "armor": 3.0, "hit": 0.9, "evade": 0.05,
			"grid": Vector2i(0, 2), "range_hex": 1})
	# 高闪避目标: 无特性时命中率仅 0.05, 特性应必中
	var mob := DefEntity.make("mob_1", "enemy", "enemy", "闪避傀儡", "brute",
		{"hp": 200.0, "atk": 0.0, "armor": 0.0, "hit": 0.85, "evade": 0.95,
			"grid": Vector2i(1, 2), "range_hex": 1})
	DefEntity.apply_status(mob, "rooted", 99999, "t")
	DefEntity.apply_status(mob, "stunned", 99999, "t")
	sim.add_entity(hero)
	sim.add_entity(mob)
	var parsed := Parser.new().parse(SRC_GHIT)
	var checked := Checker.new().check(parsed.ast)
	_check(checked.ok, "锁定圣剑通过校验 " + str(checked.errors))
	sim.add_contract("c_ghit", checked.ast, "hero_1", {"id": "w_1",
		"max_durability": 100.0, "durability": 100.0, "defects": []})
	var all_hit := true
	var attack_count := 0
	var guard := 0
	while sim.tick <= 300 and attack_count < 3:
		sim.tick_once()
		for ev in sim.events:
			if ev.get("kind") == "attack" and ev.get("hit_landed", -1) >= 0:
				attack_count += 1
				if int(ev.get("hit_landed", 0)) != 1:
					all_hit = false
		guard += 1
		if guard > 800:
			break
	_check(attack_count >= 2, "产生了多次攻击 (实际 %d)" % attack_count)
	_check(all_hit, "guaranteed_hit traits 生效(面对闪避目标全部命中)")
