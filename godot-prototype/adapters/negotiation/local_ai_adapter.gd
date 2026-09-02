## LocalAIAdapter: 本地 AI 神(桩;按 PROMPT_god.md 协议就位)。
## 检测: user://god/local_god_key.txt 存在即视为可用;未接入时礼貌驳回(可回退)。

extends RefCounted

const Base := preload("res://domain/negotiation/divine_adjudicator.gd")

const KEY_PATH := "user://god/local_god_key.txt"


## 探活: 本地模型端点/密钥可用性(桩: 检查密钥文件)
func probe() -> bool:
	return FileAccess.file_exists(KEY_PATH)


func adjudicate(facts: Dictionary, app: String) -> Dictionary:
	if not probe():
		return Base.normalize({
			"stance": "REFUSE",
			"speech": "本地神祇尚未被唤醒(缺少 user://god/local_god_key.txt)。此间的裁决暂由脚本神代理。",
			"cited_fact_ids": [], "missing": [], "refuse_reason": "local_ai_not_ready", "draft": ""})
	# TODO(协议就位): 调用本地端点(参见 PROMPT_god.md),校验返回后 normalize/validate
	return Base.normalize({
		"stance": "REFUSE",
		"speech": "(本地 AI 接入点已检测到密钥;实现见 PROMPT_god.md 协议)",
		"cited_fact_ids": [], "missing": [], "refuse_reason": "local_ai_stub", "draft": ""})


func display_name() -> String:
	return "本地 AI(桩)"
