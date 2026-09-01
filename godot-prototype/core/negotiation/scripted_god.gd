class_name ScriptedGod
## 脚本假神 v1: 关键词 -> 意图 -> 依据检查 -> 四类回应(QUESTION/COUNTEROFFER/PROPOSE/REFUSE)。
## 设计依据: 05/04 验证协议的 DivintTurn 结构;云端 AI 神 = 后续升级(AiProvider 同构输出)。
## 与 weapons.json 验证集相同字段: speech/cited_fact_ids/missing/refuse_reason/draft。

## 意图 -> (支持关键词, 需事实文本包含的词)
const INTENTS := {
	"summon":   {"name": "召唤", "need": ["灵体", "星辉", "召唤", "小精灵", "召出", "随从"]},
	"lightning": {"name": "雷", "need": ["雷", "电", "电弧", "雷霆"]},
	"freeze":    {"name": "冰", "need": ["霜钢", "寒凝", "冻结", "冰缓", "寒气", "冻住", "冰"]},
	"store":     {"name": "储能", "need": ["回振", "储蓄", "保留", "存起来", "格挡", "释放", "存", "蓄", "攒"]},
	"mark":      {"name": "标记", "need": ["标记", "印记", "标示", "猎"]},
	"repair":    {"name": "修复", "need": ["耐修", "恢复", "维修", "修复"]},
	"grow":      {"name": "击杀成长", "need": ["饥性", "击杀", "猎杀", "杀得越多"]},
	"fire":      {"name": "火", "need": ["星火", "火种", "灼热", "熔岩", "火海", "火", "烧", "燃"]},
	"slam":      {"name": "重击爆发", "need": ["破甲", "冲击", "硬度", "重击", "震", "爆发"]},
	"leech":     {"name": "汲取", "need": ["饥性", "吸血", "汲取", "吸走", "回血", "治疗"]},
}

## 意图优先级(同长度命中时,元素类优先)
const INTENT_PRIORITY := {"lightning": 1, "freeze": 2, "fire": 3}

## 意图 -> MechLang 模板占位(scale 由纯度/结构注入)
const TEMPLATES := {
	"summon": """
device 星火之约 {
  budget: { entities: 2, steps: 24, cooldown: 300 }
  state: { hits: 0 }
  on hit {
    hits += 1
    if hits >= 3 {
      spawn_sprite(2, 160, 24)
      damage_weapon({cost})
      hits = 0
    }
  }
}
""",
	"store": """
device 回锋之蓄 {
  budget: { steps: 16, cooldown: 120 }
  state: { charge: 0 }
  on block {
    charge = min(charge + blocked_damage * 0.2, 8)
  }
  on heavy_blow {
    if charge >= 8 {
      damage(target, "impact", {dmg})
      charge = 0
    }
  }
}
""",
	"mark": """
device 猎手之印 {
  budget: { steps: 16, cooldown: 60 }
  on hit {
    set_mark(target)
  }
  on heavy_blow {
    if mark_count(target) > 0 {
      damage(target, "physical", {dmg})
    }
  }
}
""",
	"freeze": """
device 冰封之触 {
  budget: { steps: 16, cooldown: 60 }
  on hit {
    damage(target, "cryo", {dmg})
    apply_status(target, "frozen", 30)
  }
}
""",
	"lightning": """
device 雷霆之引 {
  budget: { steps: 16, cooldown: 120 }
  on heavy_blow {
    consume_offering(1)
    damage(nearest_enemy(target), "lightning", {dmg})
    apply_status(nearest_enemy(target), "stunned", 10)
  }
}
""",
	"repair": """
device 生铁之心 {
  budget: { steps: 8, cooldown: 0 }
  on kill {
    heal_weapon({dmg})
  }
}
""",
	"grow": """
device 猎杀者 {
  budget: { steps: 16, cooldown: 30 }
  state: { slays: 0 }
  on kill {
    slays = min(slays + 1, 5)
  }
  on hit {
    damage(target, "physical", 6 + slays)
  }
}
""",
	"slam": """
device 崩山之重 {
  budget: { steps: 16, cooldown: 120 }
  on heavy_blow {
    damage(target, "impact", {dmg})
    reduce_armor(target, 15)
    damage_weapon({cost})
  }
}
""",
	"leech": """
device 血气之引 {
  budget: { steps: 12, cooldown: 0 }
  on hit {
    heal_self({dmg})
  }
}
""",
	"fire": """
device 余火之袭 {
  budget: { steps: 16, cooldown: 90 }
  on hit {
    damage(target, "fire", {dmg})
    apply_status(target, "burning", 40)
  }
}
""",
}


