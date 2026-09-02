## HttpProbe: OpenAI 兼容端点连接探针(同步;Windows curl)。无 Node 依赖,可单测。
## 用于"输入 API 确定时立即检测连接",失败即时反馈,避免战斗/交涉时才卡顿。

extends RefCounted


## 探测 {endpoint, key, model};返回 {ok, latency_ms, error}
static func probe(endpoint: String, key: String, model: String, timeout_s: int = 5) -> Dictionary:
	if endpoint.strip_edges() == "" or key.strip_edges() == "" or model.strip_edges() == "":
		return {"ok": false, "error": "端点/密钥/模型未填写完整"}
	var body := JSON.stringify({"model": model,
		"messages": [{"role": "user", "content": "ping"}], "max_tokens": 8})
	var args := PackedStringArray([
		"-s", "-o", "NUL", "-w", "%{http_code} %{time_total}",
		"--max-time", str(timeout_s),
		"-H", "Content-Type: application/json",
		"-H", "Authorization: Bearer %s" % key,
		"-d", body, "-X", "POST", endpoint,
	])
	var out: Array = []
	var exec_code := OS.execute("curl", args, out, false)
	if exec_code != 0:
		return {"ok": false, "error": "curl 不可用或执行失败"}
	var resp := str(out[0] if out.size() > 0 else "").strip_edges()
	var parts := resp.split(" ")
	var http_code := int(parts[0]) if parts.size() > 0 and parts[0].is_valid_int() else 0
	var ms := float(parts[1] if parts.size() > 1 and parts[1].is_valid_float() else "0") * 1000.0
	if http_code == 200:
		return {"ok": true, "latency_ms": ms}
	return {"ok": false, "error": "HTTP %d" % http_code, "latency_ms": ms}
