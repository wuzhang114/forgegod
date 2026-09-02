## InventoryOps: 材料库存操作(纯逻辑;数据在 RunState.inventory)。

extends RefCounted


## 尝试消耗一组材料 {"id": count};不足返回 false 且不扣
static func consume(run, costs: Dictionary) -> bool:
	for k in costs.keys():
		if int(run.inventory.get(k, 0)) < int(costs[k]):
			return false
	for k in costs.keys():
		run.inventory[k] = int(run.inventory.get(k, 0)) - int(costs[k])
	return true


## 加材料
static func grant(run, gains: Dictionary) -> void:
	for k in gains.keys():
		run.inventory[k] = int(run.inventory.get(k, 0)) + int(gains[k])


## 库存文本(UI 用)
static func describe(run) -> String:
	var parts: Array = []
	for k in run.inventory.keys():
		parts.append("%s×%d" % [k, int(run.inventory[k])])
	return " · ".join(parts)
