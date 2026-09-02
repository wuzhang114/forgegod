## 目标粘性(FSM 索敌细化)测试 —— 建议 3。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_pick_sticky()
	_test_pick_expire_and_dead()
	_test_move_sticky()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("STICKY FAIL: " + label)


func _mk(id: String, grid: Vector2i, kind: String, faction: String) -> Dictionary:
	return DefEntity.make(id, kind, faction, id, "brute",
		{"hp": 100.0, "atk": 10.0, "armor": 5.0, "hit": 0.9, "evade": 0.05, "grid": grid})


func _make_sim() -> Dictionary:
	var sim := BattleSim.new(7)
	var a := _mk("hero_1", Vector2i(0, 0), "hero", "player")
	var na := _mk("mob_a", Vector2i(1, 0), "enemy", "enemy")   # 近
	var nb := _mk("mob_b", Vector2i(5, 0), "enemy", "enemy")   # 远
	sim.add_entity(a)
	sim.add_entity(na)
	sim.add_entity(nb)
	return {"sim": sim, "a": a, "na": na, "nb": nb}


func _test_pick_sticky() -> void:
	var w := _make_sim()
	var sim = w.sim
	var a = w.a
	# 粘住"远"目标(窗口未过期时即使有更近敌也不换)
	a.cur_target = "mob_b"
	a.sticky_ticks = 50
	_check(sim._pick_target(a) == "mob_b", "粘性窗口内锁定原目标")
	# 窗口过期 -> 换最近
	a.sticky_ticks = 0
	_check(sim._pick_target(a) == "mob_a", "窗口过期换最近敌")
	_check(a.cur_target == "mob_a", "换目标后重新锁定 cur_target")
	_check(int(a.sticky_ticks) == BattleSim.TARGET_STICKY_TICKS, "重锁刷新粘性窗口")
	# 手动集火优先于粘性
	a.cur_target = "mob_a"
	a.sticky_ticks = 50
	a.focus_target = "mob_b"
	_check(sim._pick_target(a) == "mob_b", "手动集火覆盖粘性")


func _test_pick_expire_and_dead() -> void:
	var w := _make_sim()
	var sim = w.sim
	var a = w.a
	var nb = w.nb
	a.cur_target = "mob_b"
	a.sticky_ticks = 50
	nb.alive = false
	_check(sim._pick_target(a) == "mob_a", "粘性目标死亡立即换最近")
	a.cur_target = ""
	nb.alive = true
	a.sticky_ticks = 50
	a.cur_target = "ghost"
	_check(sim._pick_target(a) == "mob_a", "悬垂 cur_target 兜底换最近")


func _test_move_sticky() -> void:
	var w := _make_sim()
	var sim = w.sim
	var a = w.a
	var nb = w.nb
	# 敌人施加长眩晕: 不主动攻击(避免受击转火接管粘性目标),但保持可被攻击
	DefEntity.apply_status(w.na, "stunned", 99999, "t")
	DefEntity.apply_status(nb, "stunned", 99999, "t")
	# 手动把粘性目标锁定为"远"目标: 移动应朝 mob_b(+q 方向),而非近敌 mob_a
	a.cur_target = "mob_b"
	a.sticky_ticks = 50
	var x0: int = a.grid.x
	for i in 40:
		sim.tick_once()
	_check(a.grid.x > x0, "朝粘性目标移动(实际 x %d -> %d)" % [x0, a.grid.x])
	_check(a.cur_target == "mob_b", "移动过程中粘性目标不变")
	# 窗口过期: tick_once 递减 sticky_ticks;续跑至窗口结束应转向最近敌 mob_a
	for i in 80:
		sim.tick_once()
	_check(a.cur_target == "mob_a", "窗口过期后转向最近敌")
	_check(int(a.sticky_ticks) == BattleSim.TARGET_STICKY_TICKS or int(a.sticky_ticks) >= 0,
		"粘性字段维持合法区间")
	# mob_b 仍存活(未被击杀)
	_check(nb.alive, "远目标未被击杀")
