class_name ForgeCore
## 锻造核心(纯逻辑,无 UI 依赖): 材料表 → 面板选择 → WeaponFacts(4 维/缺陷/事实卡片/fingerprint)。
## 设计依据: godot-prototype/05-forge-design.md(Tetra 式面板决策版)。

const MATERIALS := {
	"grey_iron": {
		"name": "熟铁", "hardness": 5, "toughness": 6, "density": 6, "conduction": 1,
		"stability": 6, "craft": 2,
		"trait": {"id": "material.grey_iron.mendable", "label": "耐修", "text": "维修成本低,多次维修后稳定提高"},
	},
	"red_copper": {
		"name": "赤铜", "hardness": 3, "toughness": 4, "density": 7, "conduction": 8,
		"stability": 4, "craft": 5,
		"trait": {"id": "material.red_copper.flow", "label": "导流", "text": "元素与冲击可传导,支持扩散与雷电类"},
	},
	"blackwood": {
		"name": "黑木", "hardness": 4, "toughness": 7, "density": 3, "conduction": 4,
		"stability": 7, "craft": 4,
		"trait": {"id": "material.blackwood.rebound", "label": "回振", "text": "格挡或射击后保留力量,支持储蓄再释放"},
	},
	"beast_bone": {
		"name": "魔兽骨", "hardness": 3, "toughness": 8, "density": 4, "conduction": 2,
		"stability": 3, "craft": 6,
		"trait": {"id": "material.beast_bone.hunger", "label": "饥性", "text": "击杀恢复少量耐久,久不战斗则稳定下降"},
	},
	"star_iron": {
		"name": "陨铁", "hardness": 9, "toughness": 5, "density": 7, "conduction": 6,
		"stability": 5, "craft": 9,
		"trait": {"id": "material.star_iron.heavenly", "label": "天外", "text": "支持位移、坠落、星火类论证,工艺窗口极窄"},
	},
	"silverwood": {
		"name": "银木", "hardness": 5, "toughness": 5, "density": 2, "conduction": 6,
		"stability": 6, "craft": 4,
		"trait": {"id": "material.silverwood.spirit", "label": "灵亲和", "text": "可短暂容纳弱小灵体,支持召唤小精灵类"},
	},
	"void_ore": {
		"name": "虚空矿", "hardness": 4, "toughness": 3, "density": 8, "conduction": 8,
		"stability": 2, "craft": 8,
		"trait": {"id": "material.void_ore.abyss", "label": "深渊", "text": "支持吸引与吞噬类论证,会吸引附近魔法生物"},
	},
	"frost_steel": {
		"name": "霜钢", "hardness": 8, "toughness": 5, "density": 5, "conduction": 5,
		"stability": 6, "craft": 7,
		"trait": {"id": "material.frost_steel.frost", "label": "寒凝", "text": "低温淬火特性强,支持冻结与冰缓"},
	},
}

## 淬火介质: temper 加成与标签
const QUENCH_MEDIA := {
	"water":     {"label": "清水",   "temper_bonus": 18, "trait": {"id": "craft.quench.water", "text": "清水淬火:硬度优先,无特别性质"}},
	"oil":       {"label": "油脂",   "temper_bonus": 10, "trait": {"id": "craft.quench.oil", "text": "油脂淬火:温和降温,韧性略高"}},
	"salt":      {"label": "盐泉",   "temper_bonus": 14, "trait": {"id": "craft.quench.salt", "text": "盐泉淬火:晶格致密,破甲倾向"}},
	"beast_oil": {"label": "魔兽油", "temper_bonus": 16, "trait": {"id": "craft.quench.beast_oil", "text": "魔兽油淬火:嗜血,支持饥性与攻击性论证"}},
	"moon":      {"label": "月泉",   "temper_bonus": 12, "trait": {"id": "craft.quench.moon", "text": "月泉淬火:武器沾染月光,支持夜间与月光论据"}},
}

const KINDS := {
	"warhammer": {"name": "战锤", "actions": ["heavy_blow", "block", "armor_break"]},
	"longsword": {"name": "长剑", "actions": ["combo", "parry", "basic"]},
	"bow":       {"name": "弓",   "actions": ["ranged", "mark", "basic"]},
}


