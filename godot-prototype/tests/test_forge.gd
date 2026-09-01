## 锻造核心测试: 材料表/四维推导/缺陷/事实卡片/指纹确定性。
## 由 run_headless.gd 调用。

extends RefCounted

const Forge := preload("res://core/forge/forge_core.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_materials()
	_test_default_build()
	_test_keep_stress()
	_test_quench_moon()
	_test_style_fact()
	_test_fingerprint_determinism()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FORGE FAIL: " + label)


func _test_materials() -> void:
	_check(Forge.MATERIALS.size() == 8, "材料表 8 种")
	var m: Dictionary = Forge.MATERIALS["star_iron"]
	_check(m.hardness == 9 and m.craft == 9 and m.trait.label == "天外", "陨铁属性与特性")
	var q: Dictionary = Forge.QUENCH_MEDIA["moon"]
	_check(q.trait.text.contains("月光"), "月泉淬火标签")


func _default_parts() -> Dictionary:
	return {"action": "star_iron", "bearing": "blackwood", "control": "grey_iron", "medium": "red_copper"}


func _default_choices() -> Dictionary:
	return {"purity_roll": 0.6, "quench": "water", "temper": false, "keep_stress": false,
		"techniques": ["folded"], "balance_bias": false, "style": "steady"}


func _test_default_build() -> void:
	var w := Forge.build("w_forge_1", "warhammer", "试炼之锤", _default_parts(),
		{"length": 0.7, "thickness": 0.6, "balance": 0.5}, _default_choices())
	_check(w.kind_name == "战锤", "武器类型名称")
	_check(w.action_tags.has("heavy_blow"), "动作标签")
	_check(w.craft.has("purity") and w.craft.has("structure") and w.craft.has("temper") and w.craft.has("balance"),
		"四维完整")
	_check(int(w.craft.temper) >= 55 + 18, "清水淬火热处理加成")
	# 事实卡片: 包含各部件材料特性 + 淬火 + 尺寸 + 风格
	var texts := ""
	for f in w.facts:
		texts += str(f.text)
	_check(texts.contains("天外") and texts.contains("回振") and texts.contains("导流"), "材料特性事实")
	_check(texts.contains("清水淬火"), "淬火介质事实")
	_check(texts.contains("偏长"), "尺寸事实")
	_check(texts.contains("稳健风格"), "风格事实")
	_check(w.fingerprint.length() == 64, "fingerprint SHA256 长度")
	_check(w.defects.is_empty(), "默认无缺陷")


func _test_keep_stress() -> void:
	var c := _default_choices()
	c.keep_stress = true
	c.style = "cracksman"
	var w := Forge.build("w2", "warhammer", "裂锤", _default_parts(),
		{"length": 0.6, "thickness": 0.5, "balance": 0.5}, c)
	var has_crack := false
	for d in w.defects:
		if str(d.id) == "defect.stress_crack":
			has_crack = true
	_check(has_crack, "保留应力 -> 内应力裂纹缺陷")
	_check(int(w.craft.structure) < 76, "结构度下降")
	var has_style := false
	for f in w.facts:
		if str(f.text).contains("留痕风格"):
			has_style = true
	_check(has_style, "留痕风格事实")


func _test_quench_moon() -> void:
	var c := _default_choices()
	c.quench = "moon"
	var w := Forge.build("w3", "longsword", "月刃",
		{"action": "frost_steel", "bearing": "beast_bone", "control": "grey_iron", "medium": ""},
		{"length": 0.8, "thickness": 0.4, "balance": 0.5}, c)
	var has_moon := false
	var has_no_medium := false
	for f in w.facts:
		if str(f.text).contains("月光"):
			has_moon = true
		if str(f.id) == "lack.medium":
			has_no_medium = true
	_check(has_moon, "月泉淬火论据")
	_check(has_no_medium, "无媒介事实(论证缺口)")


func _test_style_fact() -> void:
	var c := _default_choices()
	c.style = "daring"
	c.quench = "beast_oil"
	var w := Forge.build("w4", "bow", "野兽之弓",
		{"action": "silverwood", "bearing": "blackwood", "control": "beast_bone", "medium": "silverwood"},
		{"length": 0.9, "thickness": 0.3, "balance": 0.6}, c)
	var has := false
	for f in w.facts:
		if str(f.text).contains("险峻风格"):
			has = true
	_check(has, "风格标签随选择变化")


func _test_fingerprint_determinism() -> void:
	var w1 := Forge.build("w5", "warhammer", "同一把", _default_parts(),
		{"length": 0.7, "thickness": 0.6, "balance": 0.5}, _default_choices())
	var w2 := Forge.build("w5", "warhammer", "同一把", _default_parts(),
		{"length": 0.7, "thickness": 0.6, "balance": 0.5}, _default_choices())
	_check(w1.fingerprint == w2.fingerprint, "同参数指纹一致(确定性)")
	# 尺寸不同 -> 指纹不同
	var w3 := Forge.build("w5", "warhammer", "同一把", _default_parts(),
		{"length": 0.9, "thickness": 0.6, "balance": 0.5}, _default_choices())
	_check(w1.fingerprint != w3.fingerprint, "参数变化 -> 指纹变化")
