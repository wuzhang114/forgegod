## 经营域垂直切片测试: 库存消耗 / 每日结算(赏金/声望/伤势/休整/日推进)/ 幂等。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const RunState := preload("res://app/run_state.gd")
const Inventory := preload("res://domain/economy/inventory.gd")
const RosterOps := preload("res://domain/economy/roster.gd")
const SettleDay := preload("res://application/settle_day.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_inventory()
	_test_settle_rewards()
	_test_settle_idempotent()
	_test_roster_wounds()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("SETTLE FAIL: " + label)


func _mk_run(seed: int = 1) -> RunState:
	var r := RunState.new()
	r.new_run(seed)
	return r


func _test_inventory() -> void:
	var r := _mk_run()
	_check(Inventory.consume(r, {"iron_ore": 1, "coal": 1}), "材料足够消耗成功")
	_check(int(r.inventory.iron_ore) == 2 and int(r.inventory.coal) == 1, "扣减正确")
	_check(not Inventory.consume(r, {"iron_ore": 9}), "不足时拒绝")
	_check(int(r.inventory.iron_ore) == 2, "拒绝时未扣")
	Inventory.grant(r, {"coal": 2})
	_check(int(r.inventory.coal) == 3, "发放入库存")
	_check(SettleDay.can_forge(r), "初始库存可锻造")


func _test_settle_rewards() -> void:
	var r := _mk_run()
	var report := {"scenario_id": "sc_test", "result": "player_win",
		"units": {"hero_1": {"role": "guard", "alive": true, "hp": 150.0, "max_hp": 300.0}},
		"ticks": 100, "duration_s": 5.0}
	var out := SettleDay.settle(r, report)
	_check(out.get("ok", false) and out.get("money_gain", 0.0) == 60.0, "胜场 +60 金")
	_check(r.money == 160.0, "金币入账")
	_check(r.current_day == 2, "日 +1")
	_check(float(r.world_flags.get("reputation", 0.0)) == 2.0, "声望 +2")
	# 败场
	var r2 := _mk_run()
	var rep2 := {"scenario_id": "sc_test2", "result": "enemy_win", "units": {}, "ticks": 1}
	var out2 := SettleDay.settle(r2, rep2)
	_check(r2.money == 110.0 and float(r2.world_flags.get("reputation", 0.0)) == -1.0,
		"败场 +10/-1 声望")


func _test_settle_idempotent() -> void:
	var r := _mk_run()
	var report := {"scenario_id": "sc_dup", "result": "player_win", "units": {}, "ticks": 1}
	var out1 := SettleDay.settle(r, report)
	var out2 := SettleDay.settle(r, report)
	_check(out1.get("ok", false) and out2.get("skipped", false), "同一场不重复结算")
	_check(r.money == 160.0, "只加一次钱")


func _test_roster_wounds() -> void:
	var r := _mk_run()
	var report := {"scenario_id": "sc_w", "result": "draw",
		"units": {
			"hero_1": {"role": "guard", "name": "布兰特", "alive": true, "hp": 100.0, "max_hp": 300.0},
			"hero_2": {"role": "duelist", "name": "莉娅", "alive": true, "hp": 270.0, "max_hp": 270.0},
			"enemy_1": {"role": "brute", "alive": true, "hp": 5.0, "max_hp": 120.0},
		}, "ticks": 1}
	SettleDay.settle(r, report)
	_check(r.roster.size() == 2, "两名英雄入队(敌人不入)")
	var g: Dictionary = r.roster[0]
	_check(g.get("role", "") == "guard" and int(g.get("wounds", 0)) == 1, "重伤布兰特 +1 伤势")
	_check(absi(float(g.get("hp_ratio", 1.0)) - 0.33) < 0.011, "血量=今日实战(33%)")
	# 过夜休整: 血量回升
	RosterOps.rest(r)
	_check(float(g.get("hp_ratio", 1.0)) > 0.5, "休整后血量回升(33%→58%)")
	var d: Dictionary = r.roster[1]
	_check(int(d.get("wounds", 0)) == 0 and float(d.get("hp_ratio", 1.0)) == 1.0, "满血莉娅无伤")