## 面板选择 -> WeaponFacts
## parts: {action, bearing, control, medium(可为 "" )}
## size: {length 0-1, thickness 0-1, balance 0-1}
## craft_choices: {purity_roll 0-1, quench: 介质, temper: bool, keep_stress: bool,
##                 techniques: [String], balance_bias: bool, style: "steady"|"daring"|"cracksman"}
static func build(weapon_id: String, kind: String, name: String,
		parts: Dictionary, size: Dictionary, craft_choices: Dictionary) -> Dictionary:
	var craft: Dictionary = _compute_craft(parts, size, craft_choices)
	var defects: Array = _compute_defects(craft, craft_choices)
	var facts: Array = _build_facts(parts, craft, defects, craft_choices, size)
	var canonical := _canonical(parts, size, craft, defects)
	return {
		"weapon_id": weapon_id,
		"name": name,
		"kind": kind,
		"kind_name": KINDS.get(kind, {}).get("name", kind),
		"action_tags": KINDS.get(kind, {}).get("actions", []),
		"parts": parts,
		"size": size,
		"craft": craft,
		"defects": defects,
		"facts": facts,
		"fingerprint": _sha256_hex(canonical),
	}


## ---- 四维推导(确定性: 参数 -> 数值,无随机) ----

static func _compute_craft(parts: Dictionary, size: Dictionary, c: Dictionary) -> Dictionary:
	# 纯度: 基础 58-92,按熔炼把握 roll;材料工艺难度高时收窄(材料越难,质量对把握越敏感)
	var hard_avg := _avg([_mat(parts.action).craft, _mat(parts.bearing).craft, _mat(parts.control).craft])
	if str(parts.medium) != "":
		hard_avg = (hard_avg + _mat(parts.medium).craft) / 2.0
	var purity := 58.0 + float(c.get("purity_roll", 0.5)) * 34.0 - maxf((hard_avg - 5.0) * 2.0, 0.0)
	purity = clampf(purity, 30.0, 96.0)
	# 结构: 技法加分;保留应力 -14;材料韧性高加分
	var structure := 60.0
	for t in c.get("techniques", []):
		structure += 4.0
	structure += (float(_mat(parts.bearing).toughness) - 5.0) * 2.0
	if c.get("keep_stress", false):
		structure -= 14.0
	structure = clampf(structure, 25.0, 92.0)
	# 热处理: 介质加成;回火 -8 但视为韧性;硬度属性影响上限
	var quench: String = str(c.get("quench", "water"))
	var temper := 55.0 + float(QUENCH_MEDIA.get(quench, QUENCH_MEDIA["water"]).temper_bonus)
	temper += (float(_mat(parts.action).hardness) - 5.0) * 3.0
	if c.get("temper", false):
		temper -= 8.0
	temper = clampf(temper, 30.0, 97.0)
	# 平衡: 重心居中 + 装配;偏置 -10
	var balance := 80.0 - absf(float(size.get("balance", 0.5)) - 0.5) * 60.0
	if c.get("balance_bias", false):
		balance -= 10.0
	balance = clampf(balance, 35.0, 92.0)
	return {"purity": int(round(purity)), "structure": int(round(structure)),
		"temper": int(round(temper)), "balance": int(round(balance))}


static func _compute_defects(craft: Dictionary, c: Dictionary) -> Array:
	var defects: Array = []
	if int(craft.purity) < 60:
		defects.append({"id": "defect.impurity", "label": "杂质", "desc": "低温淬火杂质:元素传导可能卡滞"})
	if c.get("keep_stress", false):
		defects.append({"id": "defect.stress_crack", "label": "内应力裂纹", "desc": "连续过载时耐久损耗提高;可成为危险爆发的论据"})
	if int(craft.structure) < 55:
		defects.append({"id": "defect.weak_structure", "label": "结构松散", "desc": "高冲击动作有断裂风险"})
	if int(craft.balance) < 55:
		defects.append({"id": "defect.off_balance", "label": "重心偏移", "desc": "操控下降,但部分动作可能因势得利"})
	return defects


