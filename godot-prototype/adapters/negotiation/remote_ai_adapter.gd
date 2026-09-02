## RemoteAIAdapter: 云端 AI 神(真实调用)。
## 流程: 探针/预加载(开始界面) -> adjudicate(交涉时):
##   组装 messages(上下文缓存 + 本次申请) -> POST {endpoint}/chat/completions(文件传 body 防引号炸)
##   -> 解析 choices[0].message.content 中的 JSON 对抗 DivineTurn -> normalize/validate。
## 要求模型按 PROMPT_god.md 协议输出单条对象(非批量数组)。

extends RefCounted

const Base := preload("res://domain/negotiation/divine_adjudicator.gd")
const GodConfig := preload("res://adapters/negotiation/god_config.gd")
const ContextBuilder := preload("res://adapters/negotiation/context_builder.gd")
const HttpProbe := preload("res://adapters/negotiation/http_probe.gd")

## 预加载的上下文缓存(保存 API 时构建;adjudicate 直接复用)
var cached_context: Array = []


## 探活: 已填写云端密钥即视为可用(与 GodConfig.effective_mode 一致)
func probe() -> bool:
	var cfg := GodConfig.load_config()
	return str(cfg.get("remote_key", "")).strip_edges() != ""


## 保存/连接确认时调用: 构建并缓存神裁上下文(含 summary 输出要求)
func prepare_context(facts: Dictionary) -> Array:
	cached_context = ContextBuilder.build_messages(facts)
	cached_context[0]["content"] = str(cached_context[0].get("content", "")) + (
		"\n\n额外要求(必须遵守): 除了协议字段,请额外输出 \"summary\" 字段 —— 用中文完整描述该契约技的效果,"
		+ "面向玩家,不含代码;PROPOSE/COUNTEROFFER 时必填(1-3 句),其他姿态可为空字符串。")
	return cached_context


func adjudicate(facts: Dictionary, app: String) -> Dictionary:
	if not probe():
		return Base.normalize({
			"stance": "REFUSE",
			"speech": "云端神座未达成联系(开始界面未填写云端密钥/端点)。此间的裁决暂由脚本神代理。",
			"cited_fact_ids": [], "missing": [], "refuse_reason": "remote_ai_not_configured", "draft": ""})
	if cached_context.is_empty():
		prepare_context(facts)
	var cfg := GodConfig.load_config()
	var endpoint := str(cfg.get("remote_endpoint", ""))
	var key := str(cfg.get("remote_key", ""))
	var model := str(cfg.get("remote_model", ""))
	if endpoint.strip_edges() == "" or model.strip_edges() == "":
		return Base.normalize({
			"stance": "REFUSE",
			"speech": "云端神座信息不全(端点/模型缺失)。",
			"cited_fact_ids": [], "missing": [], "refuse_reason": "remote_ai_not_configured", "draft": ""})
	var msgs := cached_context.duplicate(true)
	msgs.append({"role": "user", "content": app})
	var turn := _ask_turn(endpoint, key, model, msgs)
	# 草案校验: PROPOSE/COUNTEROFFER 时若 MechLang 未过校验 -> 自纠错回环(把错误反馈给神)
	if str(turn.get("stance", "")) in ["PROPOSE", "COUNTEROFFER"] and str(turn.get("draft", "")).strip_edges() != "":
		var errs := draft_errors(str(turn.draft))
		if not errs.is_empty():
			var fix_msgs := msgs.duplicate(true)
			fix_msgs.append({"role": "assistant", "content": JSON.stringify(turn)})
			fix_msgs.append({"role": "user", "content":
				"你给出的契约草案未通过校验,错误: %s。"
				+ "请修正草案后重新输出完整 JSON(保持字段与姿势不变,只改 draft)。" % "；".join(errs)})
			var turn2 := _ask_turn(endpoint, key, model, fix_msgs)
			if str(turn2.get("refuse_reason", "")) != "remote_parse_failed":
				turn = turn2
				if draft_errors(str(turn.draft)).is_empty():
					turn["draft_valid"] = true
				else:
					turn["draft_valid"] = false
			else:
				turn["draft_valid"] = false
		else:
			turn["draft_valid"] = true
	var out := Base.normalize(turn)
	if turn.has("draft_valid"):
		out["draft_valid"] = turn.draft_valid
	return out


