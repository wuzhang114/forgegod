## LocalAIAdapter: 本地 AI 神(桩;按 PROMPT_god.md 协议就位)。
## 探活: GodConfig.local_key 非空即视为已配置;未配置时礼貌回退(由 Provider 生效)。

extends RefCounted

const Base := preload("res://domain/negotiation/divine_adjudicator.gd")
const GodConfig := preload("res://adapters/negotiation/god_config.gd")
const ContextBuilder := preload("res://adapters/negotiation/context_builder.gd")

## 预加载的上下文缓存(保存 API 时构建;adjudicate 直接复用)
var cached_context: Array = []


## 探活: 已填写本地密钥即视为可用
func probe() -> bool:
	var cfg := GodConfig.load_config()
	return str(cfg.get("local_key", "")).strip_edges() != ""


## 保存/连接确认时调用: 构建并缓存神裁上下文(避免首轮包组装延迟)
func prepare_context(facts: Dictionary) -> Array:
	cached_context = ContextBuilder.build_messages(facts)
	return cached_context


func adjudicate(facts: Dictionary, app: String) -> Dictionary:
	if not probe():
		return Base.normalize({
			"stance": "REFUSE",
			"speech": "本地神祇尚未被唤醒(开始界面未填写本地 AI 密钥/端点)。此间的裁决暂由脚本神代理。",
			"cited_fact_ids": [], "missing": [], "refuse_reason": "local_ai_not_ready", "draft": ""})
	if cached_context.is_empty():
		prepare_context(facts)
	# TODO(协议就位): 用 cached_context + app 调用本地端点(参见 PROMPT_god.md),校验返回后 normalize/validate
	return Base.normalize({
		"stance": "REFUSE",
		"speech": "(本地 AI 已配置且上下文已就绪;接入协议见 PROMPT_god.md,当前为桩)",
		"cited_fact_ids": [], "missing": [], "refuse_reason": "local_ai_stub", "draft": ""})


func display_name() -> String:
	return "本地 AI" + ("" if probe() else "(未配置)")
