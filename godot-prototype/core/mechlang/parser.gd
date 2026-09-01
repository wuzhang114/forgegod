class_name MechLangParser
## MechLang 递归下降解析器：Token 流 → AST（Dictionary）。
## 语法为 C 风格大括号 + 换行/分号分隔；错误累积，不抛异常。

const T := {
	"WORD": "WORD", "INT": "INT", "FLOAT": "FLOAT", "STRING": "STRING",
	"SYMBOL": "SYMBOL", "NEWLINE": "NEWLINE", "EOF": "EOF",
}

const Def := preload("res://core/mechlang/mechlang_def.gd")
const Lexer := preload("res://core/mechlang/lexer.gd")

var _toks: Array = []
var _pos: int = 0
var _errors: Array = []


## 入口：返回 {ok, ast, errors}
func parse(src: String) -> Dictionary:
	var lexer = Lexer.new()
	_toks = lexer.tokenize(src)
	_pos = 0
	_errors = []
	var ast := _parse_program()
	var result := {"ok": _errors.is_empty(), "ast": ast if _errors.is_empty() else {}, "errors": _errors}
	return result


func _parse_program() -> Dictionary:
	_skip_newlines()
	_expect_word("device")
	var name_tok := _peek()
	var name: String = ""
	if name_tok.type == T.WORD and not Def.is_keyword(name_tok.value):
		name = name_tok.value
		_next()
	else:
		_error("expected device name", name_tok)
		return {}
	var prog := {"kind": "program", "name": name, "auth": "item", "budget": {},
		"state": {}, "traits": {}, "handlers": []}
	_expect_symbol("{")
	_skip_newlines()
	while not _at_symbol("}") and not _at("EOF"):
		# C 风格兼容: 顶层段之间允许分号(模型生成的自然写法)
		_consume_semicolon_opt()
		if _at_symbol("}"):
			break
		if _at_word("auth"):
			var auth := _parse_auth()
			_consume_semicolon_opt()
			if not auth.is_empty():
				prog.auth = auth
			continue
		if _at_word("budget"):
			var budget := _parse_budget()
			_consume_semicolon_opt()
			if not budget.is_empty():
				prog.budget = budget
			continue
		if _at_word("state"):
			var state := _parse_state()
			_consume_semicolon_opt()
			if not state.is_empty():
				prog.state = state
			continue
		if _at_word("traits"):
			var traits := _parse_traits()
			_consume_semicolon_opt()
			if not traits.is_empty():
				prog.traits = traits
			continue
		if _at_word("on"):
			var handler := _parse_handler()
			_consume_semicolon_opt()
			if not handler.is_empty():
				prog.handlers.append(handler)
			continue
		var tok := _peek()
		_error("unexpected token '%s' in device" % str(tok.value), tok)
		_next()
	_expect_symbol("}")
	_skip_until_eof()
	return prog


## C 风格兼容: 消费一个可选分号(段尾/语句分隔)
func _consume_semicolon_opt() -> void:
	if _at_symbol(";"):
		_next()
	_skip_newlines()


func _parse_auth() -> String:
	_next()  # auth
	_expect_symbol(":")
	var tok := _peek()
	if tok.type != T.WORD:
		_error("expected auth level", tok)
		_next()
		return ""
	_next()
	return tok.value


func _parse_budget() -> Dictionary:
	_next()  # budget
	_expect_symbol(":")
	_expect_symbol("{")
	var budget := {}
	while not _at_symbol("}") and not _at("EOF"):
		_skip_newlines()
		var key := _peek()
		if key.type != T.WORD:
			_error("expected budget key", key)
			_skip_until_symbol("}")
			break
		_next()
		_expect_symbol(":")
		var val := _peek()
		if val.type != T.INT:
			_error("expected integer budget value", val)
			_skip_until_symbol("}")
			break
		_next()
		budget[key.value] = val.value
		if not _at_symbol("}"):
			if _at_symbol(",") or _at_symbol(";"):
				_next()
			else:
				_skip_newlines()
	_expect_symbol("}")
	return budget


func _parse_state() -> Dictionary:
	_next()  # state
	_expect_symbol(":")
	_expect_symbol("{")
	var state := {}
	while not _at_symbol("}") and not _at("EOF"):
		_skip_newlines()
		var key := _peek()
		if key.type != T.WORD:
			_error("expected state variable name", key)
			_skip_until_symbol("}")
			break
		_next()
		_expect_symbol(":")
		var expr := _parse_expression()
		if expr.is_empty():
			_error("expected state default value", key)
			_skip_until_symbol("}")
			break
		state[key.value] = expr
		if not _at_symbol("}"):
			if _at_symbol(",") or _at_symbol(";"):
				_next()
			else:
				_skip_newlines()
	_expect_symbol("}")
	return state


