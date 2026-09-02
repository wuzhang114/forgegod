## 全局会话(跨场景): 锻造结果 -> 神前交涉 -> 契约 -> 战斗验证。
## 静态变量,任何场景可读写;不依赖 Node(纯 GDScript)。

class_name GameSession

static var weapon_facts: Dictionary = {}       # ForgeCore.build 结果
static var weapon_instance_id := ""            # 本轮武器实例 id(神裁定稿写回定位)
static var divine_turn: Dictionary = {}        # ScriptedGod.adjudicate 最近一轮
static var divine_contract: Dictionary = {}    # 定稿契约(校验通过): {source, readable}
static var negotiation_history: Array = []     # 对话记录 [{who, text, stance}]

static func reset() -> void:
	weapon_facts = {}
	weapon_instance_id = ""
	divine_turn = {}
	divine_contract = {}
	negotiation_history = []


## 定稿: 校验 draft 并存入契约
static func commit_contract(draft: String) -> Dictionary:
	if draft.strip_edges().is_empty():
		return {"ok": false, "error": "draft 为空"}
	var p := preload("res://core/mechlang/parser.gd").new()
	var parsed := p.parse(draft)
	if not parsed.ok:
		return {"ok": false, "error": str(parsed.errors)}
	var c := preload("res://core/mechlang/checker.gd").new()
	var checked := c.check(parsed.ast)
	if not checked.ok:
		return {"ok": false, "error": str(checked.errors)}
	divine_contract = {"source": draft, "ok": true, "weapon_id": weapon_facts.get("weapon_id", "")}
	return {"ok": true}
