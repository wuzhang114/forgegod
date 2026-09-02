## WeaponStats: 锻造产物(ForgeCore.build) -> 战斗武器面板(确定性)。
## 规则(创作者定稿): 装备增伤一律进基础攻击区(atk_mult);
## 武器特性增伤进独立乘区(wbonus,与目标易伤同桶加算);契约 traits 优先级最高。
## 数值系数唯一来源: core/config/balance.gd WEAPON 段。

extends RefCounted

const Bal := preload("res://core/config/balance.gd")


## forge facts -> 战斗武器属性
## 返回: {atk_mult, crit_mult, hit, shred, wbonus, durability, max_durability,
##        speed_mult, defects( MechLang 兼容词数组 ) , purity, structure, temper, balance}
static func from_facts(facts: Dictionary) -> Dictionary:
	var craft: Dictionary = facts.get("craft", {})
	var purity := float(craft.get("purity", 60.0))
	var structure := float(craft.get("structure", 60.0))
	var temper := float(craft.get("temper", 60.0))
	var balance_f := float(craft.get("balance", 60.0))
	var w: Dictionary = Bal.WEAPON

	var out := {
		"atk_mult": float(w.ATK_BASE) + float(w.ATK_PURITY) * purity / 100.0,
		"crit_mult": float(w.CRIT_BASE) + float(w.CRIT_TEMPER) * temper / 100.0,
		"hit": clampf(float(w.HIT_BASE) + float(w.HIT_BALANCE) * balance_f / 100.0,
			float(w.HIT_FLOOR), 1.0),
		"shred": maxf((temper - float(w.SHRED_START)) * float(w.SHRED_STEP), 0.0),
		"wbonus": maxf((temper - float(w.WBONUS_START)) / 100.0 * float(w.WBONUS_STEP), 0.0),
		"durability": float(w.DUR_BASE) + float(w.DUR_STRUCTURE) * structure,
		"speed_mult": float(w.SPEED_BASE) + float(w.SPEED_BALANCE) * balance_f / 100.0,
		"purity": purity, "structure": structure, "temper": temper, "balance": balance_f,
	}
	# 缺陷 -> 负面效果 + MechLang 兼容词(has_defect 可查)
	var mech_defects: Array = []
	for d in facts.get("defects", []):
		var did := str(d.get("id", ""))
		match did:
			"defect.impurity":
				out.hit = maxf(out.hit - float(w.DEFECT_HIT_PENALTY), float(w.HIT_FLOOR))
				mech_defects.append("impurity")
			"defect.weak_structure":
				out.durability = maxf(out.durability * float(w.DEFECT_DUR_FACTOR), 1.0)
				mech_defects.append("weak_structure")
			"defect.off_balance":
				out.speed_mult = maxf(out.speed_mult * float(w.DEFECT_SPEED_FACTOR), float(w.SPEED_FLOOR))
				mech_defects.append("off_balance")
			"defect.stress_crack":
				mech_defects.append("stress_crack")
	out["defects"] = mech_defects
	out["max_durability"] = out.durability
	return out


## 默认(演示用): 四维 60 的均衡武器(无缺陷)
static func default_stats() -> Dictionary:
	return from_facts({"craft": {"purity": 60.0, "structure": 60.0, "temper": 60.0,
		"balance": 60.0}, "defects": []})


## 应用武器面板到实体模板 opt(英雄享受武器;敌人不带)
static func apply_to_opt(opt: Dictionary, ws: Dictionary) -> void:
	opt.atk = float(opt.get("atk", 10.0)) * float(ws.atk_mult)                    # 基础攻击区
	opt.hit = clampf(float(opt.get("hit", 0.9)) * float(ws.hit), 0.05, 0.95)      # 命中
	opt.crit_mult = float(ws.crit_mult)                                           # 暴击档
	opt.weapon_shred = float(ws.shred)                                            # 武器破甲(独立于动作)
	opt.weapon_bonus = float(ws.wbonus)                                           # 独立乘区(同桶加算)
	opt.atk_speed = float(opt.get("atk_speed", 1.0)) * float(ws.speed_mult)       # 攻速
