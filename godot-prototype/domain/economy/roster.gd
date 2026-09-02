## RosterOps: 勇者队伍状态(伤势/休整;数据在 RunState.roster)。
## 成员: {id, role, name, hp_ratio, wounds, contract_cid?}

extends RefCounted


## 同步战斗存活/伤势(战报 -> 队伍): 重伤(血量<50%)+1 伤势
static func sync_from_report(run, report: Dictionary) -> void:
	var units: Dictionary = report.get("units", {})
	for uid in units.keys():
		if not str(uid).begins_with("hero_"):
			continue
		var u: Dictionary = units[uid]
		if not u.get("alive", false):
			continue
		var ratio := float(u.get("hp", 0.0)) / maxf(float(u.get("max_hp", 1.0)), 1.0)
		var entry := _upsert(run, uid, str(u.get("role", "")), str(u.get("name", uid)))
		entry["hp_ratio"] = snappedf(ratio, 0.01)
		if ratio < 0.5:
			entry["wounds"] = int(entry.get("wounds", 0)) + 1


## 每日休整(返回铁匠铺): 伤势 -1(至少 0),血量恢复 25%
static func rest(run) -> void:
	for m in run.roster:
		m["hp_ratio"] = minf(float(m.get("hp_ratio", 1.0)) + 0.25, 1.0)
		m["wounds"] = maxi(int(m.get("wounds", 0)) - 1, 0)


static func _upsert(run, uid: String, role: String, name: String) -> Dictionary:
	for m in run.roster:
		if str(m.get("id", "")) == uid:
			return m
	var m := {"id": uid, "role": role, "name": name, "hp_ratio": 1.0, "wounds": 0}
	run.roster.append(m)
	return m
