## RemoteAIAdapter: 云端 AI 神(桩;协议就位后接远端服务)。

extends RefCounted

const Base := preload("res://domain/negotiation/divine_adjudicator.gd")
const Local := preload("res://adapters/negotiation/local_ai_adapter.gd")


func adjudicate(facts: Dictionary, app: String) -> Dictionary:
	return Base.normalize({
		"stance": "REFUSE",
		"speech": "云端神座未达成联系(远程 AI 接入待定;通用协议见 PROMPT_god.md)。",
		"cited_fact_ids": [], "missing": [], "refuse_reason": "remote_ai_not_configured", "draft": ""})


func display_name() -> String:
	return "云端 AI(桩)"
