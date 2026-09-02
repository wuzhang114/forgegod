## NegotiationProvider: 谈判适配器工厂(按 GameApp.run.world_flags.god_mode 选择)。
## modes: scripted(默认) | local | remote;未知回落 scripted。

extends RefCounted

const Scripted := preload("res://adapters/negotiation/scripted_god_adapter.gd")
const LocalAI := preload("res://adapters/negotiation/local_ai_adapter.gd")
const RemoteAI := preload("res://adapters/negotiation/remote_ai_adapter.gd")

const MODES := ["scripted", "local", "remote"]


static func create(mode: String = "") -> Object:
	match mode:
		"local":
			return LocalAI.new()
		"remote":
			return RemoteAI.new()
		_:
			return Scripted.new()


## 读取当前模式(RunState 世界标记;未声明默认 scripted)
static func mode_of(run) -> String:
	var m := str(run.world_flags.get("god_mode", "scripted"))
	return m if m in MODES else "scripted"


static func cycle_mode(run) -> String:
	var m := mode_of(run)
	var idx := (MODES.find(m) + 1) % MODES.size()
	run.world_flags["god_mode"] = MODES[idx]
	return MODES[idx]
