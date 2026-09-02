## ContractExplainer: MechLang 契约源码 -> 本地化技能说明文字(玩家不再看到代码)。
## 说明由 AST 静态生成(与校验同一通道);数值自动换算(tick -> 秒)。

extends RefCounted

const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")

const EVENT_NAMES := {
	"hit": "命中敌人时", "block": "格挡时", "heavy_blow": "重击时", "hurt": "受到伤害时",
	"kill": "击杀敌人时", "right_click": "主动技·右键释放", "timer": "每 5 秒",
	"attack": "发起攻击时", "projectile_hit": "弹道命中时", "healed": "受到治疗时",
	"overload": "过载(第二形态)时", "entity_removed": "友军消失时",
}
const STATUS_NAMES := {
	"stunned": "眩晕", "rooted": "定身", "floating": "浮空", "paralyzed": "麻痹",
	"slowed": "减速", "haste": "急速", "weakened": "虚弱", "enraged": "狂怒",
	"burning": "灼烧", "poisoned": "中毒", "bleeding": "流血", "silenced": "缄默",
	"disarmed": "缴械", "feared": "恐惧", "taunted": "嘲讽", "frozen": "冻结",
	"weak_point": "弱点", "corrupted": "腐蚀", "withering": "枯萎",
}
const DAMAGE_NAMES := {
	"physical": "物理", "impact": "冲击", "fire": "火焰", "lightning": "雷电",
	"radiant": "神圣", "cryo": "冰霜", "electro": "雷元素", "anemo": "风元素",
	"pyro": "火元素", "void": "虚空", "tidal": "潮汐", "thorns": "荆棘",
	"dark": "暗影", "true": "真实", "beam": "光束", "fire_dot": "灼烧",
}


## 生成说明行(数组;每行一句)。解析/校验失败时返回含错误提示的说明。
static func explain(src: String) -> Array:
	var parsed := Parser.new().parse(src)
	if not parsed.ok:
		return ["(契约无法解析: %s)" % "、".join(parsed.errors)]
	var checked := Checker.new().check(parsed.ast)
	if not checked.ok:
		return ["(契约格式不妥: %s)" % "、".join(checked.errors)]
	var lines: Array = []
	var ast: Dictionary = parsed.ast
	var full := str(ast.get("name", ""))
	if full != "":
		lines.append("✦ %s" % full)
	for h in ast.get("handlers", []):
		lines.append("【%s】" % EVENT_NAMES.get(str(h.event), str(h.event)))
		_explain_block(h.body, lines, [])
	return lines


static func _explain_block(stmts: Array, lines: Array, for_vars: Array) -> void:
	for stmt in stmts:
		var kind: String = str(stmt.get("kind", ""))
		match kind:
			"call":
				lines.append("· " + _action_text(str(stmt.get("func", "")), stmt.get("args", []), for_vars))
			"if":
				var cond_txt := _expr_text(stmt.get("cond", {}), for_vars)
				lines.append("· 当 %s:" % cond_txt)
				_explain_block(stmt.get("then", []), lines, for_vars)
				var else_stmts: Array = stmt.get("else", [])
				if else_stmts.size() > 0:
					lines.append("· 否则:")
					_explain_block(else_stmts, lines, for_vars)
			"for":
				var src_txt := _loop_src_text(stmt.get("range_expr", {}), stmt.get("range", 0))
				var vars := for_vars.duplicate()
				vars.append(str(stmt.get("var", "")))
				lines.append("· 对%s:" % src_txt)
				_explain_block(stmt.get("body", []), lines, vars)
			"assign":
				# 状态记账类(如 charges -= 1)不出现在说明;赋值资源类简示
				pass
			_:
				pass


static func _loop_src_text(range_expr: Dictionary, range_val: int) -> String:
	if range_expr.is_empty():
		return "每个(重复 %d 次)" % int(range_val)
	var fname := str(range_expr.get("func", ""))
	match fname:
		"units_in_range":
			return "半径 %s 内的每个目标" % _num_sense(range_expr.get("args", []))
		"enemies_in_range":
			return "半径 %s 内的每个敌人" % _num_sense(range_expr.get("args", []))
		"scorched_units":
			return "灼烧地面上的每个敌人"
		"all_enemies":
			return "战场上的每个敌人"
		_:
			return "每个目标"


static func _num_sense(args: Array) -> String:
	return _expr_text(args[0] if args.size() > 0 else {"kind": "num", "value": 2}, [])


