## BattleScenario / BattleEventLog / BattleReport 测试(架构第 2 步)。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const MapTemplates := preload("res://domain/battle/map_templates.gd")
const EnemyPacks := preload("res://domain/battle/enemy_packs.gd")
const BattleScenario := preload("res://domain/battle/battle_scenario.gd")
const BattleEventLog := preload("res://domain/battle/battle_event_log.gd")
const BattleReport := preload("res://domain/battle/battle_report.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")
const DefEntity := preload("res://core/runtime/sim_entity.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_map_templates()
	_test_enemy_packs()
	_test_scenario_build_roundtrip()
	_test_seed_derive()
	_test_event_log()
	_test_report_and_timeout()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("SCN FAIL: " + label)


func _test_map_templates() -> void:
	_check(MapTemplates.all_ids().size() == 4, "4 张地图模板")
	var m := MapTemplates.get_map("ruined_road")
	_check(str(m.id) == "ruined_road" and int(m.q_max) == 7, "读已知地图")
	var b := MapTemplates.bounds_of("crystal_mine")
	_check(int(b.q_max) == 6 and int(b.r_max) == 3, "bounds 提取")
	_check(str(MapTemplates.get_map("nope").id) == "forge_courtyard", "未知地图回落默认")


func _test_enemy_packs() -> void:
	var dep := EnemyPacks.build_deploy("golems", "forge_courtyard")
	_check(dep.size() == 5, "石甲 5 只")
	var ok_in := true
	for e in dep:
		var g: Vector2i = e.grid
		if g.x < 6 or g.x > 8 or g.y < 0 or g.y > 4:
			ok_in = false
	_check(ok_in, "全部部署在敌方区(forge_courtyard)")
	var mix := EnemyPacks.build_deploy("mixed", "autumn_shrine")
	var roles := {}
	for e in mix:
		roles[str(e.role)] = true
	_check(mix.size() == 5 and roles.has("shooter") and roles.has("purger"), "混编含 射手/净化者")
	var m := EnemyPacks.get_pack("nope")
	_check(str(m.label) == "石甲傀儡群", "未知包回落")


func _test_scenario_build_roundtrip() -> void:
	var s := BattleScenario.new()
	s.init_build("forge_courtyard", "golems", 12345, [],
		[{"cid": "c_qu", "src": "device 测试", "holder_id": "hero_1"}])
	_check(s.scenario_id == "sc_forge_courtyard_12345", "scenario_id")
	_check(s.player_deploy.size() == 3 and s.enemy_deploy.size() == 5, "双方部署数量")
	_check(s.contracts.size() == 1 and s.contracts[0].holder_id == "hero_1", "契约登记")
	_check(int(s.bounds.get("q_min", -1)) == 0 and int(s.bounds.get("r_max", -1)) == 4, "bounds")
	var inside := true
	for e in s.player_deploy + s.enemy_deploy:
		if not s.is_inside(e.grid):
			inside = false
	_check(inside, "全部部署格在界内")
	# roundtrip
	var d := s.to_dict()
	var s2 := BattleScenario.new()
	s2.load_dict(d)
	_check(s2.seed == 12345 and s2.map_id == "forge_courtyard" and s2.enemy_deploy.size() == 5,
		"scenario roundtrip")


func _test_seed_derive() -> void:
	var a := BattleScenario.derive_battle_seed(20260902, "forge_courtyard", 1)
	var b := BattleScenario.derive_battle_seed(20260902, "forge_courtyard", 1)
	var c := BattleScenario.derive_battle_seed(20260902, "forge_courtyard", 2)
	var d := BattleScenario.derive_battle_seed(20260902, "crystal_mine", 1)
	_check(a == b, "同参同种子(确定性)")
	_check(a != c and a != d, "异参(day/map)异种子")


func _test_event_log() -> void:
	var wrapped := BattleEventLog.sanitize({"kind": "kill", "tick": 5, "source_id": "a"})
	_check(int(wrapped.get("v", 0)) == BattleEventLog.EVENT_VERSION, "事件带版本")
	var all := BattleEventLog.sanitize_all([{"kind": "attack", "tick": 1}, {"kind": "kill", "tick": 9}])
	_check(all.size() == 2, "批量包装")
	var q := BattleEventLog.query(all, "attack", 0, 5)
	_check(q.size() == 1 and int(q[0].tick) == 1, "按 kind/tick 查询")
	var sum := BattleEventLog.summarize(all)
	_check(int(sum.get("attack", 0)) == 1 and int(sum.get("kill", 0)) == 1, "摘要计数")


func _test_report_and_timeout() -> void:
	var s := BattleScenario.new()
	s.init_build("forge_courtyard", "golems", 7, [],
		[{"cid": "c_qu", "src": "device 测试", "holder_id": "hero_1"}])
	var sim := BattleSim.new(s.seed)
	sim.configure_board(s.bounds)
	for e in s.player_deploy:
		sim.add_entity(DefEntity.make(e.id, "hero", "player", e.name, e.role, {"grid": e.grid}))
	for e in s.enemy_deploy:
		sim.add_entity(DefEntity.make(e.id, "enemy", "enemy", e.name, e.role, {"grid": e.grid}))
	sim.run(4800)
	var rep := BattleReport.new().build(sim, s)
	_check(rep.get("result", "") in ["player_win", "enemy_win", "draw", "timeout"], "结果类型合法: " + str(rep.get("result", "")))
	_check(int(rep.get("ticks", 0)) == sim.tick, "tick 记录")
	_check(float(rep.get("duration_s", 0.0)) > 0.0, "时长秒")
	_check(rep.get("scenario_id", "") == s.scenario_id, "scenario 关联")
	# 超时模拟: 无攻击的傻瓜战斗(双方打不动) -> 跑满上限判 timeout
	var sim2 := BattleSim.new(3)
	sim2.configure_board(s.bounds)
	var h := DefEntity.make("hero_1", "hero", "player", "h", "brute",
		{"hp": 1000.0, "atk": 0.0, "armor": 50.0, "hit": 0.0, "evade": 0.0, "grid": Vector2i(0, 2), "range_hex": 1})
	var m := DefEntity.make("enemy_1", "enemy", "enemy", "m", "brute",
		{"hp": 1000.0, "atk": 0.0, "armor": 50.0, "hit": 0.0, "evade": 0.0, "grid": Vector2i(1, 2), "range_hex": 1})
	sim2.add_entity(h)
	sim2.add_entity(m)
	sim2.run(2400)
	_check(sim2.battle_result == "timeout", "打满上限 -> timeout")
	var rep2 := BattleReport.new().build(sim2, s)
	_check(rep2.get("result", "") == "timeout", "报告 timeout")
	# 奖励
	_check(float(BattleReport.rewards("player_win").get("money", 0.0)) == 60.0, "胜场奖励 60")
	_check(float(BattleReport.rewards("enemy_win").get("money", 0.0)) == 10.0, "败场奖励 10")
