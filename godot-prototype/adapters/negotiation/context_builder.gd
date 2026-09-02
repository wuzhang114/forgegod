## ContextBuilder: 神裁上下文预加载(系统提示 + 武器事实档案 + 判例库)。
## 在 API 保存/连接确认时调用一次并缓存;adjudicate 不再临时组包(避免首轮卡顿)。

extends RefCounted

const PROMPT_PATH := "res://tests/negotiation/PROMPT_god.md"
const MECH_DB_PATH := "res://data/mechanism-library.json"
const MAX_PRECEDENTS := 5


## 系统提示(协议;文件缺失时返回兜底文本)
static func system_prompt() -> String:
	var f := FileAccess.open(PROMPT_PATH, FileAccess.READ)
	if f == null:
		return "你是锻造之神。依据武器事实裁决玩家的机制申请;给出可编译契约草案或质询/驳回。"
	return f.get_as_text()


## 判例库条目(前 N 条 id/名称/幻想,取自 data/mechanism-library.json categories[].items[])
static func precedents() -> Array:
	var out: Array = []
	var f := FileAccess.open(MECH_DB_PATH, FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for cat in parsed.get("categories", []):
		for it in cat.get("items", []):
			out.append({"id": str(it.get("id", "")), "name": str(it.get("name", "")),
				"brief": str(it.get("fantasy", it.get("mechanism", ""))).left(140)})
			if out.size() >= MAX_PRECEDENTS:
				return out
	return out


## 武器事实 -> 档案文本
static func facts_text(facts: Dictionary) -> String:
	if facts.is_empty():
		return "(尚未锻造;可按通用原则裁决)"
	var craft: Dictionary = facts.get("craft", {})
	var lines := "%s(%s) 武器档案: 纯净 %d / 结构 %d / 热处理 %d / 平衡 %d" % [
		str(facts.get("name", "无名")), str(facts.get("kind_name", "武器")),
		int(craft.get("purity", 0)), int(craft.get("structure", 0)),
		int(craft.get("temper", 0)), int(craft.get("balance", 0))]
	for d in facts.get("defects", []):
		lines += "\n· 缺陷: %s(%s)" % [str(d.get("label", "")), str(d.get("desc", ""))]
	for fc in facts.get("facts", []):
		lines += "\n· %s" % str(fc.get("text", ""))
	return lines


## 构建上下文(messages;调用一次,结果缓存进 AI 适配器)
static func build_messages(facts: Dictionary) -> Array:
	var sys := system_prompt()
	var user := facts_text(facts)
	if not precedents().is_empty():
		var p : Array = []
		for it in precedents():
			p.append("%s(%s): %s" % [str(it.name), str(it.id), str(it.brief)])
		user += "\n\n参考判例:\n" + "\n".join(p)
	return [{"role": "system", "content": sys}, {"role": "user", "content": user}]
