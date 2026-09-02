## LocalAIAdapter: 本地 AI 神(桩;按 PROMPT_god.md 协议就位)。
## 探活: GodConfig.local_key 非空即视为已配置;未配置时礼貌回退(由 Provider 生效)。

extends RefCounted

const Base := preload("res://domain/negotiation/divine_adjudicator.gd")
const GodConfig := preload("res://adapters/negotiation/god_config.gd")


## 探活: 已填写本地密钥即视为可用
func probe() -> bool:
	var cfg := GodConfig.load_config()
	return str(cfg.get("local_key", "")).strip_edges() != ""


func adjudicate(facts: Dictionary, app: String) -> Dictionary:
	if not probe():
		return Base.normalize({
			"stance": "REFUSE",
			"speech": "本地神祇尚未被唤醒(开始界面未填写本地 AI 密钥/端点)。此间的裁决暂由脚本神代理。",
			"cited_fact_ids": [], "missing": [], "refuse_reason": "local_ai_not_ready", "draft": ""})
	# TODO(协议就位): 调用本地端点(参见 PROMPT_god.md),校验返回后 normalize/validate
	return Base.normalize({
		"stance": "REFUSE",
		"speech": "(本地 AI 已配置;接入协议见 PROMPT_god.md,当前为桩)",
		"cited_fact_ids": [], "missing": [], "refuse_reason": "local_ai_stub", "draft": ""})


func display_name() -> String:
	return "本地 AI" + ("" if probe() else "(未配置)")
