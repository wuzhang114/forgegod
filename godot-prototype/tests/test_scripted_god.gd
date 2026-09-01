## 假神核心测试: 意图识别/依据判定/草案可编译/驳回与讨价。
## 由 run_headless.gd 调用。

extends RefCounted

const Forge := preload("res://core/forge/forge_core.gd")
const God := preload("res://core/negotiation/scripted_god.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_intent_mapping()
	_test_summon_propose()
	_test_store_propose()
	_test_lightning_counteroffer()
	_test_refuse_no_support()
	_test_drafts_compile()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("GOD FAIL: " + label)


## 星火猎弓(银木弓臂) 与 陨铁重锤
func _w_bow() -> Dictionary:
	return Forge.build("test_bow", "bow", "测试弓",
		{"action": "silverwood", "bearing": "blackwood", "control": "beast_bone", "medium": "silverwood"},
		{"length": 0.8, "thickness": 0.3, "balance": 0.5},
		{"purity_roll": 0.7, "quench": "water", "temper": false, "keep_stress": false,
			"techniques": [], "balance_bias": false, "style": "steady"})


func _w_hammer() -> Dictionary:
	return Forge.build("test_hammer", "warhammer", "测试锤",
		{"action": "star_iron", "bearing": "blackwood", "control": "grey_iron", "medium": "red_copper"},
		{"length": 0.7, "thickness": 0.6, "balance": 0.5},
		{"purity_roll": 0.6, "quench": "water", "temper": false, "keep_stress": false,
			"techniques": [], "balance_bias": false, "style": "steady"})


func _w_dagger() -> Dictionary:
	return Forge.build("test_dagger", "longsword", "测试铁器",
		{"action": "grey_iron", "bearing": "grey_iron", "control": "grey_iron", "medium": ""},
		{"length": 0.5, "thickness": 0.4, "balance": 0.5},
		{"purity_roll": 0.3, "quench": "water", "temper": false, "keep_stress": false,
			"techniques": [], "balance_bias": false, "style": "steady"})


func _test_intent_mapping() -> void:
	var r := God.adjudicate(_w_bow(), "连续命中三次召唤火花小精灵")
	_check(r.stance == "PROPOSE", "弓+召唤 -> PROPOSE (实际 %s)" % r.stance)
	var r2 := God.adjudicate(_w_hammer(), "重击时电弧传导")
	_check(r2.stance == "COUNTEROFFER", "锤+雷 -> COUNTEROFFER(缺雷源)")


func _test_summon_propose() -> void:
	var r := God.adjudicate(_w_bow(), "连续命中三次召唤火花小精灵")
	_check(r.cited_fact_ids.size() > 0, "引用事实非空")
	_check(r.draft.contains("spawn_sprite"), "草案含召唤")
	_check(r.draft.contains("200") == false, "草案占位已替换")


func _test_store_propose() -> void:
	var r := God.adjudicate(_w_hammer(), "格挡时把伤害存起来,下一次重击释放")
	_check(r.stance == "PROPOSE", "锤+储能 -> PROPOSE")
	_check(r.draft.contains("blocked_damage") and r.draft.contains("charge"), "储能草案")


func _test_lightning_counteroffer() -> void:
	var r := God.adjudicate(_w_hammer(), "召唤一道雷霆劈向敌人")
	_check(r.stance == "COUNTEROFFER", "雷无源 -> 讨价(供物)")
	_check(r.draft.contains("consume_offering"), "讨价包含供物代价")
	_check(r.missing.contains("雷源"), "说明缺口")


func _test_refuse_no_support() -> void:
	var r := God.adjudicate(_w_dagger(), "我想把这把剑变成巨龙")
	# 龙 -> 无意图关键词匹配(仅"变成"?意图无匹配) -> QUESTION(未识别)或 REFUSE
	_check(r.stance in ["REFUSE", "QUESTION"], "铁器+离奇申请 -> 拒绝或质询 (实际 %s)" % r.stance)
	var r2 := God.adjudicate(_w_dagger(), "召唤一片火海")
	_check(r2.stance == "REFUSE", "无火材料 -> 驳回")


func _test_drafts_compile() -> void:
	for wep in [_w_bow(), _w_hammer()]:
		for app in ["连续命中三次召唤火花小精灵", "格挡时把伤害存起来再释放",
				"击退敌人并破甲", "杀死敌人恢复耐久", "打中敌人让他减速"]:
			var r := God.adjudicate(wep, app)
			var draft: String = str(r.get("draft", ""))
			if draft.strip_edges().is_empty():
				continue
			var p := Parser.new()
			var parsed_prog := p.parse(draft)
			if not parsed_prog.ok:
				_check(false, "草案解析失败: %s (%s)" % [app, str(parsed_prog.errors)])
				continue
			var c := Checker.new()
			var checked := c.check(parsed_prog.ast)
			_check(checked.ok, "假神草案可编译: %s (%s)" % [app, str(checked.errors)])
			return
