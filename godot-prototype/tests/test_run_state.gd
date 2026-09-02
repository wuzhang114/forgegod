## RunState / SaveRepository / AppRouter 测试(架构第 1 步)。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const RunState := preload("res://app/run_state.gd")
const SaveRepository := preload("res://app/save_repository.gd")
const AppRouter := preload("res://app/app_router.gd")

var _passes := 0
var _fails := 0
var _tmp_dir := "user://test_saves"


func run() -> Dictionary:
	_test_new_run()
	_test_roundtrip()
	_test_from_dict_tolerant()
	_test_save_load()
	_test_router()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("RUN FAIL: " + label)


func _test_new_run() -> void:
	var r := RunState.new()
	r.new_run(42)
	_check(r.run_seed == 42, "种子记录")
	_check(r.run_id.begins_with("run_42_"), "run_id 生成")
	_check(r.current_day == 1 and r.money == 100.0, "默认日/金钱")
	_check(r.inventory.has("iron_ore") and r.weapons.is_empty() and r.roster.is_empty(),
		"初始库存/空武器库/空队伍")
	_check(r.contract_src == "", "契约为空")


func _test_roundtrip() -> void:
	var r := RunState.new()
	r.new_run(7)
	r.money = 320.5
	r.current_day = 3
	r.weapons = [{"instance_id": "w_1", "facts": {"name": "试剑"},
		"durability": 80.0, "contract_src": "device 测试"}]
	r.roster = [{"id": "hero_1", "role": "guard", "hp_ratio": 0.7}]
	r.negotiation_history = [{"who": "神", "text": "此约可行", "stance": "PROPOSE"}]
	r.contract_src = "device 最终契约"
	var d := r.to_dict()
	var r2 := RunState.new()
	r2.load_dict(d)
	_check(r2.money == 320.5 and r2.current_day == 3, "数字字段 roundtrip")
	_check(r2.weapons.size() == 1 and str(r2.weapons[0].facts.get("name", "")) == "试剑",
		"武器库 roundtrip")
	_check(r2.negotiation_history.size() == 1 and r2.contract_src == "device 最终契约",
		"交涉历史/契约 roundtrip")
	_check(r2.run_seed == 7 and r2.run_id == r.run_id, "run_id/种子 roundtrip")


func _test_from_dict_tolerant() -> void:
	# 空字典/半旧档 -> 默认值兜底(版本迁移友好)
	var r := RunState.new()
	r.load_dict({})
	_check(r.current_day == 1 and r.money == 100.0 and r.weapons.is_empty(), "空档容错")
	var old := RunState.new()
	old.load_dict({"money": 55.0, "schema_version": 1})
	_check(old.money == 55.0 and old.current_day == 1, "半旧档容错")


func _test_save_load() -> void:
	var saves := SaveRepository.new(_tmp_dir)
	saves.delete_save(0)
	_check(saves.has_save(0) == false, "初始无档")
	var r := RunState.new()
	r.new_run(99)
	r.money = 777.0
	r.current_day = 5
	r.weapons = [{"instance_id": "w_2", "facts": {"name": "寒铁弓"}, "durability": 100.0}]
	var res := saves.save(r, 0)
	_check(res.get("ok", false), "存档成功")
	_check(saves.has_save(0), "档存在")
	var loaded := saves.load(0)
	_check(loaded.get("ok", false), "读档成功")
	var r2: RunState = loaded.run
	_check(r2.money == 777.0 and r2.current_day == 5, "读档数值一致")
	_check(r2.weapons.size() == 1 and str(r2.weapons[0].facts.get("name", "")) == "寒铁弓",
		"读档武器一致")
	_check(saves.load(9).get("ok", false) == false, "空槽读取失败")
	saves.delete_save(0)
	DirAccess.remove_absolute(_tmp_dir)


func _test_router() -> void:
	var router := AppRouter.new()
	_check(router.resolve("forge") == "res://scenes/forge/forge_scene.tscn", "forge 路径")
	_check(router.resolve("altar") == "res://scenes/altar/altar_scene.tscn", "altar 路径")
	_check(router.resolve("battle") == "res://scenes/battle/battle_demo.tscn", "battle 路径")
	_check(router.resolve("unknown") == "", "未知节点返回空")
	_check(router.has("forge") and not router.has("nope"), "has() 断言")
