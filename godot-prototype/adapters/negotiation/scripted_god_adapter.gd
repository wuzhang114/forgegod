## ScriptedGodAdapter: 脚本神适配器(首个 Adapter;协议稳定后可替换为本地/云端 AI)。

extends RefCounted

const Base := preload("res://domain/negotiation/divine_adjudicator.gd")
const ScriptedGod := preload("res://core/negotiation/scripted_god.gd")


func adjudicate(facts: Dictionary, app: String) -> Dictionary:
	return Base.normalize(ScriptedGod.adjudicate(facts, app))


## 显示名(UI 选择)
func display_name() -> String:
	return "脚本神(内置)"
