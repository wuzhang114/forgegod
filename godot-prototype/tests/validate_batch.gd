## M0.5-AI 生成验证: 批量校验 MechanLang 样本(parse + checker)。
## 输入: tests/ai_generated/applications.json(申请清单) 与 ai_generated/samples.json(模型生成的源码)
## 输出: 统计与逐条错误(解析/校验通过率)
## 运行: godot --headless --path godot-prototype -s res://tests/validate_batch.gd

extends SceneTree

const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")


func _initialize() -> void:
	var samples_path := "res://tests/ai_generated/samples.json"
	if not FileAccess.file_exists(samples_path):
		print("RESULT: FAIL samples.json 不存在(%s)" % samples_path)
		quit(2)
		return
	var f := FileAccess.open(samples_path, FileAccess.READ)
	var text := f.get_as_text()
	var samples: Array = []
	var json_ok := true
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		samples = parsed
	elif parsed is Dictionary:
		samples = [parsed]
	else:
		json_ok = false
	if not json_ok:
		print("RESULT: FAIL samples.json 不是合法 JSON")
		quit(2)
		return
	var pass_count := 0
	var fail_list: Array = []
	for item in samples:
		var sid: String = str(item.get("id", "?"))
		var src: String = str(item.get("source", ""))
		var p := Parser.new()
		var parsed_prog := p.parse(src)
		if not parsed_prog.ok:
			fail_list.append({"id": sid, "stage": "parse", "errors": parsed_prog.errors})
			continue
		var c := Checker.new()
		var checked := c.check(parsed_prog.ast)
		if not checked.ok:
			fail_list.append({"id": sid, "stage": "check", "errors": checked.errors})
			continue
		pass_count += 1
	print("RESULT: PASS %d / %d (通过率 %.1f%%)" % [pass_count, samples.size(), 100.0 * pass_count / samples.size()])
	for fl in fail_list:
		var errs := ""
		for e in fl.errors:
			errs += "[%s:%s] %s; " % [e.get("code", "?"), e.get("line", 0), e.get("detail", "")]
		print("FAIL %s (%s): %s" % [fl.id, fl.stage, errs])
	quit(0 if pass_count == samples.size() else 1)
