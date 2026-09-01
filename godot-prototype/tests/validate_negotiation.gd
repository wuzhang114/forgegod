## 神前交涉验证器: 事实引用真实性 / draft 可编译 / 裁决合理性。
## 输入: tests/negotiation/{weapons.json, cases.json, results.json}
## 运行: godot --headless --path godot-prototype -s res://tests/validate_negotiation.gd

extends SceneTree

const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")


func _initialize() -> void:
	var weapons := _read_json_object("res://tests/negotiation/weapons.json")
	var cases := _read_json_object("res://tests/negotiation/cases.json")
	var results := _read_json_array("res://tests/negotiation/results.json")
	if weapons.is_empty() or cases.is_empty() or results.is_empty():
		print("RESULT: FAIL 输入文件缺失或非法 JSON")
		quit(2)
		return
	var weapon_map := {}
	for w in weapons.get("weapons", []):
		weapon_map[w.id] = w
	var expected: Dictionary = cases.get("expected", {})
	var must_accept: Array = expected.get("must_accept_or_leveling", [])
	var must_bargain: Array = expected.get("must_bargain", [])
	var must_refuse: Array = expected.get("must_refuse_or_super_weaken", [])
	var pass_count := 0
	var issues: Array = []
	for rec in results:
		var rid: String = str(rec.get("id", "?"))
		var weapon_info: Dictionary = weapon_map.get(str(case_of(cases, rid, "weapon")), {})
		var facts := {}
		for f in weapon_info.get("facts", []):
			facts[f.id] = true
		var stance: String = str(rec.get("stance", ""))
		var cited: Array = rec.get("cited_fact_ids", [])
		var draft: String = str(rec.get("draft", ""))
		var ok := true
		var msgs: Array = []
		# 1) 事实引用真实性
		for cid in cited:
			if not facts.has(str(cid)):
				ok = false
				msgs.append("引用了不存在的事实 %s" % str(cid))
		# 2) stance 与 draft/理由一致性
		if stance in ["PROPOSE", "COUNTEROFFER"]:
			if draft.strip_edges().is_empty():
				ok = false
				msgs.append("%s 但缺少 draft" % stance)
			else:
				var p := Parser.new()
				var parsed_prog := p.parse(draft)
				if not parsed_prog.ok:
					ok = false
					msgs.append("draft 解析失败: " + str(parsed_prog.errors))
				else:
					var c := Checker.new()
					var checked := c.check(parsed_prog.ast)
					if not checked.ok:
						ok = false
						msgs.append("draft 校验失败: " + str(checked.errors))
		elif stance == "REFUSE":
			if str(rec.get("refuse_reason", "")).strip_edges().is_empty():
				ok = false
				msgs.append("REFUSE 缺少驳回理由")
		elif stance == "QUESTION":
			if str(rec.get("missing", "")).strip_edges().is_empty():
				ok = false
				msgs.append("QUESTION 缺少缺口说明")
		# 3) 裁决合理性
		if rid in must_accept:
			if stance == "REFUSE":
				ok = false
				msgs.append("合理申请被驳回")
		if rid in must_bargain:
			if stance == "REFUSE":
				ok = false
				msgs.append("半依据申请被直接驳回(应讨价)")
		if rid in must_refuse:
			if stance == "PROPOSE":
				ok = false
				msgs.append("越界申请被原样批准")
			elif stance == "QUESTION":
				ok = false
				msgs.append("越界申请只提问未给定立场")
		# 4) 引用必须有意义: 非 REFUSE 至少引用 1 条真实事实?宽松:只要求"存在事实引用时"真实
		if ok:
			pass_count += 1
		else:
			issues.append({"id": rid, "msgs": msgs, "stance": stance})
	print("===== 交涉验证 ===== 通过 %d / %d =====" % [pass_count, results.size()])
	for it in issues:
		print("FAIL %s (%s): %s" % [it.id, it.stance, "; ".join(it.msgs)])
	quit(0 if pass_count == results.size() else 1)


func case_of(cases: Dictionary, rid: String, key: String) -> String:
	for c in cases.get("cases", []):
		if c.id == rid:
			return str(c.get(key, ""))
	return ""


func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return data
	return {}


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		return data
	return []
