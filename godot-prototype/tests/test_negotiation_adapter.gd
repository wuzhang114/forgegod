## 谈判适配器测试(架构第 5 步): DivineTurn 协议 / 脚本神适配器 / AI 桩 / Provider 工厂。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const Base := preload("res://domain/negotiation/divine_adjudicator.gd")
const ScriptedAdapter := preload("res://adapters/negotiation/scripted_god_adapter.gd")
const LocalAI := preload("res://adapters/negotiation/local_ai_adapter.gd")
const RemoteAI := preload("res://adapters/negotiation/remote_ai_adapter.gd")
const Provider := preload("res://application/negotiation_provider.gd")
const RunState := preload("res://app/run_state.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_turn_protocol()
	_test_scripted_adapter()
	_test_ai_stubs()
	_test_provider_factory()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("GOD FAIL: " + label)


func _mk_facts() -> Dictionary:
	var Forge := preload("res://core/forge/forge_core.gd")
	return Forge.build("test", "longsword", "试剑",
		{"action": "star_iron", "bearing": "blackwood", "control": "silverwood", "medium": "frost_steel"},
		{"length": 0.6, "thickness": 0.5, "balance": 0.5},
		{"purity_roll": 0.8, "quench": "salt", "temper": false, "keep_stress": false,
			"techniques": ["folded"], "balance_bias": false, "style": "steady"})


func _test_turn_protocol() -> void:
	var good := Base.normalize({"stance": "PROPOSE", "speech": "应允", "draft": "device 契约"})
	_check(Base.validate(good), "合法 DivineTurn 通过校验")
	var bad := Base.normalize({"stance": "WISH", "speech": ""})
	_check(not Base.validate(bad), "非法 stance/空 speech 被拒")
	var partial := Base.normalize({"stance": "QUESTION", "speech": "质询"})
	_check(partial.has("cited_fact_ids") and partial.has("draft"), "缺字段补齐")


func _test_scripted_adapter() -> void:
	var adapter := ScriptedAdapter.new()
	var turn := adapter.adjudicate(_mk_facts(), "召唤一道雷霆")
	_check(Base.validate(turn), "脚本神输出通过协议校验")
	_check(str(turn.stance) in Base.STANCES, "stance 合法")


func _test_ai_stubs() -> void:
	# 注入纯净配置路径(避免本机真实配置污染断言)
	const GodConfig := preload("res://adapters/negotiation/god_config.gd")
	GodConfig.override_path = "user://test_god_cfg.json"
	DirAccess.remove_absolute(GodConfig.override_path)
	var local := LocalAI.new()
	_check(local.probe() == false, "无密钥时本地 AI 未探活")
	var turn := local.adjudicate(_mk_facts(), "任意申请")
	_check(Base.validate(turn), "本地桩输出合法")
	_check(str(turn.get("refuse_reason", "")) == "local_ai_not_ready", "本地桩回退理由")
	var remote := RemoteAI.new()
	var rturn := remote.adjudicate(_mk_facts(), "任意申请")
	_check(Base.validate(rturn) and str(rturn.get("refuse_reason", "")) == "remote_ai_not_configured",
		"云端桩输出合法")
	GodConfig.override_path = ""
	DirAccess.remove_absolute("user://test_god_cfg.json")


func _test_provider_factory() -> void:
	var s := Provider.create("scripted")
	_check(s.has_method("adjudicate") and s.has_method("display_name"), "scripted 适配器可调用")
	var l := Provider.create("local")
	_check(l.has_method("adjudicate"), "local 适配器可调用")
	var r := RunState.new()
	r.new_run(1)
	_check(Provider.mode_of(r) == "scripted", "默认脚本神模式")
	_check(Provider.cycle_mode(r) == "local", "切换 -> local")
	_check(Provider.cycle_mode(r) == "remote", "切换 -> remote")
	_check(Provider.cycle_mode(r) == "scripted", "循环回 scripted")
	r.world_flags["god_mode"] = "nope"
	_check(Provider.mode_of(r) == "scripted", "未知模式回落")
