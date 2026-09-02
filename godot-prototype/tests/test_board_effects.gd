## 棋格效果层 + 几何助手测试(建议 4)。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")
const Grid := preload("res://core/runtime/hex_grid.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_cell_effects_crud()
	_test_cell_events_on_move()
	_test_cells_in_line()
	_test_cells_in_front()
	_test_find_knockback()
	_test_closest_enemy()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("BOARD FAIL: " + label)


func _mk(id: String, grid: Vector2i, role: String, kind: String, faction: String) -> Dictionary:
	return DefEntity.make(id, kind, faction, id, role,
		{"hp": 100.0, "atk": 10.0, "armor": 5.0, "hit": 0.9, "evade": 0.05, "grid": grid})


func _test_cell_effects_crud() -> void:
	var sim := BattleSim.new(1)
	var eid := sim.add_cell_effect(Vector2i(2, 2), "w_1", "fire", 5)
	_check(eid == "ce_1", "效果 id 生成")
	_check(sim.has_cell_effect(Vector2i(2, 2), "fire"), "has_cell_effect 命中")
	_check(not sim.has_cell_effect(Vector2i(2, 2), "water"), "不同 kind 不命中")
	_check(not sim.has_cell_effect(Vector2i(3, 2), "fire"), "不同格不命中")
	var fx := sim.cell_effects_of(Vector2i(2, 2))
	_check(fx.size() == 1 and fx[0].kind == "fire" and fx[0].owner == "w_1", "cell_effects_of 列表")
	# 到期移除
	for i in 5:
		sim.tick_once()
	sim.tick_once()
	_check(not sim.has_cell_effect(Vector2i(2, 2), "fire"), "lifetime 到期自动移除")
	# 永续效果
	var ep := sim.add_cell_effect(Vector2i(0, 0), "w_1", "altar", -1)
	for i in 30:
		sim.tick_once()
	_check(sim.has_cell_effect(Vector2i(0, 0), "altar"), "lifetime<0 永续")
	# 手动移除
	sim.remove_cell_effect(ep)
	_check(not sim.has_cell_effect(Vector2i(0, 0), "altar"), "remove_cell_effect")


func _test_cell_events_on_move() -> void:
	var sim := BattleSim.new(1)
	var hero := _mk("hero_1", Vector2i(0, 0), "brute", "hero", "player")
	var mob := _mk("mob_1", Vector2i(3, 0), "brute", "enemy", "enemy")
	DefEntity.apply_status(mob, "rooted", 99999, "test")  # 定身,避免相向移动干扰路径
	sim.add_entity(hero)
	sim.add_entity(mob)
	sim.add_cell_effect(Vector2i(1, 0), "w_1", "fire_pit", -1)
	sim.add_cell_effect(Vector2i(2, 0), "w_1", "frost", -1)
	var entered_fire := false
	var exited_fire := false
	var entered_frost := false
	for i in 80:
		sim.tick_once()
		for ev in sim.events:
			if ev.get("kind") == "cell_enter" and ev.get("cell") == Vector2i(1, 0):
				entered_fire = true
			if ev.get("kind") == "cell_exit" and ev.get("cell") == Vector2i(1, 0):
				exited_fire = true
			if ev.get("kind") == "cell_enter" and ev.get("cell") == Vector2i(2, 0):
				entered_frost = true
		if entered_fire and exited_fire and entered_frost:
			break
	_check(entered_fire, "踩入火坑格触发 cell_enter")
	_check(exited_fire, "离开火坑格触发 cell_exit")
	_check(entered_frost, "踩入霜冻格触发 cell_enter")


func _test_cells_in_line() -> void:
	var line := Grid.cells_in_line(Vector2i(0, 0), Vector2i(3, 0))
	_check(line.size() == 4, "直线 4 格 (实际 %d)" % line.size())
	_check(line[1] == Vector2i(1, 0) and line[3] == Vector2i(3, 0), "直线逐格顺序")
	var diag := Grid.cells_in_line(Vector2i(0, 0), Vector2i(2, 1))
	_check(diag.size() == 4, "斜线 4 格 (实际 %d)" % diag.size())
	var self_line := Grid.cells_in_line(Vector2i(1, 1), Vector2i(1, 1))
	_check(self_line.size() == 1 and self_line[0] == Vector2i(1, 1), "自连线单格")


func _test_cells_in_front() -> void:
	var fan := Grid.cells_in_front(Vector2i(0, 0), 0, 2)  # +q 方向锥
	_check(fan.has(Vector2i(1, 0)), "锥形含正前格")
	_check(fan.has(Vector2i(2, 0)), "锥形含两格外")
	_check(fan.has(Vector2i(1, 1)), "锥形含斜前格(60°内)")
	_check(not fan.has(Vector2i(-1, 0)), "锥形不含反向格")
	_check(not fan.has(Vector2i(0, 0)), "锥形不含自身")
	var back := Grid.cells_in_front(Vector2i(0, 0), 3, 1)  # 反向锥
	_check(back.has(Vector2i(-1, 0)), "反向锥成立")
	_check(Grid.cells_in_front(Vector2i(0, 0), 0, 0).is_empty(), "半径 0 空")


func _test_find_knockback() -> void:
	var sim := BattleSim.new(1)
	# 默认边界 q 0..7
	_check(sim.find_knockback_cell(Vector2i(2, 2), 0, 3) == Vector2i(5, 2), "无障碍最远 3 格")
	sim.blocked_cells[Vector2i(4, 2)] = true
	_check(sim.find_knockback_cell(Vector2i(2, 2), 0, 3) == Vector2i(3, 2), "被墙截断")
	_check(sim.find_knockback_cell(Vector2i(6, 2), 0, 5) == Vector2i(7, 2), "越界截断")
	_check(sim.find_knockback_cell(Vector2i(0, 0), 2, 2) == Vector2i(0, 0), "反向一步即越界,原地截断")


func _test_closest_enemy() -> void:
	var sim := BattleSim.new(1)
	var hero := _mk("hero_1", Vector2i(0, 0), "brute", "hero", "player")
	var m1 := _mk("mob_1", Vector2i(2, 0), "brute", "enemy", "enemy")
	var m2 := _mk("mob_2", Vector2i(1, 3), "brute", "enemy", "enemy")
	sim.add_entity(hero)
	sim.add_entity(m1)
	sim.add_entity(m2)
	var t := sim.closest_enemy_in_radius(hero, 3)
	_check(t.get("id", "") == "mob_1", "半径 3 内最近敌为 mob_1 (实际 " + str(t.get("id", "")) + ")")
	var tf := sim.closest_enemy_in_radius(hero, 1)
	_check(tf.is_empty(), "半径 1 内无敌")
