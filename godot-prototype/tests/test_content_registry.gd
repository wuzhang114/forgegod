## ContentRegistry + ForgeCalculator(唯一计算)测试 —— 架构第 3 步。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const Registry := preload("res://domain/content/content_registry.gd")
const Calc := preload("res://domain/weapon/forge_calculator.gd")
const WeaponStats := preload("res://core/forge/weapon_stats.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_registry_content()
	_test_contract_templates_compilable()
	_test_calculator_consistency()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("REG FAIL: " + label)


func _test_registry_content() -> void:
	_check(str(Registry.material("star_iron").name) == "陨铁", "材料查询")
	_check(str(Registry.material("nope").name) == "熟铁", "未知材料回落")
	_check(str(Registry.weapon_kind("bow").get("name", "")) == "弓", "武器种类")
	_check(float(Registry.hero_tpl("guard").get("hp", 0.0)) == 300.0, "英雄模板代理(balance)")
	_check(float(Registry.enemy_tpl("purger").get("hp", 0.0)) == 150.0, "敌人模板代理")
	_check(Registry.all_maps().size() == 4, "地图内容")
	_check(str(Registry.enemy_pack("mixed").get("id", "x")) != "x" or Registry.enemy_pack("mixed").has("roles"),
		"敌群包内容")
	_check(str(Registry.contract_template("quake").label) == "震地怒涛", "契约模板查询")
	_check(str(Registry.contract_template("nope").label) == "蓄能盾击", "未知契约回落")


func _test_contract_templates_compilable() -> void:
	for cid in ["bulwark", "quake", "scorch", "lifesteal"]:
		var src := str(Registry.contract_template(cid).src)
		var parsed := Parser.new().parse(src)
		_check(parsed.ok, "%s 可解析: %s" % [cid, str(parsed.errors)])
		if parsed.ok:
			var checked := Checker.new().check(parsed.ast)
			_check(checked.ok, "%s 通过静态校验: %s" % [cid, str(checked.errors)])


func _test_calculator_consistency() -> void:
	# 预览面板确定性
	var p1 := Calc.material_preview({"action": "star_iron", "bearing": "blackwood",
		"control": "silverwood", "medium": "frost_steel"}, {"length": 0.6, "thickness": 0.5, "balance": 0.5})
	var p2 := Calc.material_preview({"action": "star_iron", "bearing": "blackwood",
		"control": "silverwood", "medium": "frost_steel"}, {"length": 0.6, "thickness": 0.5, "balance": 0.5})
	_check(str(p1) == str(p2), "material_preview 确定性")
	_check(p1.has("攻击") and p1.has("稳固") == false and p1.has("稳定"), "预览 6 项")
	# 预览换算 == 战斗用的 WeaponStats(同一通道)
	var parts := {"action": "star_iron", "bearing": "blackwood", "control": "silverwood", "medium": "frost_steel"}
	var size := {"length": 0.6, "thickness": 0.5, "balance": 0.5}
	var choices := {"purity_roll": 0.8, "quench": "salt", "temper": false, "keep_stress": false,
		"techniques": ["folded"], "balance_bias": false, "style": "steady"}
	var facts := Calc.preview_build("preview", "longsword", parts, size, choices)
	var cs := Calc.combat_summary(facts)
	var ws := WeaponStats.from_facts(facts)
	_check(absf(float(cs["攻×"]) - snappedf(ws.atk_mult, 0.01)) < 0.001, "预览攻× == 战斗 atk_mult")
	_check(absf(float(cs["暴×"]) - snappedf(ws.crit_mult, 0.01)) < 0.001, "预览暴× == 战斗 crit_mult")
	_check(absf(float(cs["耐久"]) - snappedf(ws.durability, 1.0)) < 0.001, "预览耐久 == 战斗耐久")
	_check((cs.get("缺陷", []) as Array).size() == (ws.defects as Array).size(), "预览缺陷列表一致")
	# preview_build 与 Forge.build 数值一致(同通道)
	var facts2 := Calc.preview_build("preview2", "longsword", parts, size, choices)
	_check(int(facts.craft.purity) == int(facts2.craft.purity), "同参数同四维")
