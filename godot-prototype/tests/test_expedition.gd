## 出征地图/规则测试(StS 式分支结构 + 逐层敌人变强)。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const ExpeditionMap := preload("res://domain/expedition/expedition_map.gd")
const ExpeditionRules := preload("res://domain/expedition/expedition_rules.gd")
const EnemyPacks := preload("res://domain/battle/enemy_packs.gd")
const RunState := preload("res://app/run_state.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_generate_structure()
	_test_determinism()
	_test_scaling()
	_test_pack_for()
	_test_effects()
	_test_node_apply()
	_test_enemy_packs_new()
	_test_resolve_battle()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("RUN FAIL: " + label)


func _test_generate_structure() -> void:
	var m: Dictionary = ExpeditionMap.generate(20260902)
	# 层数与行数
	_check(int(m.floors) == 6 and m.rows.size() == 6, "6 层结构")
	# 首层 3 个全战斗
	var row1: Dictionary = m.rows[0]
	_check(row1.nodes.size() == 3, "首层 3 节点 (实际 %d)" % row1.nodes.size())
	var all_combat := true
	for n in row1.nodes:
		if str(n.type) != "combat":
			all_combat = false
	_check(all_combat, "首层全部战斗")
	# 末层单 Boss
	var last_row: Dictionary = m.rows[5]
	_check(last_row.nodes.size() == 1 and str(last_row.nodes[0].type) == "boss", "末层单 Boss")
	# 中间层节点数 3~5 且每层有战斗
	for i in range(1, 5):
		var row: Dictionary = m.rows[i]
		var n: int = row.nodes.size()
		_check(n >= 3 and n <= 5, "层 %d 节点数 %d 在 3~5" % [i + 1, n])
		var has_combat := false
		for node in row.nodes:
			if str(node.type) == "combat" or str(node.type) == "elite":
				has_combat = true
		_check(has_combat, "层 %d 至少一场战斗/精英" % (i + 1))
	# 边: 相邻层之间,且连通兜底生效(每个非末层节点有出边、每个非首层节点有入边)
	var edges: Array = m.edges
	_check(edges.size() > 0, "存在边 (实际 %d)" % edges.size())
	for i in range(5):
		for n in m.rows[i].nodes:
			var has_out := false
			for e in edges:
				if str(e.from) == str(n.id):
					has_out = true
			_check(has_out, "层 %d 节点 %s 有出边" % [i + 1, str(n.id)])
	for i in range(1, 6):
		for n in m.rows[i].nodes:
			var has_in := false
			for e in edges:
				if str(e.to) == str(n.id):
					has_in = true
			_check(has_in, "层 %d 节点 %s 有入边" % [i + 1, str(n.id)])


func _test_determinism() -> void:
	var a: Dictionary = ExpeditionMap.generate(42)
	var b: Dictionary = ExpeditionMap.generate(42)
	var c: Dictionary = ExpeditionMap.generate(7)
	_check(str(a.rows) == str(b.rows) and str(a.edges) == str(b.edges), "同种子地图一致")
	_check(str(a.rows) != str(c.rows), "不同种子地图不同")


func _test_scaling() -> void:
	var s1: Dictionary = ExpeditionRules.scale_for_floor(1)
	var s2: Dictionary = ExpeditionRules.scale_for_floor(2)
	var s6: Dictionary = ExpeditionRules.scale_for_floor(6)
	_check(float(s1.hp) == 1.0 and float(s1.atk) == 1.0, "第 1 层基准")
	_check(float(s2.hp) > float(s1.hp), "第 2 层 HP 更高")
	_check(float(s6.hp) > float(s2.hp), "第 6 层 HP 更高")
	_check(abs(float(s6.hp) - 1.6) < 0.001, "第 6 层 HP ×1.6 (实际 %s)" % str(s6.hp))
	_check(abs(float(s6.atk) - 1.5) < 0.001, "第 6 层攻击 ×1.5 (实际 %s)" % str(s6.atk))


func _test_pack_for() -> void:
	_check(str(ExpeditionRules.pack_for(1, "combat")) == "golems", "第 1 层石甲傀儡")
	_check(str(ExpeditionRules.pack_for(3, "combat")) == "mixed", "第 3 层混编")
	_check(str(ExpeditionRules.pack_for(3, "elite")) == "elite_golem", "精英包")
	_check(str(ExpeditionRules.pack_for(6, "boss")) == "boss_golem", "首领包")


func _test_effects() -> void:
	var run = RunState.new()
	run.new_run(5)
	var money0: float = run.money
	var out: Dictionary = ExpeditionRules.apply_effect(run, {"money": 20.0, "reputation": 3.0})
	_check(run.money == money0 + 20.0 and float(run.world_flags.get("reputation", 0.0)) == 3.0,
		"金钱/声望效果")
	var out2: Dictionary = ExpeditionRules.apply_effect(run, {"grant": {"iron_ore": 2}})
	_check(int(run.inventory.get("iron_ore", 0)) == 5, "材料入账 (3+2=5, 实际 %d)" % int(run.inventory.get("iron_ore", 0)))
	var out3: Dictionary = ExpeditionRules.apply_effect(run, {"consume": {"iron_ore": 1}})
	_check(int(run.inventory.get("iron_ore", 0)) == 4, "材料扣除 (实际 %d)" % int(run.inventory.get("iron_ore", 0)))
	var out4: Dictionary = ExpeditionRules.apply_effect(run, {"money": -999.0})
	_check(run.money >= 0.0, "金钱不低于 0")
	var amb: Dictionary = ExpeditionRules.apply_effect(run, {"ambush": true})
	_check(bool(amb.ambush), "伏击标记")


func _test_node_apply() -> void:
	var run = RunState.new()
	run.new_run(5)
	for w in run.weapons:
		w["durability"] = 30.0
	var r: Dictionary = ExpeditionRules.apply_node(run, {"type": "treasure", "floor": 2})
	_check(run.money > 100.0, "宝箱加钱")
	_check(int(run.inventory.get("charm_crystal", 0)) == 2, "偶数层宝箱给水晶(默认 1+1=2)")
	var r2: Dictionary = ExpeditionRules.apply_node(run, {"type": "rest", "floor": 2})
	var all_ok := true
	for w in run.weapons:
		if float(w.get("durability", 0.0)) != 55.0:
			all_ok = false
	_check(all_ok, "篝火修复全部武器 耐久 30→55")


func _test_enemy_packs_new() -> void:
	var elite: Dictionary = EnemyPacks.get_pack("elite_golem")
	var boss: Dictionary = EnemyPacks.get_pack("boss_golem")
	_check(elite.get("slots", []).size() == 4, "精英包 4 单位")
	_check(boss.get("slots", []).size() == 4, "首领包 4 单位")
	# 构建部署不越界: 使用默认地图
	var deploy: Array = EnemyPacks.build_deploy("boss_golem", "forge_courtyard", "enemy")
	_check(deploy.size() == 4, "Boss 队伍可部署 (实际 %d)" % deploy.size())


func _test_resolve_battle() -> void:
	var run = RunState.new()
	run.new_run(9)
	var map_data: Dictionary = ExpeditionMap.generate(9)
	run.expedition = {"active": true, "map": map_data, "floor": 1, "done": {},
		"awaiting_battle": "f1_n1", "battle_result": "", "battle_floor": 1,
		"battle_type": "combat", "last_report": {}, "outcome": ""}
	var money0: float = run.money
	var out: Dictionary = ExpeditionRules.resolve_battle(run, "player_win", "f1_n1", map_data)
	_check(str(out.type) == "won", "胜利类型")
	_check(int(run.expedition.get("floor", 1)) == 2, "胜利推进到第 2 层")
	_check(run.money > money0, "胜利获得金币")
	_check((run.expedition.get("done", {}) as Dictionary).has("f1_n1"), "节点标记完成")
	# 失败: 停在节点所在层(可再战),无奖励
	var out2: Dictionary = ExpeditionRules.resolve_battle(run, "enemy_win", "f1_n2", map_data)
	_check(str(out2.type) == "lost" and int(run.expedition.get("floor", 1)) == 1, "失败留在节点层")
	# Boss 通关: 远征关闭
	var boss_row: Dictionary = map_data.rows[5]
	var boss_id := str(boss_row.nodes[0].id)
	run.expedition["floor"] = 6
	var out3: Dictionary = ExpeditionRules.resolve_battle(run, "player_win", boss_id, map_data)
	_check(str(out3.type) == "victory", "Boss 胜利 = 凯旋")
	_check(not bool(run.expedition.get("active", true)), "远征关闭")
	_check(str(run.expedition.get("outcome", "")) == "victory", "结果记录 victory")