func _parse_traits() -> Dictionary:
	_next()  # traits
	_expect_symbol(":")
	_expect_symbol("{")
	var traits := {}
	while not _at_symbol("}") and not _at("EOF"):
		_skip_newlines()
		var key := _peek()
		if key.type != T.WORD:
			_error("expected trait name", key)
			_skip_until_symbol("}")
			break
		_next()
		_expect_symbol(":")
		var tok := _peek()
		if tok.type == T.INT:
			traits[key.value] = {"kind": "num", "value": tok.value}
			_next()
		elif tok.type == T.FLOAT:
			traits[key.value] = {"kind": "num", "value": tok.value}
			_next()
		elif tok.type == T.WORD and (tok.value == "true" or tok.value == "false"):
			traits[key.value] = {"kind": "bool", "value": tok.value == "true"}
			_next()
		else:
			_error("trait value must be number or true/false", tok)
			_skip_until_symbol("}")
			break
		if not _at_symbol("}"):
			if _at_symbol(",") or _at_symbol(";"):
				_next()
			else:
				_skip_newlines()
	_expect_symbol("}")
	return traits


func _parse_handler() -> Dictionary:
	_next()  # on
	var ev := _peek()
	if ev.type != T.WORD or not Def.is_event(ev.value):
		_error("unknown event '%s'" % str(ev.value), ev)
		_next()
		return {}
	_next()
	var body := _parse_block()
	return {"kind": "handler", "event": ev.value, "body": body}


func _parse_block() -> Array:
	_expect_symbol("{")
	var stmts: Array = []
	_skip_newlines()
	while not _at_symbol("}") and not _at("EOF"):
		var stmt := _parse_stmt()
		if not stmt.is_empty():
			stmts.append(stmt)
		_skip_stmt_end()
		if _at_symbol("}"):
			break
	_expect_symbol("}")
	return stmts


func _parse_stmt() -> Dictionary:
	if _at_word("if"):
		return _parse_if()
	if _at_word("for"):
		return _parse_for()
	# 简单语句：赋值 / 函数调用 / 表达式
	var tok := _peek()
	if tok.type == T.WORD:
		var nxt := _peek_ahead(1)
		# 赋值: WORD assignop
		if nxt.type == T.SYMBOL and nxt.value in ["=", "+=", "-=", "*=", "/="]:
			return _parse_assign()
		# 调用: WORD "("
		if nxt.type == T.SYMBOL and nxt.value == "(":
			return _parse_call_stmt()
	# 单纯表达式
	var expr := _parse_expression()
	if expr.is_empty():
		_next()  # 跳过坏 token,避免死循环
		return {}
	return {"kind": "expr", "expr": expr}


func _parse_assign() -> Dictionary:
	var name = _next().value
	var op = _next().value
	var expr := _parse_expression()
	return {"kind": "assign", "target": name, "op": op, "expr": expr}


func _parse_call_stmt() -> Dictionary:
	var func_name = _next().value
	_expect_symbol("(")
	var args := _parse_args()
	return {"kind": "call", "func": func_name, "args": args}


func _parse_if() -> Dictionary:
	_next()  # if
	# C 风格兼容: if (cond) { ... }
	var cond := {}
	if _at_symbol("("):
		_next()
		cond = _parse_expression()
		_expect_symbol(")")
	else:
		cond = _parse_expression()
	var then_body := _parse_block()
	var else_body: Array = []
	if _at_word("else"):
		_next()
		if _at_word("if"):
			# else if 链: 作为嵌套 if 语句
			else_body = [_parse_if()]
		else:
			else_body = _parse_block()
	return {"kind": "if", "cond": cond, "then": then_body, "else": else_body}


func _parse_for() -> Dictionary:
	_next()  # for
	# C 风格兼容: for (i in 3) { ... }
	var has_paren := false
	if _at_symbol("("):
		has_paren = true
		_next()
	var var_tok := _peek()
	if var_tok.type != T.WORD:
		_error("expected loop variable", var_tok)
		return {}
	_next()
	_expect_word("in")
	# v0.2: 迭代源可以是整数常量(整数循环)或集合查询(集合迭代),语义由 checker 判定
	var range_expr := _parse_expression()
	if range_expr.is_empty():
		return {}
	if has_paren:
		_expect_symbol(")")
	var body := _parse_block()
	return {"kind": "for", "var": var_tok.value, "range_expr": range_expr,
		"range": range_expr.get("value", 0) if range_expr.get("kind", "") == "num" else 0,
		"body": body}


func _parse_args() -> Array:
	var args: Array = []
	_skip_newlines()
	if _at_symbol(")"):
		_next()
		return args
	while not _at_symbol(")") and not _at("EOF"):
		var expr := _parse_expression()
		if expr.is_empty():
			break
		args.append(expr)
		if _at_symbol(","):
			_next()
			_skip_newlines()
		else:
			break
	_expect_symbol(")")
	return args


