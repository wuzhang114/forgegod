class_name MechLangChecker
## MechLang 静态校验器：AST → 规范化结果。
## 校验：语法(parser 已做) / 函数白名单+元数 / for 上界 / 语句与展开预算 / 变量符号表 / 权限层。
## 返回 {ok, ast(规范化), budget(合并默认), errors:[{code,line,detail}]}

const T := {"WORD": "WORD", "INT": "INT", "FLOAT": "FLOAT", "STRING": "STRING",
	"SYMBOL": "SYMBOL", "NEWLINE": "NEWLINE", "EOF": "EOF"}

const Def := preload("res://core/mechlang/mechlang_def.gd")

var _errors: Array = []
var _env: Dictionary = {}   # 变量名 -> true（state vars + for vars）
var _func_ctx := ""         # 当前正在检查的 handler 事件


func check(ast: Dictionary, enforce_item_auth: bool = true) -> Dictionary:
	_errors = []
	if ast.is_empty() or ast.get("kind", "") != "program":
		_error("check", 0, "program AST 为空或损坏")
		return {"ok": false, "ast": ast, "budget": {}, "errors": _errors}
	# 1) 权限层
	var auth: String = ast.get("auth", "item")
	if auth not in Def.AUTH_LEVELS:
		_error("check", 0, "未知权限层 '%s'(允许: %s)" % [auth, str(Def.AUTH_LEVELS)])
	elif enforce_item_auth and auth != "item":
		_error("check", 0, "M1 沙盒仅允许 auth: item,收到 '%s'" % auth)
	# 2) 预算
	var budget: Dictionary = Def.DEFAULT_BUDGET.duplicate()
	var raw_budget: Dictionary = ast.get("budget", {})
	for key in ["entities", "steps", "cooldown"]:
		if raw_budget.has(key):
			var v: Variant = raw_budget[key]
			if typeof(v) != TYPE_INT or v < 0 or v > 100000:
				_error("check", 0, "预算 %s 必须为非负整数(≤100000),收到 %s" % [key, str(v)])
			else:
				budget[key] = v
	if int(budget.get("steps", 0)) < 1:
		_error("check", 0, "预算 steps 必须 ≥ 1")
	# 3) 状态
	var state: Dictionary = ast.get("state", {})
	_env = {}
	for var_name in state:
		if Def.is_keyword(var_name) or Def.is_action_func(var_name) \
				or Def.is_query_func(var_name):
			_error("check", 0, "状态变量 '%s' 与关键字/宿主函数重名" % var_name)
			continue
		var default: Dictionary = state[var_name]
		var t := _check_expr(default, true)
		if not t.is_empty() and t.get("type", "") != "num":
			_error("check", 0, "状态 '%s' 默认值必须是数值常量" % var_name)
		state[var_name] = {"expr": default, "type": "num"}
		_env[var_name] = true
	# 3.5) 特性 traits
	var traits: Dictionary = ast.get("traits", {})
	for tname in traits:
		if not Def.is_trait(tname):
			_error("check", 0, "未知契约特性 '%s'(允许: %s)" % [tname, str(Def.TRAITS.keys())])
			continue
		var tval: Dictionary = traits[tname]
		var expected: String = Def.trait_type(tname)
		if expected == "bool":
			if tval.get("kind", "") != "bool":
				_error("check", 0, "特性 %s 需要 true/false" % tname)
		elif expected == "float":
			if tval.get("kind", "") != "num":
				_error("check", 0, "特性 %s 需要数值" % tname)
			else:
				var fv: float = float(tval.get("value", 0))
				if fv < 1.0 or fv > 3.0:
					_error("check", 0, "特性 %s 数值超出 1.0..3.0" % tname)
	ast["traits"] = traits
	# 4) handlers
	var handlers: Array = ast.get("handlers", [])
	if handlers.is_empty():
		_error("check", 0, "至少需要一个 on 事件处理器")
	for handler in handlers:
		_func_ctx = handler.get("event", "?")
		var body: Array = handler.get("body", [])
		if body.size() > Def.MAX_HANDLER_STMTS:
			_error("check", 0, "handler %s 语句数 %d 超过上限 %d" % [_func_ctx, body.size(), Def.MAX_HANDLER_STMTS])
		var expanded := _static_expand(body)
		if expanded > Def.MAX_EXPANDED_STEPS:
			_error("check", 0, "handler %s 静态展开估计 %d 步,超过上限 %d" % [_func_ctx, expanded, Def.MAX_EXPANDED_STEPS])
		_check_statements(body)
	ast["budget"] = budget
	ast["handlers"] = handlers
	return {"ok": _errors.is_empty(), "ast": ast, "budget": budget, "errors": _errors}


## 静态展开估计: for 按迭代源估计展开 + 语句计数(集合迭代按实体预算上界保守估计)
func _static_expand(stmts: Array) -> int:
	var total := 0
	for s in stmts:
		if s.get("kind", "") == "for":
			var r = s.get("range_expr", {})
			var iter: int = int(s.get("range", 0))
			if r.get("kind", "") == "call_expr" and Def.is_collection_func(r.get("func", "")):
				iter = Def.MAX_COLLECTION_ITER
			total += maxi(iter, 1) * _static_expand(s.get("body", []))
		elif s.get("kind", "") == "if":
			total += 1 + _static_expand(s.get("then", [])) + _static_expand(s.get("else", []))
		else:
			total += 1
	return total


