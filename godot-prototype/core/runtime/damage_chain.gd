class_name DamageChain
## 伤害判定链(02-battle-system-design.md §5):
## 命中判定 → 格挡判定 → 六区伤害结算 → 事件对象生成。
## 六区: 基础攻击 × 动作倍率 × 增伤区(≤上限) × 暴击区 × 防御区 × 独立乘区。
## 全部数值来自 core/config/balance.gd(唯一数值源)。纯函数式: 不修改实体,由 BattleSim 应用结果。

const DefAction := preload("res://core/runtime/sim_actions.gd")
const Bal := preload("res://core/config/balance.gd")

const EVADE_FLOOR: float = 0.05
const EVADE_CEIL: float = 0.95


## 计算一次命中的伤害结果(不含命中 roll,交由 resolve_attack 统一)
## 返回 {landed, blocked, crit_tier, base, final_damage, armor_after, shred, blocked_damage}
static func resolve_attack(attacker: Dictionary, target: Dictionary, action_tag: String,
		rng, dmg_bonus: float, vuln: float, traits: Dictionary = {}) -> Dictionary:
	var action := DefAction.get_def(action_tag)
	var atk: float = attacker.atk
	var armor: float = target.armor
	# 破甲 = 动作自带 + 武器词条(锻造 trait)
	var shred: float = float(action.get("armor_shred", 0.0)) + float(attacker.get("weapon_shred", 0.0))
	var base: float = atk * Bal.action_mult(action_tag)

	# ---- 命中判定 ----
	var evade: float = target.evade
	if traits.get("ignores_evade", {}).get("value", false):
		evade = 0.0
	var hit_cfg: Dictionary = Bal.HIT
	var hit_chance: float = clampf(attacker.hit - evade,
		float(hit_cfg.EVADE_FLOOR), float(hit_cfg.EVADE_CEIL))
	var landed: bool = traits.get("guaranteed_hit", {}).get("value", false)
	if not landed:
		landed = rng.rand_range(0.0, 1.0) < hit_chance
	if not landed:
		return {"landed": false, "blocked": false, "crit_tier": 0.0,
			"base": base, "final_damage": 0.0, "armor_after": armor,
			"shred": shred, "blocked_damage": 0.0}

	# ---- 格挡判定 ----
	var is_blocking: bool = DefAction.is_block_tag(target.current_action.get("tag", "")) \
			and target.current_action.get("phase", "") == "active"
	if is_blocking:
		return {"landed": true, "blocked": true, "crit_tier": 0.0,
			"base": base, "final_damage": 0.0, "armor_after": armor,
			"shred": shred, "blocked_damage": base}

	# ---- 暴击档(离散三档,数值来自 Balance) ----
	var roll = rng.rand_range(0.0, 1.0)
	var crit_cfg: Dictionary = Bal.CRIT
	var crit_tier := 1.0
	if roll >= float(crit_cfg.ROLL_HIGH):
		crit_tier = float(traits.get("crit_mult", {}).get("value", attacker.crit_mult))
	elif roll <= float(crit_cfg.ROLL_LOW):
		crit_tier = float(crit_cfg.LOW)

	# ---- 六区结算(数值全部来自 Balance) ----
	var armor_after: float = maxf(armor - shred, 0.0)
	var defense: float = float(Bal.DAMAGE.ARMOR_BASE) / (float(Bal.DAMAGE.ARMOR_BASE) + armor_after)
	var bonus := clampf(dmg_bonus, 0.0, float(Bal.DAMAGE.BONUS_CAP))   # 增伤区上限
	# 独立乘区(单桶加算,含上限): 目标易伤 + 武器特性增伤(创作者规则)
	var indep := clampf(1.0 + maxf(vuln, 0.0) + maxf(float(attacker.get("weapon_bonus", 0.0)), 0.0),
		0.0, float(Bal.DAMAGE.INDEP_MAX))
	var final_damage: float = base * (1.0 + bonus) * crit_tier * defense * indep
	return {"landed": true, "blocked": false, "crit_tier": crit_tier,
		"base": base, "final_damage": final_damage, "armor_after": armor_after,
		"shred": shred, "blocked_damage": 0.0}