func _parse_expression() -> Dictionary:
	return _parse_or()


func _parse_or() -> Dictionary:
	var l := _parse_and()
	while _at_symbol("||"):
		_next()
		var r := _parse_and()
		l = {"kind": "binop", "op": "||", "l": l, "r": r}
	return l


func _parse_and() -> Dictionary:
	var l := _parse_cmp()
	while _at_symbol("&&"):
		_next()
		var r := _parse_cmp()
		l = {"kind": "binop", "op": "&&", "l": l, "r": r}
	return l


func _parse_cmp() -> Dictionary:
	var l := _parse_add()
	while _at_symbol_any([">=", "<=", "==", "!=", ">", "<"]):
		var op = _next().value
		var r := _parse_add()
		l = {"kind": "binop", "op": op, "l": l, "r": r}
	return l


func _parse_add() -> Dictionary:
	var l := _parse_mul()
	while _at_symbol_any(["+", "-"]):
		var op = _next().value
		var r := _parse_mul()
		l = {"kind": "binop", "op": op, "l": l, "r": r}
	return l


func _parse_mul() -> Dictionary:
	var l := _parse_unary()
	while _at_symbol_any(["*", "/", "%"]):
		var op = _next().value
		var r := _parse_unary()
		l = {"kind": "binop", "op": op, "l": l, "r": r}
	return l


func _parse_unary() -> Dictionary:
	if _at_symbol("-") or _at_symbol("!"):
		var op = _next().value
		var e := _parse_unary()
		return {"kind": "unop", "op": op, "e": e}
	return _parse_primary()


func _parse_primary() -> Dictionary:
	var tok := _peek()
	if tok.type == T.INT:
		_next()
		return {"kind": "num", "value": tok.value, "is_int": true}
	if tok.type == T.FLOAT:
		_next()
		return {"kind": "num", "value": tok.value, "is_int": false}
	if tok.type == T.STRING:
		_next()
		return {"kind": "str", "value": tok.value}
	if tok.type == T.WORD:
		if tok.value == "true":
			_next()
			return {"kind": "num", "value": 1, "is_int": true}
		if tok.value == "false":
			_next()
			return {"kind": "num", "value": 0, "is_int": true}
		if Def.is_keyword(tok.value):
			_error("unexpected keyword '%s' in expression" % tok.value, tok)
			_next()
			return {}
		var nxt := _peek_ahead(1)
		if nxt.type == T.SYMBOL and nxt.value == "(":
			# 查询函数调用
			var func_name = tok.value
			_next()
			_next()  # (
			var args := _parse_args()
			return {"kind": "call_expr", "func": func_name, "args": args}
		_next()
		return {"kind": "var", "name": tok.value}
	if _at_symbol("("):
		_next()
		var e := _parse_expression()
		_expect_symbol(")")
		return e
	_error("unexpected token '%s' in expression" % str(tok.value), tok)
	return {}


## ---- 工具 ----

func _peek() -> Dictionary:
	return _toks[_pos]


func _peek_ahead(n: int) -> Dictionary:
	var i := _pos + n
	if i >= _toks.size():
		return _toks[_toks.size() - 1]
	return _toks[i]


func _next() -> Dictionary:
	var t = _toks[_pos]
	if _pos < _toks.size() - 1:
		_pos += 1
	return t


func _at(type: String) -> bool:
	return _peek().type == type


func _at_symbol(s: String) -> bool:
	return _peek().type == T.SYMBOL and _peek().value == s


func _at_symbol_any(syms: Array) -> bool:
	return _peek().type == T.SYMBOL and _peek().value in syms


func _at_word(w: String) -> bool:
	return _peek().type == T.WORD and _peek().value == w


func _expect_word(w: String) -> bool:
	if _at_word(w):
		_next()
		return true
	_error("expected '%s'" % w, _peek())
	return false


func _expect_symbol(s: String) -> bool:
	if _at_symbol(s):
		_next()
		return true
	_error("expected '%s'" % s, _peek())
	return false


func _skip_newlines() -> void:
	while _at(T.NEWLINE):
		_next()


func _skip_stmt_end() -> void:
	if _at(T.NEWLINE):
		_next()
	elif _at_symbol(";"):
		_next()
	_skip_newlines()


func _skip_until_symbol(s: String) -> void:
	while not _at("EOF") and not _at_symbol(s):
		_next()
	if _at_symbol(s):
		_next()


func _skip_until_eof() -> void:
	while not _at("EOF"):
		_next()


func _error(msg: String, tok: Dictionary) -> void:
	_errors.append({"code": "parse", "line": tok.get("line", 0), "detail": msg})
