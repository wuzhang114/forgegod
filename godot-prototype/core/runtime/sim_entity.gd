class_name SimEntityDef
## 战斗实体:轻量数据化结构(纯 Dictionary),由 BattleSim 管理。
## B2.6(六边形重构): 位置 = 网格坐标 grid(Vector2i axial);射程/移动以"格"为单位;
## 像素位置由播放器从 grid 投影 + 滑动插值产生。

const Grid := preload("res://core/runtime/hex_grid.gd")
const Bal := preload("res://core/config/balance.gd")


## 创建实体。kind: hero | enemy | summon;faction: player | enemy
static func make(id: String, kind: String, faction: String, name: String, role: String, opt: Dictionary = {}) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"faction": faction,
		"name": name,
		"role": role,
		"hp": float(opt.get("hp", 100.0)),
		"max_hp": float(opt.get("hp", 100.0)),
		"atk": float(opt.get("atk", 10.0)),
		"armor": float(opt.get("armor", 0.0)),
		"hit": float(opt.get("hit", 0.9)),
		"evade": float(opt.get("evade", 0.05)),
		"crit_mult": float(opt.get("crit_mult", 1.5)),
		"grid": opt.get("grid", Vector2i.ZERO),      # 六边形轴向坐标
		"range_hex": int(opt.get("range_hex", 1)),   # 攻击射程(格)
		"move_interval": int(opt.get("move_interval", 12)),  # 每移动一格所需 tick
		"move_t": 0,                                  # 移动累积 tick
		"focus_target": "",            # 集火倾向(指令)
		"focus_manual": false,         # 指令是否手动设置(受击转火不覆盖手动指令)
		"cur_target": "",              # 目标粘性: 当前锁定目标(死亡/过期才换)
		"sticky_ticks": 0,             # 目标粘性剩余窗口(tick)
		"statuses": {},                # status_id -> {ticks, stacks, source_id}
		"weapon_shred": float(opt.get("weapon_shred", 0.0)),  # 武器词条破甲(锻造 trait)
		"weapon_bonus": float(opt.get("weapon_bonus", 0.0)),  # 武器特性增伤(独立乘区,同桶加算)
		"empower_left": int(opt.get("empower_left", 0)),      # 攻速强化剩余攻击次数(嗜血之舞)
		"empower_mult": float(opt.get("empower_mult", 1.0)),  # 攻速倍率(封顶 2.0)
		"current_action": {},          # {tag, target_id, phase, t, windup, active, recover}
		"atk_speed": 1.0,              # 攻速倍率(动作帧时长 = 基础 / (1 + atk_speed 增量))
		"alive": true,
		"deaths": 0,
	}


## 状态操作(纯数据)
## DoT 类(burning/poisoned/bleeding/withering)重复挂载 = 叠加层数(封顶 stacks_max);其余 = 刷新时长
static func apply_status(e: Dictionary, status_id: String, ticks: int, source_id: String) -> void:
	var cfg := Bal.status_cfg(status_id)
	var is_dot: bool = cfg.get("dot", 0.0) > 0.0
	if not e.statuses.has(status_id):
		e.statuses[status_id] = {"ticks": ticks, "stacks": 1, "source_id": source_id}
		return
	var st: Dictionary = e.statuses[status_id]
	st.ticks = maxi(st.ticks, ticks)
	if is_dot:
		st.stacks = mini(int(st.get("stacks", 1)) + 1, int(cfg.get("stacks_max", 3)))
	if st.get("source_id", "") == "":
		st.source_id = source_id


static func has_status(e: Dictionary, status_id: String) -> bool:
	return e.statuses.has(status_id)


static func remove_status(e: Dictionary, status_id: String) -> void:
	e.statuses.erase(status_id)


static func tick_statuses(e: Dictionary) -> void:
	# 每 tick 递减(DoT 跳伤在 BattleSim 的结算点统一处理,B1 只做到期移除)
	for sid in e.statuses.keys().duplicate():
		var st: Dictionary = e.statuses[sid]
		st.ticks -= 1
		if st.ticks <= 0:
			e.statuses.erase(sid)


static func distance(a: Dictionary, b: Dictionary) -> float:
	return float(Grid.dist(a.grid, b.grid))


## ---- 状态 → 行为接线(金铲铲对照:A-D 修复) ----

## 移动速度倍率(slowed ×0.7 / haste ×1.15)
static func move_speed_mult(e: Dictionary) -> float:
	var m := 1.0
	if has_status(e, "slowed"):
		m *= 0.7
	if has_status(e, "haste"):
		m *= 1.15
	return m


## 动作帧时长倍率(受攻速/减速/急速影响): 基础帧 × mult
static func frame_mult(e: Dictionary) -> float:
	var m := 1.0 / maxf(float(e.get("atk_speed", 1.0)), 0.2)
	if has_status(e, "slowed"):
		m *= 1.3
	if has_status(e, "haste"):
		m *= 0.85
	return m


## 是否被硬控(stunned/frozen/paralyzed/floating)
static func is_hard_cc(e: Dictionary) -> bool:
	return has_status(e, "stunned") or has_status(e, "frozen") \
		or has_status(e, "paralyzed") or has_status(e, "floating")


## 是否被缴械(攻击全部禁用)
static func is_disarmed(e: Dictionary) -> bool:
	return has_status(e, "disarmed")


## 是否被缄默(技能类动作禁用: ranged/channel; 普攻可用)
static func is_silenced(e: Dictionary) -> bool:
	return has_status(e, "silenced")


## 是否恐惧(背离移动,不攻击)
static func is_feared(e: Dictionary) -> bool:
	return has_status(e, "feared")


## 攻击输出(weakened -20%)
static func atk_mult(e: Dictionary) -> float:
	return 0.8 if has_status(e, "weakened") else 1.0


## 最近敌人(以 hex 距离)<忽略 faction 相同的召唤物归属:以 faction 判定敌我>
static func nearest_enemy_of(mine: Dictionary, entities: Dictionary, range: int = 999) -> Dictionary:
	var best: Dictionary = {}
	var best_d := range
	for other in entities.values():
		if other.id == mine.id or not other.alive:
			continue
		if other.faction == mine.faction:
			continue
		var d := int(Grid.dist(mine.grid, other.grid))
		if d < best_d:
			best_d = d
			best = other
	return best
