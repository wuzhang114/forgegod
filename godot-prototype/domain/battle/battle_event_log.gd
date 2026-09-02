## BattleEventLog: 事件结构化/版本化包装(裸 Dictionary 只留在序列化边缘)。
## 提供: 版本标记 / 查询 / 摘要;表现层与报告层共用同一定义。

extends RefCounted

const EVENT_VERSION := 1
const EVENT_KINDS := [
	"attack", "kill", "mech_damage", "healed", "status_apply", "interrupt",
	"armor_break", "weapon_cost", "block_ready", "projectile_launch",
	"projectile_hit", "mechanic_damage", "active_cast", "scorch", "cell_enter",
	"cell_exit", "timer",
]


## 规范化裸事件: 补 version 与缺失字段(兼容旧事件;越狱字段保留)
## 注: 避免命名 wrap(Godot 内置 wrap(value,min,max))
static func sanitize(raw: Dictionary) -> Dictionary:
	var ev := raw.duplicate(true)
	ev["v"] = EVENT_VERSION
	if not ev.has("tick"):
		ev["tick"] = -1
	if not ev.has("kind"):
		ev["kind"] = "unknown"
	return ev


static func sanitize_all(raw: Array) -> Array:
	var out: Array = []
	for r in raw:
		out.append(sanitize(r))
	return out


## 按 kind 抽取(可选 tick 区间)
static func query(events: Array, kind: String, from_tick: int = -1, to_tick: int = -1) -> Array:
	var out: Array = []
	for ev in events:
		if ev.get("kind", "") != kind:
			continue
		var t := int(ev.get("tick", -1))
		if from_tick >= 0 and t < from_tick:
			continue
		if to_tick >= 0 and t > to_tick:
			continue
		out.append(ev)
	return out


## 摘要: 各 kind 计数(战报用)
static func summarize(events: Array) -> Dictionary:
	var out := {}
	for ev in events:
		var k := str(ev.get("kind", "unknown"))
		out[k] = int(out.get(k, 0)) + 1
	return out