static func _action_text(name: String, args: Array, for_vars: Array) -> String:
	var arg := func(i: int) -> String:
		return _expr_text(args[i] if i < args.size() else {"kind": "num", "value": 0}, for_vars)
	match name:
		"apply_status":
			return "使%s%s" % [arg.call(0), _status_dur(str(args[1].get("value", "")) if args.size() > 1 else "",
				_expr_n(args[2] if args.size() > 2 else {}).f)]
		"damage":
			return "对%s造成 %d 点%s伤害" % [arg.call(0), int(_expr_n(args[2] if args.size() > 2 else {}).f),
				DAMAGE_NAMES.get(str(args[1].get("value", "")), str(args[1].get("value", "")))]
		"damage_weapon":
			return "消耗 %d 点耐久" % int(_expr_n(args[0] if args.size() > 0 else {}).f)
		"heal_weapon":
			return "修复 %d 点耐久" % int(_expr_n(args[0] if args.size() > 0 else {}).f)
		"heal":
			return "治疗%s(%s)" % [arg.call(0), arg.call(1)]
		"heal_self":
			return "回复自身 %s" % arg.call(0)
		"damage_self":
			return "自损 %s" % arg.call(0)
		"scorch":
			return "点燃目标所在格子 %d 秒(灼烧地面)" % int(_expr_n(args[0] if args.size() > 0 else {}).f / 20.0)
		"empower":
			return "接下来 %d 次攻击攻速提升 %.1f 倍" % [
				int(_expr_n(args[0] if args.size() > 0 else {}).f),
				_expr_n(args[1] if args.size() > 1 else {}).f]
		"knockback":
			return "击退%s %d 格" % [arg.call(0), int(_expr_n(args[1] if args.size() > 1 else {}).f)]
		"reduce_armor":
			return "削减%s %d 点护甲" % [arg.call(0), int(_expr_n(args[1] if args.size() > 1 else {}).f)]
		"set_mark":
			return "标记%s" % arg.call(0)
		"clear_mark":
			return "清除%s的标记" % arg.call(0)
		"spawn_sprite":
			return "召唤 %d 只伴灵(存活 %d 刻,环绕)" % [int(_expr_n(args[0] if args.size() > 0 else {}).f),
				int(_expr_n(args[1] if args.size() > 1 else {}).f)]
		"spawn_projectile":
			return "发射弹道(速度 %s,追踪=%s)" % [arg.call(0), "是" if _expr_n(args[1] if args.size() > 1 else {}).f >= 1.0 else "否"]
		"create_zone":
			return "生成持续 %d 秒的地面区域" % int(_expr_n(args[1] if args.size() > 1 else {}).f / 20.0)
		"spawn_beam":
			return "发射持续光束(%d 秒)" % int(_expr_n(args[0] if args.size() > 0 else {}).f / 20.0)
		"create_wall":
			return "竖起风墙(长 %s,持续 %d 秒)" % [arg.call(0), int(_expr_n(args[1] if args.size() > 1 else {}).f / 20.0)]
		"dash":
			return "向目标突进 %d 格" % int(_expr_n(args[0] if args.size() > 0 else {}).f)
		"consume_offering":
			return "消耗 %d 份祭品" % int(_expr_n(args[0] if args.size() > 0 else {}).f)
		"set_weapon_state":
			return "记录武器状态(%s)" % arg.call(0)
		"destroy_entity":
			return "摧毁%s" % arg.call(0)
		_:
			return "%s(...)" % name


static func _status_dur(sid: String, ticks: float) -> String:
	var name: String = STATUS_NAMES.get(sid, sid)
	var secs := ticks / 20.0
	return "%s %s" % [name, ("%.1f 秒" % secs) if secs != int(secs) else ("%d 秒" % int(secs))]


## 表达式 -> 人话
static func _expr_text(e: Dictionary, for_vars: Array) -> String:
	var kind: String = str(e.get("kind", ""))
	match kind:
		"num":
			var f := float(e.get("value", 0.0))
			return str(int(f)) if f == int(f) else ("%.1f" % f)
		"str":
			return str(e.get("value", ""))
		"var":
			var name := str(e.get("name", ""))
			if name in for_vars:
				return "范围内目标"
			match name:
				"target": return "目标"
				"self": return "自己"
				"attack_damage": return "本次伤害"
				"hurt_damage": return "所受伤害"
				"blocked_damage": return "格挡伤害"
				"nearest_ally": return "最近队友"
				_:
					return name
		"call_expr":
			var fname := str(e.get("func", ""))
			if fname == "nearest_ally":
				return "最近的队友"
			if fname == "nearest_enemy":
				return "最近的敌人"
			return "%s(...)" % fname
		"binop":
			var l := _expr_text(e.get("l", {}), for_vars)
			var r := _expr_text(e.get("r", {}), for_vars)
			var op := str(e.get("op", ""))
			if op == "*":
				if l == "0.5":
					return "%s的一半" % r
				if r == "0.5":
					return "%s的一半" % l
			var op_zh: String = {"+": "加", "-": "减", "*": "乘", "/": "除", "&&": "并且", "||": "或者",
				"==": "等于", "!=": "不等于", ">": "大于", "<": "小于", ">=": "不小于", "<=": "不大于"}.get(op, op)
			return "%s %s %s" % [l, op_zh, r]
		_:
			return ""


## 数值求出(仅静态可求: num 或一元)
static func _expr_n(e: Dictionary) -> Dictionary:
	var kind := str(e.get("kind", ""))
	if kind == "num":
		return {"f": float(e.get("value", 0.0))}
	return {"f": 0.0}
