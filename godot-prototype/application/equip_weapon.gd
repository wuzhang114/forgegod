## EquipWeapon: 装备用例(武器实例 <-> 队伍 loadout;纯逻辑可测)。
## 模型: run.weapons(武器实例库) + run.roster[].weapon_id(持有);一把武器同时只在一人手上。

extends RefCounted


## 装备: 武器实例(库内存在则更新,否则追加)归属给 hero_id;其他英雄解除该武器引用
static func equip(run, instance: Dictionary, hero_id: String) -> Dictionary:
	var iid := str(instance.get("instance_id", ""))
	if iid == "":
		return {"ok": false, "error": "instance without id"}
	instance["holder_id"] = hero_id
	var found := false
	for w in run.weapons:
		if str(w.get("instance_id", "")) == iid:
			for k in instance.keys():
				w[k] = instance[k]
			found = true
			break
	if not found:
		run.weapons.append(instance.duplicate(true))
	# 同步 roster: 装备者承接,其余英雄解除
	_upsert_hero(run, hero_id, iid)
	for m in run.roster:
		if str(m.get("id", "")) != hero_id and str(m.get("weapon_id", "")) == iid:
			m["weapon_id"] = ""
	return {"ok": true, "instance_id": iid}


## 某英雄当前装备(旧实例壳;无则空 dict)
static func loadout_of(run, hero_id: String) -> Dictionary:
	for m in run.roster:
		if str(m.get("id", "")) == hero_id:
			var wid := str(m.get("weapon_id", ""))
			if wid != "":
				for w in run.weapons:
					if str(w.get("instance_id", "")) == wid:
						return w
	return {}


## 库中携带神赐契约的武器实例(定稿那把;用于战斗契约持有人定位)
static func weapon_with_contract(run) -> Dictionary:
	for w in run.weapons:
		if str(w.get("contract_src", "")).strip_edges() != "":
			return w
	return {}


static func _upsert_hero(run, hero_id: String, iid: String) -> void:
	for m in run.roster:
		if str(m.get("id", "")) == hero_id:
			m["weapon_id"] = iid
			return
	run.roster.append({"id": hero_id, "role": "", "name": hero_id, "hp_ratio": 1.0,
		"wounds": 0, "weapon_id": iid})
