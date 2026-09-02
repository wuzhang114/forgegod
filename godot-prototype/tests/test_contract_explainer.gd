## ContractExplainer(契约本地说明)+ GodConfig 测试。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const Explainer := preload("res://domain/weapon/contract_explainer.gd")
const Registry := preload("res://domain/content/content_registry.gd")
const GodConfig := preload("res://adapters/negotiation/god_config.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_explain_templates()
	_test_explain_specific_sentences()
	_test_explain_bad_src()
	_test_god_config()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("EXPLAIN FAIL: " + label)


func _test_explain_templates() -> void:
	for cid in ["bulwark", "quake", "scorch", "lifesteal"]:
		var src := str(Registry.contract_template(cid).src)
		var lines: Array = Explainer.explain(src)
		_check(not lines.is_empty(), "%s 有说明" % cid)
		var joined := "\n".join(lines)
		_check(not joined.contains("device") and not joined.contains("{")
			and not joined.contains("}"), "%s 说明不展示源码" % cid)
		_check(joined.contains("【") and joined.contains("】"), "%s 含触发事件标题" % cid)


func _test_explain_specific_sentences() -> void:
	var q := "\n".join(Explainer.explain(str(Registry.contract_template("quake").src)))
	_check(q.contains("眩晕 3 秒") and q.contains("半径 2"), "震地说明: 眩晕3秒/半径2")
	var s := "\n".join(Explainer.explain(str(Registry.contract_template("scorch").src)))
	_check(s.contains("灼烧") and s.contains("6 秒") and s.contains("火焰伤害"),
		"灼烧说明: 灼烧6秒/火焰伤害")
	var l := "\n".join(Explainer.explain(str(Registry.contract_template("lifesteal").src)))
	_check(l.contains("3 次攻击") and l.contains("回复自身") and l.contains("最近的队友"),
		"嗜血说明: 3次攻击/回复")
	var b := "\n".join(Explainer.explain(str(Registry.contract_template("bulwark").src)))
	_check(b.contains("格挡") and b.contains("冲击"), "蓄能说明: 格挡触发")


func _test_explain_bad_src() -> void:
	var lines: Array = Explainer.explain("device 坏 { on block { explode_world() } }")
	_check(lines.size() >= 1 and (str(lines[0]).contains("无法解析") or str(lines[0]).contains("格式不妥")),
		"非法契约给出错误说明")
	var lines2: Array = Explainer.explain("")
	_check(lines2.is_empty() == false and str(lines2[0]).contains("无法解析"), "空源码安全")


func _test_god_config() -> void:
	GodConfig.override_path = "user://test_god_config.json"
	DirAccess.remove_absolute(GodConfig.override_path)
	var d := GodConfig.load_config()
	_check(str(d.god_mode) == "scripted", "默认脚本神")
	_check(GodConfig.effective_mode(d) == "scripted", "未配置无密钥回落脚本神")
	var cfg := {"god_mode": "local", "local_endpoint": "http://127.0.0.1:8000/v1",
		"local_key": "sk-localtest", "remote_endpoint": "", "remote_key": ""}
	var res := GodConfig.save_config(cfg)
	_check(res.get("ok", false), "保存成功")
	var loaded := GodConfig.load_config()
	_check(str(loaded.local_key) == "sk-localtest" and str(loaded.god_mode) == "local", "roundtrip")
	_check(GodConfig.effective_mode(loaded) == "local", "密钥就位后模式生效")
	var bad := {"god_mode": "local", "local_key": "", "local_endpoint": "", "remote_endpoint": "", "remote_key": ""}
	_check(GodConfig.effective_mode(bad) == "scripted", "选本地但没密钥 -> 回落")
	GodConfig.override_path = ""
	DirAccess.remove_absolute("user://test_god_config.json")