## 一次交涉判定: weapon_facts(ForgeCore.build 输出), application(玩家申请)
## 返回 DivineTurn: {stance, speech, cited_fact_ids, missing, refuse_reason, draft}
static func adjudicate(weapon: Dictionary, application: String) -> Dictionary:
	var facts: Array = weapon.get("facts", [])
	var facts_text := ""
	var fact_ids: Array = []
	for f in facts:
		facts_text += " " + str(f.text)
		fact_ids.append(str(f.id))
	# 1) 意图识别(最长命中词优先;同长度时元素意图优先)
	var intent := ""
	var best_len := 0
	for key in INTENTS.keys():
		for w in INTENTS[key].need:
			var wlen := str(w).length()
			if application.contains(str(w)):
				if wlen > best_len or (wlen == best_len and _prio(key) < _prio(intent)):
					intent = key
					best_len = wlen
	if intent.is_empty():
		# 未识别意图 -> QUESTION(请玩家明确方向,而非默认批准)
		return {
			"stance": "QUESTION",
			"speech": "言语恳切,但神意不明。你想要的,是召唤、雷霆、冰封,还是复仇之重?",
			"cited_fact_ids": fact_ids.slice(0, 2),
			"missing": "未识别申请核心意图(召唤/雷/冰/储能/标记/修复/成长/重击/汲取)",
			"draft": "",
		}
	# 2) 依据检查: 武器事实文本是否支持该意图
	var supported := _contains_any(facts_text, _support_words(intent))
	var cited: Array = []
	for f in facts:
		if _contains_any(str(f.text), INTENTS[intent].need):
			cited.append(str(f.id))
	if cited.is_empty() and fact_ids.size() > 0:
		cited = fact_ids.slice(0, 1)
	# 3) 分级
	var purity := int(weapon.get("craft", {}).get("purity", 70))
	var structure := int(weapon.get("craft", {}).get("structure", 70))
	var dmg := 6 + int(purity / 25.0)
	var cost := 2 + int((100 - structure) / 30.0)
	if supported and intent != "lightning":
		return _propose(intent, dmg, cost, cited, purity)
	# 雷电特判: 有导流但无雷源 -> 供物补足的讨价
	if intent == "lightning":
		if _contains_any(facts_text, ["雷源", "雷木", "雷鸣", "雷矿"]):
			return _propose("lightning", dmg, cost, cited, purity)
		if _contains_any(facts_text, ["传导", "导流"]):
			return _counteroffer_lightning(dmg, cited)
		return _refuse("lightning", facts, cited)
	return _refuse(intent, facts, cited)


## 意图优先级(小者优先,用于同长度命中平局)
static func _prio(intent: String) -> int:
	return INTENT_PRIORITY.get(intent, 4)


## 意图的"支持词"(在 weapon facts 文本中找)
static func _support_words(intent: String) -> Array:
	var map := {
		"summon": ["灵体", "星辉", "灵亲和"],
		"lightning": ["雷源", "雷木", "雷鸣", "雷矿", "传导", "导流"],
		"freeze": ["霜钢", "寒凝", "冰缓", "寒气"],
		"store": ["回振", "储蓄", "保留"],
		"mark": ["标记", "感应", "印记"],
		"repair": ["耐修", "维修", "恢复"],
		"grow": ["饥性", "击杀"],
		"fire": ["星火", "火种", "灼热", "熔岩", "火海"],
		"slam": ["破甲", "冲击", "硬度"],
		"leech": ["饥性", "吸血", "生机"],
	}
	return map.get(intent, [])


static func _propose(intent: String, dmg: int, cost: int, cited: Array, purity: int) -> Dictionary:
	var tpl: String = TEMPLATES.get(intent, "")
	if tpl.is_empty():
		return _refuse(intent, [], cited)
	var draft := tpl.replace("{dmg}", str(dmg)).replace("{cost}", str(cost))
	return {
		"stance": "PROPOSE",
		"speech": "愿望与器物相符。此约可行——但记住,神恩有价。",
		"cited_fact_ids": cited,
		"missing": "",
		"refuse_reason": "",
		"draft": draft,
	}


static func _counteroffer_lightning(dmg: int, cited: Array) -> Dictionary:
	var tpl: String = TEMPLATES["lightning"]
	var draft := tpl.replace("{dmg}", str(dmg)).replace("{cost}", "1")
	return {
		"stance": "COUNTEROFFER",
		"speech": "你的锤导得走雷霆,却没有雷霆的来源。以一份供物为引,我可以借你一瞬——只借一瞬。",
		"cited_fact_ids": cited,
		"missing": "缺雷源:需要供物或雷木媒介",
		"refuse_reason": "",
		"draft": draft,
	}


static func _refuse(intent: String, facts: Array, cited: Array) -> Dictionary:
	var missing_desc: String = {
		"summon": "缺少灵体亲和材料(如银木/星辉矿)",
		"lightning": "缺少雷源与导流媒介(赤铜之外还需雷木/雷鸣矿或供物)",
		"freeze": "缺少寒性材料(如霜钢)",
		"store": "缺少回振/储蓄特性材料(如黑木)",
		"mark": "缺少标记/感应特性材料(如银木/兽筋)",
		"repair": "缺少耐修特性材料(如熟铁)",
		"grow": "缺少饥性材料(如魔兽骨)",
		"fire": "缺少火性材料(如熔岩晶/陨铁星火)",
		"slam": "缺少足够硬度与冲击结构(如陨铁/重锤结构)",
		"leech": "缺少汲取生机材料(如魔兽骨)",
	}.get(intent, "缺少对应依据的材料与工艺")
	return {
		"stance": "REFUSE",
		"speech": "此愿无凭。若强行降下神意,只会毁了这把器,也毁了你的手。",
		"cited_fact_ids": cited,
		"missing": "",
		"refuse_reason": missing_desc + ";补强路径:更换部件材料或完成一次祭仪",
		"draft": "",
	}


static func _contains_any(text: String, words: Array) -> bool:
	for w in words:
		if str(w).is_empty():
			continue
		if text.contains(str(w)):
			return true
	return false
