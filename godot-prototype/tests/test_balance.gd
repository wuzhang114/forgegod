## 数值源(Balance)守护测试: 六区公式/三档边界/模板/状态表一致性。
## 由 run_headless.gd 调用。

extends RefCounted

const Bal := preload("res://core/config/balance.gd")
const Chain := preload("res://core/runtime/damage_chain.gd")

var _passes := 0
var _fails := 0


class FakeRng:
	var seq: Array = []
	func _init(s: Array) -> void:
		seq = s
	func rand_range(_a: float, _b: float) -> float:
		if seq.is_empty():
			return 0.5
		return seq.pop_front()


func _mk(armor: float = 0.0) -> Dictionary:
	return {"atk": 10.0, "hit": 0.9, "crit_mult": 1.5, "armor": armor, "evade": 0.0,
		"current_action": {}, "grid": Vector2i.ZERO, "hp": 50.0, "max_hp": 50.0, "alive": true}


func run() -> Dictionary:
	_test_damage_formula_constants()
	_test_crit_tiers()
	_test_templates()
	_test_status_table()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("BAL FAIL: " + label)


func _test_damage_formula_constants() -> void:
	# 引用的 BattleSim 数值与 Balance 一致
	_check(float(Bal.DAMAGE.BONUS_CAP) == 1.0, "增伤区上限 +100%")
	_check(float(Bal.DAMAGE.ARMOR_BASE) == 100.0, "护甲对抗基数 100")
	# 六区精确公式: atk10 × basic1.0 × (1+0.5) × crit1.0 × 100/(100+100) × (1+0.25) = 9.375
	var t := _mk(100.0)
	var r := Chain.resolve_attack(_mk(), t, "basic", FakeRng.new([0.1, 0.5]), 0.5, 0.25, {})
	_check(abs(r.final_damage - 9.375) < 0.001, "六区公式 9.375 (实际 %s)" % str(r.final_damage))
	# 增伤区 clamp
	var r2 := Chain.resolve_attack(_mk(), _mk(0.0), "basic", FakeRng.new([0.1, 0.5]), 5.0, 0.0, {})
	_check(abs(r2.final_damage - (10.0 * 2.0)) < 0.001, "增伤区超限被 clamp(basic 无甲)")


func _test_crit_tiers() -> void:
	var c: Dictionary = Bal.CRIT
	# 边界: roll 0.9 -> 暴击 ×1.5
	var r := Chain.resolve_attack(_mk(), _mk(0.0), "basic", FakeRng.new([0.1, 0.9]), 0.0, 0.0, {})
	_check(r.crit_tier == 1.5, "暴击档 1.5")
	var r2 := Chain.resolve_attack(_mk(), _mk(0.0), "basic", FakeRng.new([0.1, 0.05]), 0.0, 0.0, {})
	_check(r2.crit_tier == 0.7, "刮痧档 0.7")
	var r3 := Chain.resolve_attack(_mk(), _mk(0.0), "basic", FakeRng.new([0.1, 0.5]), 0.0, 0.0, {})
	_check(r3.crit_tier == 1.0, "普通档 1.0")


func _test_templates() -> void:
	_check(Bal.hero_tpl("ranger").range_hex == 4, "射手射程 4 格")
	_check(Bal.enemy_tpl("shooter").range_hex == 4, "远程敌射程 4")
	_check(Bal.enemy_tpl("purger").hp == 150.0, "净化者血 150(×3)")
	_check(Bal.hero_tpl("guard").hp == 300.0 and Bal.hero_tpl("duelist").hp == 270.0, "勇者模板(×3)")
	_check(Bal.STATUS.has("burning") and Bal.STATUS.burning.stacks_max == 3, "状态表含 DoT 层数上限")
	_check(Bal.ACTION.heavy_blow == 1.5 and Bal.ACTION.block == 0.0, "动作倍率表")


func _test_status_table() -> void:
	# 状态表与 25 态定义对齐(抽查全量 id 存在)
	var ids := ["burning", "poisoned", "bleeding", "withering", "stunned", "rooted", "frozen",
		"floating", "slowed", "weakened", "paralyzed", "silenced", "disarmed", "feared",
		"taunted", "trapped", "cursed", "corrupted", "enraged", "guarded", "invisible",
		"haste", "shield", "mined", "weak_point"]
	var missing: Array = []
	for s in ids:
		if not Bal.STATUS.has(s):
			missing.append(s)
	_check(missing.is_empty(), "25 态全部在数值表登记(缺 %s)" % str(missing))