static func _build_facts(parts: Dictionary, craft: Dictionary, defects: Array, c: Dictionary, size: Dictionary) -> Array:
	var facts: Array = []
	var role_names := {"action": "作用部件", "bearing": "承力部件", "control": "操控部件", "medium": "媒介部件"}
	# 材料特性(每部件)
	for role in ["action", "bearing", "control"]:
		var m: Dictionary = _mat(parts[role])
		facts.append({"id": "material.%s.%s" % [parts[role], m.trait.label],
			"text": "%s %s【%s】: %s" % [role_names[role], m.name, m.trait.label, m.trait.text]})
	if str(parts.medium) != "":
		var m2: Dictionary = _mat(parts.medium)
		facts.append({"id": "material.%s.%s" % [parts.medium, m2.trait.label],
			"text": "%s %s【%s】: %s" % [role_names.medium, m2.name, m2.trait.label, m2.trait.text]})
	else:
		facts.append({"id": "lack.medium", "text": "没有媒介部件:难以承载需持续供能的复杂效果"})
	# 工艺里程碑
	if int(craft.purity) >= 85:
		facts.append({"id": "craft.purity.good", "text": "纯净度 %d:炉火干净" % int(craft.purity)})
	if int(craft.temper) >= 85:
		facts.append({"id": "craft.temper.good", "text": "热处理 %d:硬度优秀,破甲能力强" % int(craft.temper)})
	if int(craft.balance) >= 80:
		facts.append({"id": "craft.balance.good", "text": "平衡度 %d:重心稳定" % int(craft.balance)})
	# 淬火介质
	var q: Dictionary = QUENCH_MEDIA.get(str(c.get("quench", "water")), QUENCH_MEDIA["water"])
	facts.append({"id": q.trait.id, "text": q.trait.text})
	# 尺寸事实
	facts.append({"id": "size.length.%s" % ("long" if float(size.length) > 0.6 else "short" if float(size.length) < 0.4 else "mid"),
		"text": "长度 %s:影响射程与操控" % ("偏长" if float(size.length) > 0.6 else "偏短" if float(size.length) < 0.4 else "适中")})
	# 缺陷事实
	for d in defects:
		facts.append({"id": d.id, "text": "%s: %s" % [d.label, d.desc]})
	# 手法风格
	var style: String = str(c.get("style", "steady"))
	var style_fact: Dictionary = {
		"steady": {"id": "style.steady", "text": "稳健风格:选择保守,武器值得信任"},
		"daring": {"id": "style.daring", "text": "险峻风格:常在边缘下注,武器带着狠劲"},
		"cracksman": {"id": "style.cracksman", "text": "留痕风格:裂纹是实话,比完美更可信"},
	}.get(style, {"id": "style.steady", "text": "稳健风格:选择保守,武器值得信任"})
	facts.append(style_fact)
	return facts


static func _mat(id: String) -> Dictionary:
	return MATERIALS.get(id, MATERIALS["grey_iron"])


static func _avg(values: Array) -> float:
	var s := 0.0
	for v in values:
		s += float(v)
	return s / maxf(values.size(), 1.0)


## 规范化字符串(键序固定) -> SHA256
static func _canonical(parts: Dictionary, size: Dictionary, craft: Dictionary, defects: Array) -> String:
	var out := "parts:{"
	for role in ["action", "bearing", "control", "medium"]:
		out += "%s:%s;" % [role, str(parts.get(role, ""))]
	out += "}size:%.3f,%.3f,%.3f;craft:%d,%d,%d,%d;defects:" % [
		float(size.length), float(size.thickness), float(size.balance),
		int(craft.purity), int(craft.structure), int(craft.temper), int(craft.balance)]
	for d in defects:
		out += str(d.id) + ";"
	return out


static func _sha256_hex(s: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(s.to_utf8_buffer())
	var res := ctx.finish()
	var hex := ""
	for b in res:
		hex += "%02x" % b
	return hex
