## HttpProbe: OpenAI 兼容端点连接探针(同步;Windows curl)。无 Node 依赖,可单测。
## 用于"输入 API 确定时立即检测连接",失败即时反馈,避免战斗/交涉时才卡顿。
## key 可空(本地服务如 LM Studio/Ollama 无鉴权);endpoint 需完整 /v1/chat/completions。

extends RefCounted


## 探测 {endpoint, key, model};返回 {ok, latency_ms, error}
## key 可空(本地服务无鉴权);endpoint 允许只填 base,自动补全 /chat/completions
static func probe(endpoint: String, key: String, model: String, timeout_s: int = 5) -> Dictionary:
	if endpoint.strip_edges() == "" or model.strip_edges() == "":
		return {"ok": false, "error": "端点/模型未填写完整(密钥可留空:本地服务通常无鉴权)"}
	if key.strip_edges() != "" and str(key).contains("://"):
		return {"ok": false, "error": "密钥框里似乎填了网址 —— 请把 API 密钥(如 sk- 开头)填入密钥框,网址应填在端点框"}
	var full := normalize_endpoint(endpoint)
	if full == "":
		return {"ok": false, "error": "端点需为 http(s) 地址(可只填 base,如 https://api.deepseek.com)"}
	var body := JSON.stringify({"model": model,
		"messages": [{"role": "user", "content": "ping"}], "max_tokens": 8})
	# 响应体收到临时文件: 失败时读取服务端错误原文(OpenAI 兼容错误带 message)
	var tmp := "user://_probe_body.tmp"
	var args := PackedStringArray([
		"-s", "-o", ProjectSettings.globalize_path(tmp), "-w", "%{http_code} %{time_total}",
		"--max-time", str(timeout_s),
		"-H", "Content-Type: application/json",
	])
	if key.strip_edges() != "":
		args.append("-H")
		args.append("Authorization: Bearer %s" % key)
	args.append_array(["-d", body, "-X", "POST", full])
	var out: Array = []
	var exec_code := OS.execute("curl", args, out, false)
	if exec_code != 0:
		return {"ok": false, "error": "curl 不可用或执行失败"}
	var resp := str(out[0] if out.size() > 0 else "").strip_edges()
	var parts := resp.split(" ")
	var http_code := int(parts[0]) if parts.size() > 0 and parts[0].is_valid_int() else 0
	var ms := float(parts[1] if parts.size() > 1 and parts[1].is_valid_float() else "0") * 1000.0
	var detail := _read_body_detail(tmp)
	if http_code == 200:
		return {"ok": true, "latency_ms": ms, "endpoint": full}
	var why := _explain_code(http_code, str(key).strip_edges() == "")
	if detail != "":
		why += " — 服务端: " + detail
	return {"ok": false, "error": "HTTP %d(%s)" % [http_code, why],
		"latency_ms": ms, "endpoint": full, "server_detail": detail}


## 读取服务端响应体(前 220 字符,提取 OpenAI 兼容错误 message)
static func _read_body_detail(tmp: String) -> String:
	if not FileAccess.file_exists(tmp):
		return ""
	var f := FileAccess.open(tmp, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	DirAccess.remove_absolute(tmp)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		var err: Variant = parsed.error
		if typeof(err) == TYPE_DICTIONARY and err.has("message"):
			return str(err.message).left(200)
		return str(err).left(200)
	return txt.left(200).replace("\n", " ")


## base 地址 -> 完整 chat 端点(url 尾部去斜杠;已含 /chat/completions 则原样)
static func normalize_endpoint(endpoint: String) -> String:
	var e := str(endpoint).strip_edges()
	if not (e.begins_with("http://") or e.begins_with("https://")):
		return ""
	if e.to_lower().contains("/chat/completions"):
		return e
	while e.ends_with("/"):
		e = e.left(e.length() - 1)
	return e + "/chat/completions"


## 常见错误码解读(面向用户;排查引导)
static func _explain_code(code: int, key_empty: bool) -> String:
	match code:
		401:
			return "认证失败: 密钥无效或错误(检查是否把网址误填进密钥框;需以 sk- 开头的令牌)" \
				if not key_empty else "认证失败: 该服务需要密钥但未填写"
		403:
			return "被拒绝: 密钥无权限或频控"
		404:
			return "路径不存在: 服务不在此地址,检查端点域名/路径"
		400, 422:
			return "请求格式/模型名不被接受: 检查模型名"
		408:
			return "请求超时: 服务较慢,可加大超时"
		_:
			return "服务器返回异常状态码"
