## ForgeCalculator: 武器计算的唯一模块(消除"面板预览公式/战斗换算"多套来源)。
## 输入 锻造选择 -> 输出 {craft(四维), material_preview(手感面板), combat_summary(战斗换算), facts, defects}
## 面板显示的数值 == 战斗实际使用的数值(同一 build 通道)。

extends RefCounted

const Forge := preload("res://core/forge/forge_core.gd")
const WeaponStats := preload("res://core/forge/weapon_stats.gd")


## 材料性质 + 尺寸 -> 手感面板 6 项(原 forge_scene._stats 公式的唯一归属)
static func material_preview(parts: Dictionary, size: Dictionary) -> Dictionary:
	var ma: Dictionary = Forge.MATERIALS.get(str(parts.action), Forge.MATERIALS["grey_iron"])
	var mb: Dictionary = Forge.MATERIALS.get(str(parts.bearing), Forge.MATERIALS["grey_iron"])
	var mc: Dictionary = Forge.MATERIALS.get(str(parts.control), Forge.MATERIALS["grey_iron"])
	var mm: Dictionary = Forge.MATERIALS.get(str(parts.medium), Forge.MATERIALS["grey_iron"])
	var center_ok: float = 0.5 - absf(float(size.balance) - 0.5)
	var atk := int(round(float(ma.hardness) * 6.0 + float(size.thickness) * 18.0 + (1.0 - float(size.length)) * 8.0))
	var tough := int(round(float(mb.toughness) * 7.0 + center_ok * 20.0))
	var speed := int(round(20.0 + (1.0 - float(mc.density)) * 7.0 + (1.0 - float(size.length)) * 10.0))
	var ctrl := int(round(float(mc.stability) * 7.0 + center_ok * 30.0))
	var cond := int(round(float(mm.conduction) * 7.0 + float(ma.conduction) * 1.5))
	var stab := int(round((float(ma.stability) + float(mb.stability) + float(mc.stability)) / 3.0 * 7.0))
	return {"攻击": atk, "坚韧": tough, "速度": speed, "操控": ctrl, "导能": cond, "稳定": stab}


## 成品 facts -> 战斗换算(唯一来源: WeaponStats;与战斗实际生效值一致)
static func combat_summary(facts: Dictionary) -> Dictionary:
	var ws := WeaponStats.from_facts(facts)
	return {
		"攻×": snappedf(ws.atk_mult, 0.01),
		"暴×": snappedf(ws.crit_mult, 0.01),
		"破甲+": snappedf(ws.shred * 100.0, 1.0),
		"独立+": snappedf(ws.wbonus * 100.0, 1.0),
		"耐久": snappedf(ws.durability, 1.0),
		"攻速×": snappedf(ws.speed_mult, 0.01),
		"缺陷": ws.defects,
	}


## 由锻造选择构造"预览产物"(四维/事实/面板;不落库): 与最终 build 同通道
static func preview_build(weapon_id: String, kind: String, parts: Dictionary, size: Dictionary,
		craft_choices: Dictionary) -> Dictionary:
	return Forge.build(weapon_id, kind, "预览 " + str(Forge.KINDS.get(kind, {}).get("name", kind)),
		parts, size, craft_choices)
