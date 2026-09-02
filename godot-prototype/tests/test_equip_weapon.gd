## EquipWeapon(装备用例)测试。
## 由 run_headless.gd 调用; 运行: godot --headless --path godot-prototype -s tests/run_headless.gd

extends RefCounted

const RunState := preload("res://app/run_state.gd")
const EquipWeapon := preload("res://application/equip_weapon.gd")
const WeaponStats := preload("res://core/forge/weapon_stats.gd")

var _passes := 0
var _fails := 0


func run() -> Dictionary:
	_test_equip()
	_test_swap_and_release()
	_test_loadout_and_contract()
	_test_combat_panel()
	return {"ok": _fails == 0, "pass": _passes, "fail": _fails}


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("EQUIP FAIL: " + label)


func _mk_run() -> RunState:
	var r := RunState.new()
	r.new_run(7)
	return r


func _mk_inst(iid: String, name: String) -> Dictionary:
	return {"instance_id": iid, "facts": {"name": name, "craft": {"purity": 90.0, "structure": 80.0,
		"temper": 85.0, "balance": 80.0}, "defects": []},
		"durability": 100.0, "contracts": [], "holder_id": ""}


func _test_equip() -> void:
	var r := _mk_run()
	var inst := _mk_inst("w_1", "试剑")
	var res := EquipWeapon.equip(r, inst, "hero_2")
	_check(res.get("ok", false), "装备成功")
	_check(r.weapons.size() == 4, "武器入库(3 默认 + 1)")
	var lo := EquipWeapon.loadout_of(r, "hero_2")
	_check(not lo.is_empty() and str(lo.get("facts", {}).get("name", "")) == "试剑", "loadout 可查")
	_check(EquipWeapon.loadout_of(r, "hero_1").get("instance_id", "") != "w_1", "原有者未被动")


func _test_swap_and_release() -> void:
	var r := _mk_run()
	var inst := _mk_inst("w_1", "试剑")
	EquipWeapon.equip(r, inst, "hero_2")
	# 同一把武器换给另一人: 旧人解除
	var inst2 := _mk_inst("w_1", "试剑")
	EquipWeapon.equip(r, inst2, "hero_3")
	_check(EquipWeapon.loadout_of(r, "hero_2").is_empty(), "旧持有者解除")
	_check(str(EquipWeapon.loadout_of(r, "hero_3").get("instance_id", "")) == "w_1", "新持有者接上")
	# 再握回来
	EquipWeapon.equip(r, _mk_inst("w_1", "试剑"), "hero_2")
	_check(EquipWeapon.loadout_of(r, "hero_3").is_empty() and not EquipWeapon.loadout_of(r, "hero_2").is_empty(),
		"换手正常")


func _test_loadout_and_contract() -> void:
	var r := _mk_run()
	_check(EquipWeapon.weapon_with_contract(r).get("instance_id", "") == "demon_bulwark",
		"默认武器已带契约(c_bulwark)")
	var inst := _mk_inst("w_new", "试剑")
	inst["contracts"] = [{"cid": "c_player", "src": "device 定稿 { on block { damage_weapon(1) } }"}]
	EquipWeapon.equip(r, inst, "hero_1")
	var wc := EquipWeapon.weapon_with_contract(r)
	_check(str(wc.get("instance_id", "")) in ["demon_bulwark", "w_new"], "携带契约的武器可查")
	# add_contract 追加
	_check(EquipWeapon.add_contract(r, "w_new", "c_extra", "device 附加 { on hit { damage_weapon(1) } }"),
		"追加契约成功")
	var w2 := EquipWeapon.loadout_of(r, "hero_1")
	_check((w2.get("contracts", []) as Array).size() == 2, "实例契约数 2")
	_check(not EquipWeapon.add_contract(r, "nope", "c", "device x"), "未知实例追加失败")


func _test_combat_panel() -> void:
	# 装备武器的英雄按实例 facts 计算战斗面板(与徒手默认不同)
	var r := _mk_run()
	EquipWeapon.equip(r, _mk_inst("w_1", "神铸"), "hero_1")
	var lo := EquipWeapon.loadout_of(r, "hero_1")
	var ws := WeaponStats.from_facts(lo.get("facts", {}))
	_check(absf(ws.atk_mult - (0.75 + 0.5 * 0.9)) < 0.001, "装备面板按实例四维(纯度90)")
	var opt := {"atk": 10.0, "hit": 0.9, "crit_mult": 1.5, "atk_speed": 1.0}
	WeaponStats.apply_to_opt(opt, ws)
	_check(absf(opt.atk - 10.0 * 1.2) < 0.001, "装备者攻击=模板×面板")
