## SettleDay: 战斗后的每日结算用例(垂直切片核心)。
## 输入 run + 战报;输出: 赏金/声望/日推进/队伍伤势同步/休整,并记录结算结果。

extends RefCounted

const BattleReport := preload("res://domain/battle/battle_report.gd")
const RosterOps := preload("res://domain/economy/roster.gd")


## 执行结算(幂等: 以 run.world_flags.last_settled_id 防重复结算同一场)
static func settle(run, report: Dictionary) -> Dictionary:
	var sc_id := str(report.get("scenario_id", ""))
	if str(run.world_flags.get("last_settled_id", "")) == sc_id:
		return {"ok": false, "skipped": true, "reason": "已结算"}
	var result := str(report.get("result", "draw"))
	var rewards: Dictionary = BattleReport.rewards(result)
	run.money += float(rewards.get("money", 0.0))
	run.world_flags["reputation"] = float(run.world_flags.get("reputation", 0.0)) + float(rewards.get("reputation", 0.0))
	# 队伍伤势: 先休整(旧伤 -1),再同步今日战场重伤
	RosterOps.rest(run)
	RosterOps.sync_from_report(run, report)
	# 日推进
	run.current_day += 1
	run.world_flags["last_settled_id"] = sc_id
	run.expedition["last_report"] = report
	var out := {"ok": true, "result": result, "money_gain": float(rewards.get("money", 0.0)),
		"reputation": float(run.world_flags.get("reputation", 0.0)), "day": run.current_day}
	run.world_flags["last_settlement"] = out
	return out


## 锻造消耗(垂直切片: 每把武器消耗 1 铁矿 + 1 煤;入 ContentRegistry 节流点)
const FORGE_COST := {"iron_ore": 1, "coal": 1}


static func can_forge(run) -> bool:
	for k in FORGE_COST.keys():
		if int(run.inventory.get(k, 0)) < int(FORGE_COST[k]):
			return false
	return true
