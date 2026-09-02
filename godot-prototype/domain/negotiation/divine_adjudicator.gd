## DivineAdjudicator: 神前交涉适配器协议(接口 + 结构化 DivineTurn 定义与校验)。
## 实现: ScriptedGodAdapter(脚本神) / LocalAIAdapter / RemoteAIAdapter。
## 统一产出 {stance, speech, cited_fact_ids, missing, refuse_reason, draft}。

extends RefCounted

const STANCES := ["QUESTION", "COUNTEROFFER", "PROPOSE", "REFUSE"]
const TURN_KEYS := ["stance", "speech", "cited_fact_ids", "missing", "refuse_reason", "draft"]


## 子类实现: 依据武器事实档案裁决申请,返回结构化 DivineTurn
func adjudicate(_facts: Dictionary, _app: String) -> Dictionary:
	push_error("DivineAdjudicator: subclass must implement adjudicate()")
	return _empty_turn()


static func _empty_turn() -> Dictionary:
	return {"stance": "QUESTION", "speech": "", "cited_fact_ids": [], "missing": [],
		"refuse_reason": "", "draft": ""}


## 规范化: 缺失字段补默认(过载/第三方实现容错)
static func normalize(turn: Dictionary) -> Dictionary:
	var out := _empty_turn()
	for k in TURN_KEYS:
		if turn.has(k):
			out[k] = turn[k]
	return out


## 结构校验(防幻觉/畸形响应): stance 合法 + speech 非空 + draft 为字符串
static func validate(turn: Dictionary) -> bool:
	var t := normalize(turn)
	if not (str(t.stance) in STANCES):
		return false
	if str(t.speech).strip_edges().is_empty():
		return false
	if not (t.cited_fact_ids is Array or typeof(t.cited_fact_ids) == TYPE_NIL):
		return false
	if not (t.draft is String or typeof(t.draft) == TYPE_NIL):
		return false
	return true
