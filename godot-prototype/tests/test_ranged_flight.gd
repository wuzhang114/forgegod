## 远程弹道(command 化延迟命中)测试 —— 建议 2。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_ranged_flight()
	_test_melee_unchanged()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("RANGED FAIL: " + label)


func _mk(id: String, role: String, kind: String, faction: String, grid: Vector2i, range_hex: int = 1) -> Dictionary:
	return DefEntity.make(id, kind, faction, id, role,
		{"hp": 100.0, "atk": 10.0, "armor": 5.0, "hit": 0.9, "evade": 0.05,
			"grid": grid, "range_hex": range_hex})


func _test_ranged_flight() -> void:
	var sim := BattleSim.new(7)
	var ranger := _mk("hero_r", "ranger", "hero", "player", Vector2i(0, 1), 4)
	var mob := _mk("mob_1", "brute", "enemy", "enemy", Vector2i(3, 1))
	DefEntity.apply_status(mob, "rooted", 99999, "t")     # 定身: 不移动
	DefEntity.apply_status(mob, "stunned", 99999, "t")    # 眩晕: 不还手(避免转火干扰)
	sim.add_entity(ranger)
	sim.add_entity(mob)

	var launch_tick := -1
	var launch_flight := 0
	var attack: Dictionary = {}
	var guard := 0
	while sim.tick <= 300 and attack.is_empty():
		sim.tick_once()
		for ev in sim.events:
			if ev.get("kind") == "projectile_launch" and launch_tick < 0:
				launch_tick = int(ev.tick)
				launch_flight = int(ev.flight)
			if ev.get("kind") == "attack" and ev.get("hit_landed", -1) >= 0:
				attack = ev
		guard += 1
		if guard > 500:
			break

	_check(launch_tick >= 0, "远程射击产生 projectile_launch(弹道发射)")
	if launch_tick >= 0:
		_check(not attack.is_empty(), "弹道到达后有 attack 结算事件")
		if not attack.is_empty():
			_check(int(attack.get("hit_landed", 0)) == 1, "弹道命中")
			_check(float(attack.get("final_damage", 0.0)) > 0.0, "弹道伤害>0")
			var d := 3 - 1  # 距离 3 格 -> 飞行 (3-1)*4 = 8 tick
			_check(launch_flight == d * BattleSim.RANGED_FLIGHT_TICKS,
				"飞行 tick == (距离-1)*每格tick (实际 %d)" % launch_flight)
			_check(int(attack.get("tick", -1)) == launch_tick + launch_flight,
				"attack 事件发生在命中 tick (出手 %d + 飞行 %d)" % [launch_tick, launch_flight])


func _test_melee_unchanged() -> void:
	var sim := BattleSim.new(7)
	var guard := _mk("hero_g", "guard", "hero", "player", Vector2i(0, 2), 1)
	var mob := _mk("mob_2", "brute", "enemy", "enemy", Vector2i(1, 2))
	DefEntity.apply_status(mob, "rooted", 99999, "t")
	DefEntity.apply_status(mob, "stunned", 99999, "t")
	sim.add_entity(guard)
	sim.add_entity(mob)

	var launch_count := 0
	var attack: Dictionary = {}
	var guard2 := 0
	while sim.tick <= 300 and attack.is_empty():
		sim.tick_once()
		for ev in sim.events:
			if ev.get("kind") == "projectile_launch":
				launch_count += 1
			if ev.get("kind") == "attack" and ev.get("hit_landed", -1) >= 0:
				attack = ev
		guard2 += 1
		if guard2 > 500:
			break

	_check(launch_count == 0, "近战攻击不发射弹道")
	_check(not attack.is_empty() and int(attack.get("hit_landed", 0)) == 1, "近战立即命中")
	_check(float(attack.get("final_damage", 0.0)) > 0.0, "近战伤害>0")