## 请求一次并解析(带推理引擎降级)
static func _ask_turn(endpoint: String, key: String, model: String, msgs: Array) -> Dictionary:
	var content := _chat_once(endpoint, key, model, msgs)
	var turn := parse_turn_from_llm(content)
	if str(turn.get("refuse_reason", "")) == "remote_parse_failed":
		var content2 := _chat_once(endpoint, key, "deepseek-chat", msgs)
		var turn2 := parse_turn_from_llm(content2)
		if str(turn2.get("refuse_reason", "")) != "remote_parse_failed":
			turn = turn2
	return turn


## MechLang 草案静态校验(错误列表;空 = 通过)
static func draft_errors(src: String) -> Array:
	var Parser := preload("res://core/mechlang/parser.gd")
	var Checker := preload("res://core/mechlang/checker.gd")
	var parsed := Parser.new().parse(src)
	if not parsed.ok:
		return parsed.errors
	var checked := Checker.new().check(parsed.ast)
	if not checked.ok:
		return checked.errors
	return []


## 单次对话请求(推理引擎 content 空时兜底 reasoning_content)
static func _chat_once(endpoint: String, key: String, model: String, msgs: Array) -> String:
	var body := JSON.stringify({"model": model, "messages": msgs, "max_tokens": 4096,
		"response_format": {"type": "json_object"}})
	var full_endpoint := HttpProbe.normalize_endpoint(endpoint)
	var resp := _http_post(full_endpoint, key, body)
	return str(resp.get("content", ""))


## LLM 输出 -> DivineTurn(提取 JSON 对象;失败则容错为 REFUSE 并附原文片段)
static func parse_turn_from_llm(text: String) -> Dictionary:
	var candidates: Array = []
	var t := text.strip_edges()
	var j := JSON.new()
	if j.parse(t) == OK and typeof(j.data) == TYPE_DICTIONARY:
		candidates.append(j.data)
	var start := t.find("{")
	if start >= 0:
		var end := t.rfind("}")
		if end > start:
			var sub := t.substr(start, end - start + 1)
			var j2 := JSON.new()
			if j2.parse(sub) == OK and typeof(j2.data) == TYPE_DICTIONARY:
				candidates.append(j2.data)
	for c in candidates:
		if Base.validate(Base.normalize(c)):
			return Base.normalize(c)
	return {
		"stance": "REFUSE",
		"speech": "云端神座所言晦涩难明(回应无法解析): %s" % text.left(120),
		"cited_fact_ids": [], "missing": [], "refuse_reason": "remote_parse_failed",
		"draft": "",
	}


## HTTP POST(文件传 body/响应,避开 Windows 命令行引号地狱;单次调用超时 60s)
static func _http_post(endpoint: String, key: String, body: String, timeout_s: int = 60) -> Dictionary:
	var body_file := "user://_god_req.tmp"
	var bf := FileAccess.open(body_file, FileAccess.WRITE)
	if bf == null:
		return {"ok": false, "error": "无法写入请求临时文件"}
	bf.store_string(body)
	bf.close()
	var resp_file := "user://_god_resp.tmp"
	var args := PackedStringArray([
		"-s", "-o", ProjectSettings.globalize_path(resp_file), "-w", "%{http_code}",
		"--max-time", str(timeout_s),
		"-H", "Content-Type: application/json",
	])
	if key.strip_edges() != "":
		args.append("-H")
		args.append("Authorization: Bearer %s" % key)
	args.append_array(["--data-binary", "@" + ProjectSettings.globalize_path(body_file),
		"-X", "POST", endpoint])
	var out: Array = []
	var exec_code := OS.execute("curl", args, out, false)
	DirAccess.remove_absolute(body_file)
	if exec_code != 0:
		return {"ok": false, "error": "curl 不可用或执行失败"}
	var code := int(out[0]) if out.size() > 0 else 0
	var txt := ""
	if FileAccess.file_exists(resp_file):
		var rf := FileAccess.open(resp_file, FileAccess.READ)
		if rf != null:
			txt = rf.get_as_text()
			rf.close()
		DirAccess.remove_absolute(resp_file)
	if code == 200:
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			var choices: Variant = parsed.get("choices", [])
			if typeof(choices) == TYPE_ARRAY and choices.size() > 0:
				var msg: Dictionary = choices[0].get("message", {})
				var content := str(msg.get("content", ""))
				# 推理模型(deepseek-v4-flash 等)常把回复放 reasoning_content:
				# content 为空时以 reasoning_content 兜底(JSON 可能就在其中)
				if content.strip_edges() == "":
					content = str(msg.get("reasoning_content", ""))
				return {"ok": true, "content": content}
		return {"ok": false, "error": "响应结构异常"}
	var detail := txt.left(200).replace("\n", " ")
	return {"ok": false, "error": "HTTP %d %s" % [code, detail]}
