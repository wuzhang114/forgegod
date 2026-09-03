## 远征 UI 接缝回归验证(场景模式运行; -s 模式无 GameApp autoload)。
## 运行: godot --headless --path godot-prototype --quit-after 120 res://tests/fixtures/expedition_flow_test.tscn
extends Control

const ExpeditionMap := preload("res://domain/expedition/expedition_map.gd")


func _ready() -> void:
	var run = GameApp.run
	run.new_run(99)
	var map_data: Dictionary = ExpeditionMap.generate(99)
	run.expedition = {"active": true, "map": map_data, "floor": 1, "done": {},
		"awaiting_battle": "f1_n1", "battle_result": "player_win", "battle_floor": 1,
		"battle_type": "combat", "last_report": {"result": "victory", "scenario_id": "sc_test_99"},
		"outcome": ""}
	var money0: float = run.money
	var scene = preload("res://scenes/expedition/expedition_scene.gd").new()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := scene.modal_panel != null
	ok = ok and int(run.expedition.get("floor", 1)) == 2
	ok = ok and run.money > money0
	ok = ok and (run.expedition.get("done", {}) as Dictionary).has("f1_n1")
	print("FLOW_OK=" + str(ok) + " modal=" + str(scene.modal_panel != null) +
		" floor=" + str(run.expedition.get("floor", 1)) +
		" money_delta=%.0f" % (run.money - money0))
	get_tree().quit(0 if ok else 1)
