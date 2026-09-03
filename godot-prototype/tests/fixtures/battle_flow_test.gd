## 战斗远征接缝验证: 从地图进入战斗,敌人按层缩放生效,返回按钮切远征返回。
## 运行: godot --headless --path godot-prototype --quit-after 120 res://tests/fixtures/battle_flow_test.tscn
extends Control

const ExpeditionMap := preload("res://domain/expedition/expedition_map.gd")


func _ready() -> void:
	var run = GameApp.run
	run.new_run(99)
	var map_data: Dictionary = ExpeditionMap.generate(99)
	run.expedition = {"active": true, "map": map_data, "floor": 5, "done": {},
		"awaiting_battle": "", "battle_result": "", "battle_floor": 5,
		"battle_type": "elite", "last_report": {}, "outcome": ""}
	var row: Dictionary = map_data.rows[4]
	var elite_id := ""
	for n in row.nodes:
		if str(n.type) == "elite":
			elite_id = str(n.id)
	if elite_id == "":
		print("FLOW_OK=false (no elite node)")
		get_tree().quit(1)
		return
	run.expedition["awaiting_battle"] = elite_id
	run.expedition["battle_type"] = "elite"
	run.expedition["battle_floor"] = 5
	# 实例化战斗场景(不切换 current_scene,避免 fixture 被释放)
	var battle = load("res://scenes/battle/battle_demo.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := bool(battle.expedition_mode)
	ok = ok and str(battle.current_pack_id) == "elite_golem"
	ok = ok and str(battle.return_button.text).contains("返回地图")
	# 敌人实际面板: 第 5 层 HP ×1.48(brute 120 / shooter 102 / purger 150 基准之一)
	var first_enemy: Dictionary = {}
	for e in battle.deploy_entities:
		if not str(e.id).begins_with("hero_"):
			first_enemy = battle._make_entity(e)
			break
	ok = ok and not first_enemy.is_empty()
	var expected_hp := 0.0
	for base in [120.0, 102.0, 150.0]:
		if absf(float(first_enemy.get("hp", 0.0)) - base * 1.48) < 1.0:
			expected_hp = base * 1.48
	ok = ok and expected_hp > 0.0
	print("FLOW_OK=" + str(ok) + " mode=" + str(battle.expedition_mode) +
		" pack=" + str(battle.current_pack_id) +
		" enemy_hp=%.1f" % float(first_enemy.get("hp", 0.0)) +
		" ret=" + str(battle.return_button.text))
	get_tree().quit(0 if ok else 1)