func _check_statements(stmts: Array) -> void:
	for stmt in stmts:
		var kind: String = stmt.get("kind", "")
		if kind == "call":
			var func_name: String = stmt.get("func", "")
			if not Def.is_action_func(func_name):
				_error("check", stmt.get("line", 0), "未知动作函数 '%s'" % func_name)
			else:
				var arity = Def.action_arity(func_name)
				var args: Array = stmt.get("args", [])
				if args.size() != arity:
					_error("check", stmt.get("line", 0), "动作函数 %s 需要 %d 个参数,收到 %d" % [func_name, arity, args.size()])
				for a in args:
					_check_expr(a, false)
		elif kind == "assign":
			var target: String = stmt.get("target", "")
			# 未声明的目标自动作为局部变量(handler 内可见,与 for 变量同级)
			if not _env.has(target) and not Def.is_keyword(target) \
					and not Def.is_action_func(target) and not Def.is_query_func(target) \
					and not Def.is_ref_func(target) and not Def.is_collection_func(target):
				_env[target] = true
			_check_expr(stmt.get("expr", {}), false)
		elif kind == "if":
			_check_expr(stmt.get("cond", {}), false)
			_check_statements(stmt.get("then", []))
			_check_statements(stmt.get("else", []))
		elif kind == "for":
			var var_name: String = stmt.get("var", "")
			if Def.is_keyword(var_name) or Def.is_action_func(var_name) \
					or Def.is_query_func(var_name) or Def.is_collection_func(var_name):
				_error("check", stmt.get("line", 0), "循环变量 '%s' 非法" % var_name)
			var range_expr: Dictionary = stmt.get("range_expr", {})
			var is_int_loop: bool = range_expr.get("kind", "") == "num"
			var is_col_loop: bool = range_expr.get("kind", "") == "call_expr" \
					and Def.is_collection_func(range_expr.get("func", ""))
			if not is_int_loop and not is_col_loop:
				_error("check", stmt.get("line", 0), "for 迭代源必须是整数常量(1..%d)或集合查询(%s)"
					% [Def.MAX_FOR_RANGE, str(Def.COLLECTION_FUNCS.keys())])
				return
			if is_int_loop:
				var range_val: int = int(range_expr.get("value", 0))
				if range_val < 1 or range_val > Def.MAX_FOR_RANGE:
					_error("check", stmt.get("line", 0), "for 循环上界 %d 超出 1..%d" % [range_val, Def.MAX_FOR_RANGE])
			else:
				var cname: String = range_expr.get("func", "")
				var arity = Def.collection_arity(cname)
				var cargs: Array = range_expr.get("args", [])
				if cargs.size() != arity:
					_error("check", stmt.get("line", 0), "集合查询 %s 需要 %d 个参数,收到 %d" % [cname, arity, cargs.size()])
				for a in cargs:
					_check_expr(a, false)
			_env[var_name] = true
			_check_statements(stmt.get("body", []))
			_env.erase(var_name)
		elif kind == "expr":
			_check_expr(stmt.get("expr", {}), false)
		else:
			_error("check", stmt.get("line", 0), "未知语句类型 '%s'" % kind)


## 返回 {type: "num"|"str"|"bool"} 或 {} (类型不合)
func _check_expr(expr: Dictionary, is_default: bool) -> Dictionary:
	var kind: String = expr.get("kind", "")
	if kind == "num":
		return {"type": "num"}
	if kind == "str":
		return {"type": "str"}
	if kind == "var":
		var name: String = expr.get("name", "")
		if not _env.has(name) and not (name in Def.CONTEXT_VARS):
			_error("check", 0, "未声明变量 '%s'(事件上下文内置: %s)" % [name, str(Def.CONTEXT_VARS)])
			return {}
		return {"type": "num"}
	if kind == "call_expr":
		var func_name: String = expr.get("func", "")
		# v0.2: 生成型函数(spawn_sprite/create_zone 等)也可出现在表达式位置,返回实体/区域引用
		var is_query := Def.is_query_func(func_name)
		var is_ref := Def.is_ref_func(func_name)
		if not is_query and not is_ref:
			_error("check", 0, "未知查询函数 '%s'(允许: 查询函数或生成型函数 %s)"
				% [func_name, str(Def.REF_FUNCS.keys())])
			return {"type": "num"}
		var arity = Def.query_arity(func_name) if is_query else Def.ref_arity(func_name)
		var args: Array = expr.get("args", [])
		if args.size() != arity:
			_error("check", 0, "函数 %s 需要 %d 个参数,收到 %d" % [func_name, arity, args.size()])
		for a in args:
			_check_expr(a, is_default)
		return {"type": "num"}
	if kind == "binop":
		var op: String = expr.get("op", "")
		var lt := _check_expr(expr.get("l", {}), is_default)
		var rt := _check_expr(expr.get("r", {}), is_default)
		if op in ["+", "-", "*", "/", "%"]:
			return {"type": "num"}
		if op in ["<", ">", "<=", ">=", "==", "!=", "&&", "||"]:
			return {"type": "bool"}
		_error("check", 0, "未知二元运算符 '%s'" % op)
		return {}
	if kind == "unop":
		_check_expr(expr.get("e", {}), is_default)
		return {"type": "num"}
	_error("check", 0, "未知表达式类型 '%s'" % kind)
	return {}


func _error(code: String, line: int, detail: String) -> void:
	_errors.append({"code": code, "line": line, "detail": detail})
