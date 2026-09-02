## HttpProbe(连接检测)+ ContextBuilder(上下文预加载)测试。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const HttpProbe := preload("res://adapters/negotiation/http_probe.gd")
const ContextBuilder := preload("res://adapters/negotiation/context_builder.gd")
const LocalAI := preload("res://adapters/negotiation/local_ai_adapter.gd")
const RemoteAI := preload("res://adapters/negotiation/remote_ai_adapter.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_probe_fail_fast()
	_test_probe_incomplete()
	_test_normalize_endpoint()
	_test_context_builder()
	_test_prepare_cache()
	_test_parse_turn_from_llm()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("PROBE FAIL: " + label)


func _test_probe_fail_fast() -> void:
	# 拒绝连接的端点 -> 立即失败(不 5s 等待)
	var t0 := Time.get_ticks_msec()
	var r := HttpProbe.probe("http://127.0.0.1:9/v1/chat/completions", "sk-test", "m", 3)
	var ms := Time.get_ticks_msec() - t0
	_check(not r.get("ok", false), "无服务端点探测失败 (error=%s)" % str(r.get("error", "?")))
	_check(ms < 6000, "快速失败而非超时等待 (耗时 %dms)" % ms)


func _test_probe_incomplete() -> void:
	_check(not HttpProbe.probe("", "", "m").get("ok", false), "端点空 -> 直接失败")
	_check(not HttpProbe.probe("http://x", "", "").get("ok", false), "模型空 -> 失败")
	# 密钥框误填网址 -> 立即拦截(不发网络)
	var r := HttpProbe.probe("https://api.deepseek.com/chat/completions",
		"https://api.deepseek.com", "deepseek-chat")
	_check(not r.get("ok", false) and str(r.error).contains("密钥框"), "密钥误填网址被拦截")


func _test_normalize_endpoint() -> void:
	_check(HttpProbe.normalize_endpoint("https://api.deepseek.com") == "https://api.deepseek.com/chat/completions",
		"base 自动补全")
	_check(HttpProbe.normalize_endpoint("https://api.deepseek.com/") == "https://api.deepseek.com/chat/completions",
		"尾部斜杠容错")
	_check(HttpProbe.normalize_endpoint("https://api.deepseek.com/v1") == "https://api.deepseek.com/v1/chat/completions",
		"/v1 base 补全")
	_check(HttpProbe.normalize_endpoint("https://api.deepseek.com/v1/chat/completions") == "https://api.deepseek.com/v1/chat/completions",
		"完整端点原样")
	_check(HttpProbe.normalize_endpoint("api.deepseek.com") == "", "非 http 拒绝")


func _test_context_builder() -> void:
	var sys := ContextBuilder.system_prompt()
	_check(sys.length() > 20, "系统提示非空")
	var msgs := ContextBuilder.build_messages({"name": "试剑", "kind_name": "长剑",
		"craft": {"purity": 80, "structure": 70, "temper": 60, "balance": 65},
		"defects": [], "facts": [{"text": "★ 材料·陨铁: 锋利"}]})
	_check(msgs.size() >= 2 and str(msgs[0].role) == "system" and str(msgs[1].role) == "user",
		"上下文结构 system+user")
	var joined := str(msgs[1].content)
	_check(joined.contains("试剑") and joined.contains("纯净"), "武器事实进上下文")
	_check(joined.contains("判例"), "判例库进上下文")
	var facts_txt := ContextBuilder.facts_text({})
	_check(facts_txt.length() > 0, "空事实兜底文本")


func _test_prepare_cache() -> void:
	var adapter := LocalAI.new()
	var msgs := adapter.prepare_context({"name": "试剑", "craft": {}})
	_check(adapter.cached_context.size() >= 2, "适配器上下文缓存")
	_check(msgs.size() == adapter.cached_context.size(), "prepare 返回与缓存一致")


func _test_parse_turn_from_llm() -> void:
	# 纯 JSON
	var t1 := RemoteAI.parse_turn_from_llm('{"stance":"PROPOSE","speech":"应允","cited_fact_ids":[],"missing":"","refuse_reason":"","draft":"device 试 { on hit { damage_weapon(1) } }"}')
	_check(str(t1.get("stance", "")) == "PROPOSE" and str(t1.get("draft", "")).begins_with("device"),
		"纯 JSON 解析")
	# 代码块包裹
	var t2 := RemoteAI.parse_turn_from_llm('前言... ```json\n{"stance":"QUESTION","speech":"问什么","cited_fact_ids":["x"],"missing":"材料","refuse_reason":"","draft":""}\n``` 后记')
	_check(str(t2.get("stance", "")) == "QUESTION" and str(t2.get("missing", "")) == "材料",
		"```json 块提取")
	# 垃圾输出 -> 容错 REFUSE
	var t3 := RemoteAI.parse_turn_from_llm("这不是 JSON,只是一段神秘的低语")
	_check(str(t3.get("stance", "")) == "REFUSE" and str(t3.get("refuse_reason", "")) == "remote_parse_failed",
		"垃圾输出容错")
