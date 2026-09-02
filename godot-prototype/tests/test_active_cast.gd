## 主动技(手动释放)测试: units_in_range 查询 / 调度触发 / 冷却门控。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const DefEntity := preload("res://core/runtime/sim_entity.gd")
const BattleSim := preload("res://core/runtime/battle_sim.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")

const SRC_QUAKE := """
device 震地怒涛 {
  auth: item
  budget: { entities: 12, steps: 32, cooldown: 300 }
  on right_click {
    for e in units_in_range(2) {
      apply_status(e, "stunned", 60)
    }
    damage_weapon(3)
  }
}
"""

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_units_api()
	_test_cast_end_to_end()
	_test_cooldown()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("ACTIVE FAIL: " + label)


func _mk(id: String, grid: Vector2i, kind: String, faction: String) -> Dictionary:
	return DefEntity.make(id, kind, faction, id, "duelist",
		{"hp": 100.0, "atk": 0.0, "armor": 0.0, "hit": 0.9, "evade": 0.05,
			"grid": grid, "range_hex": 1})


func _test_units_api() -> void:
	var sim := BattleSim.new(7)
	var hero := _mk("hero_1", Vector2i(0, 0), "hero", "player")
	var mob1 := _mk("mob_1", Vector2i(1, 0), "enemy", "enemy")
	var ally := _mk("hero_2", Vector2i(1, 1), "hero", "player")
	var mob2 := _mk("mob_2", Vector2i(3, 0), "enemy", "enemy")
	sim.add_entity(hero)
	sim.add_entity(mob1)
	sim.add_entity(ally)
	sim.add_entity(mob2)
	var us := sim.units_in_radius(hero, 2)
	_check(us.size() == 3, "半径 2 内全部活体(含友军) 实际 %d" % us.size())
	var ids := []
	for u in us:
		ids.append(u.id)
	_check("mob_1" in ids and "hero_2" in ids and not "mob_2" in ids, "不分阵营且排除远敌")
	var es := sim.enemies_in_radius(hero, 2)
	_check(es.size() == 1 and es[0].id == "mob_1", "enemies_in_range 仍只含敌人")


func _test_cast_end_to_end() -> void:
	var sim := BattleSim.new(7)
	var hero := _mk("hero_1", Vector2i(0, 2), "hero", "player")
	var mob1 := _mk("mob_1", Vector2i(1, 2), "enemy", "enemy")   # 距离 1
	var ally := _mk("hero_2", Vector2i(0, 0), "hero", "player")   # 距离 2
	var mob2 := _mk("mob_2", Vector2i(5, 2), "enemy", "enemy")    # 距离 5(超范围)
	DefEntity.apply_status(mob1, "rooted", 99999, "t")
	DefEntity.apply_status(mob2, "rooted", 99999, "t")
	sim.add_entity(hero)
	sim.add_entity(mob1)
	sim.add_entity(ally)
	sim.add_entity(mob2)
	var parsed := Parser.new().parse(SRC_QUAKE)
	_check(parsed.ok, "震地怒涛可解析 " + str(parsed.errors))
	var checked := Checker.new().check(parsed.ast)
	_check(checked.ok, "units_in_range 通过静态校验 " + str(checked.errors))
	var weapon := {"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []}
	sim.add_contract("c_quake", checked.ast, "hero_1", weapon)
	sim.schedule_active("c_quake", 10)
	for i in 20:
		sim.tick_once()
	_check(DefEntity.has_status(hero, "stunned"), "施放者自身被晕(AOE 不分敌我)")
	_check(DefEntity.has_status(mob1, "stunned"), "范围内敌人被晕")
	_check(DefEntity.has_status(ally, "stunned"), "范围内友军被晕")
	_check(not DefEntity.has_status(mob2, "stunned"), "范围外敌人不受影响")
	_check(absf(weapon.durability - 97.0) < 0.001, "施放耗耐久 3 (实际 %.0f)" % weapon.durability)
	var cast_event := false
	for ev in sim.events:
		if ev.get("kind") == "active_cast" and int(ev.get("tick", -1)) == 10:
			cast_event = true
	_check(cast_event, "active_cast 事件于 tick 10 产生")
	var scheduled := false
	for entry in sim.input_log:
		if entry.get("cmd") == "active" and int(entry.get("tick", -1)) == 10:
			scheduled = true
	_check(scheduled, "input_log 记录主动指令")


func _test_cooldown() -> void:
	var sim := BattleSim.new(7)
	var hero := _mk("hero_1", Vector2i(0, 2), "hero", "player")
	sim.add_entity(hero)
	var parsed := Parser.new().parse(SRC_QUAKE)
	var checked := Checker.new().check(parsed.ast)
	var weapon := {"id": "w_1", "max_durability": 100.0, "durability": 100.0, "defects": []}
	sim.add_contract("c_quake", checked.ast, "hero_1", weapon)
	sim.schedule_active("c_quake", 10)
	sim.schedule_active("c_quake", 30)   # 冷却 300 tick 内,应被门控
	sim.schedule_active("c_quake", 320)  # 冷却结束后,应再次触发
	for i in 340:
		sim.tick_once()
	_check(absf(weapon.durability - 94.0) < 0.001,
		"冷却门控: 10 与 320 各耗 3, 30 被拦 (实际 %.0f)" % weapon.durability)
	var casts := 0
	for ev in sim.events:
		if ev.get("kind") == "active_cast":
			casts += 1
	_check(casts == 2, "仅两次有效施放 (实际 %d)" % casts)
