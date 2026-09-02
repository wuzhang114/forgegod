## BattleReport: 战斗结果的结构化记录(可序列化;结算/战报/统计统一来源)。
## 结果类型: player_win | enemy_win | draw | timeout | retreat。

extends RefCounted

## 由 BattleSim + BattleScenario 生成战报。sim: 结算用 BattleSim。
func build(sim, scenario) -> Dictionary:
	var result := "draw"
	var r: String = str(sim.battle_result)
	if r == "player_win" or r == "enemy_win" or r == "retreat":
		result = r
	elif r == "timeout":
		result = "timeout"
	else:
		# 结束但未判定: 双存活为 draw
		var p := 0
		var e := 0
		for ent in sim.entities.values():
			if not ent.alive:
				continue
			if ent.kind == "hero":
				p += 1
			elif ent.kind == "enemy":
				e += 1
		if p > 0 and e > 0:
			result = "draw"
		elif p > 0:
			result = "player_win"
		elif e > 0:
			result = "enemy_win"
	var units := {}
	for ent in sim.entities.values():
		units[ent.id] = {"role": ent.get("role", ""), "kind": ent.kind,
			"alive": ent.alive, "hp": ent.hp, "max_hp": ent.max_hp}
	var summary: Dictionary = sim.summary_report()
	return {
		"scenario_id": scenario.scenario_id,
		"rules_version": scenario.rules_version,
		"seed": scenario.seed,
		"result": result,
		"ticks": sim.tick,
		"duration_s": float(sim.tick) / 20.0,
		"units": units,
		"combat": summary.get("units", {}),
		"contracts": summary.get("contracts", {}),
		"event_count": sim.events.size(),
	}


## 奖励结算(第 4 步 Settlement 用): 胜负 -> 金钱/声望
static func rewards(result: String) -> Dictionary:
	match result:
		"player_win":
			return {"money": 60.0, "reputation": 2.0}
		"draw":
			return {"money": 30.0, "reputation": 0.0}
		"timeout":
			return {"money": 20.0, "reputation": 0.0}
		"retreat":
			return {"money": 0.0, "reputation": -2.0}
		_:
			return {"money": 10.0, "reputation": -1.0}   # enemy_win
