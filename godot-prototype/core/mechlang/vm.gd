class_name MechLangVM
## MechLang 确定性解释器：执行校验后的 AST。
## 语义：事件驱动；局部作用域(for 变量) + 契约状态(跨事件持久)；每执行一个 AST 节点步数 +1，
## 超过 MAX_STEPS_PER_HANDLER 即熔断(记录 BREACH,不影响世界)；随机全部经宿主 RNG(确定性)。
## 注意：本类不引用任何 Godot 节点，可 headless 测试。

const Def := preload("res://core/mechlang/mechlang_def.gd")

var _ast: Dictionary = {}
var _host = null                 # MechLangHost 实例(测试用 DummyHost)
var _state: Dictionary = {}          # 契约状态(持久)
var _local: Dictionary = {}          # 局部(for 变量)
var _steps: int = 0
var _max_steps: int = 512            # 每次事件触发的语句级步数上限(契约 budget.steps 与硬上限取小)
var _breached: bool = false
var _stats: Dictionary = {}

const NUM_TYPE := {"num": TYPE_FLOAT, "bool": TYPE_BOOL, "str": TYPE_STRING}


func _init(ast: Dictionary, host) -> void:
	_ast = ast
	_host = host
	_steps = 0
	_breached = false
	_stats = {"steps": 0, "breached": false, "calls": {}}
	var budget: Dictionary = ast.get("budget", {})
	var budget_steps: int = int(budget.get("steps", Def.MAX_STEPS_PER_HANDLER))
	_max_steps = mini(budget_steps, Def.MAX_STEPS_PER_HANDLER)
	# 初始化契约状态
	for var_name in ast.get("state", {}):
		var decl: Dictionary = ast["state"][var_name]
		_state[var_name] = 0
		if decl.has("expr"):
			# 默认值必须在初始化时求值(仅数值常量,由 checker 保证)
			_state[var_name] = _eval(decl["expr"], {})


func get_state() -> Dictionary:
	return _state


## v0.3 契约特性(由战斗 sim 在判定链中读取)
func get_traits() -> Dictionary:
	return _ast.get("traits", {})


func get_stats() -> Dictionary:
	return _stats


## 运行一个事件。ctx 由 sim 传入：{event, tick, target, attacker, blocked_damage, ...}
## 返回 {triggered: bool, breached: bool, steps: int, calls: Dictionary}
func run_event(event: String, ctx: Dictionary) -> Dictionary:
	var result := {"triggered": false, "breached": false, "steps": 0, "calls": {}}
	for handler in _ast.get("handlers", []):
		if handler.get("event", "") != event:
			continue
		_steps = 0
		_breached = false
		_local = {}
		_exec(handler.get("body", []), ctx)
		result["triggered"] = true
		result["breached"] = _breached
		result["steps"] += _steps
		# 合并调用统计
		for f in _stats.get("calls", {}):
			var cur: int = result["calls"].get(f, 0)
			result["calls"][f] = cur + _stats["calls"][f]
		_stats["calls"] = {}
	return result


func reset_stats() -> void:
	_stats = {"steps": 0, "breached": false, "calls": {}}


## ---------------- 语句执行 ----------------

func _exec(stmts: Array, ctx: Dictionary) -> void:
	for stmt in stmts:
		if _breached:
			return
		_tick()
		var kind: String = stmt.get("kind", "")
		match kind:
			"call":
				var func_name: String = stmt.get("func", "")
				var args: Array = []
				for a in stmt.get("args", []):
					args.append(_eval(a, ctx))
				_do_action(func_name, args, ctx)
			"assign":
				var expr_val: Variant = _eval(stmt.get("expr", {}), ctx)
				var target: String = stmt.get("target", "")
				var op: String = stmt.get("op", "")
				if _local.has(target):
					match op:
						"=":
							_local[target] = expr_val
						"+=":
							_local[target] = _local[target] + expr_val
						"-=":
							_local[target] = _local[target] - expr_val
						"*=":
							_local[target] = _local[target] * expr_val
						"/=":
							_local[target] = _local[target] / expr_val
				elif _state.has(target):
					match op:
						"=":
							_state[target] = expr_val
						"+=":
							_state[target] = _state[target] + expr_val
						"-=":
							_state[target] = _state[target] - expr_val
						"*=":
							_state[target] = _state[target] * expr_val
						"/=":
							_state[target] = _state[target] / expr_val
				else:
					# 隐式局部变量(handler 内自动创建)
					match op:
						"=":
							_local[target] = expr_val
						"+=":
							_local[target] = _local[target] + expr_val
						"-=":
							_local[target] = _local[target] - expr_val
						"*=":
							_local[target] = _local[target] * expr_val
						"/=":
							_local[target] = _local[target] / expr_val
			"if":
				var c: Variant = _eval(stmt.get("cond", {}), ctx)
				if _coerce_bool(c):
					_exec(stmt.get("then", []), ctx)
				else:
					_exec(stmt.get("else", []), ctx)
			"for":
				var var_name: String = stmt.get("var", "")
				var range_val: Variant = _eval(stmt.get("range_expr", {"kind": "num", "value": stmt.get("range", 0)}), ctx)
				if typeof(range_val) == TYPE_ARRAY:
					# 集合迭代(实体/区域引用列表)
					for item in range_val:
						if _breached:
							return
						_local[var_name] = item
						_exec(stmt.get("body", []), ctx)
				else:
					var n: int = int(range_val) if range_val is float or range_val is int else 0
					for i in range(n):
						if _breached:
							return
						_local[var_name] = i
						_exec(stmt.get("body", []), ctx)
				_local.erase(var_name)
			"expr":
				_eval(stmt.get("expr", {}), ctx)


## ---------------- 表达式求值 ----------------

func _eval(expr: Dictionary, ctx: Dictionary) -> Variant:
	if _breached:
		return 0
	var kind: String = expr.get("kind", "")
	match kind:
		"num":
			return expr.get("value", 0)
		"str":
			return expr.get("value", "")
		"var":
			var name: String = expr.get("name", "")
			if _local.has(name):
				return _local[name]
			if _state.has(name):
				return _state[name]
			if ctx.has(name):
				return ctx[name]
			_breach("read unknown variable '%s'" % name)
			return 0
		"call_expr":
			var fname: String = expr.get("func", "")
			var args: Array = []
			for a in expr.get("args", []):
				args.append(_eval(a, ctx))
			if fname == "weapon_state":
				return _host.read_weapon_state(str(args[0])) if args.size() == 1 else null
			if fname == "count_entities":
				return _host.count_entities()
			if fname == "min":
				return mini(args[0], args[1]) if typeof(args[0]) == TYPE_INT and typeof(args[1]) == TYPE_INT else minf(args[0], args[1])
			if fname == "max":
				return maxi(args[0], args[1]) if typeof(args[0]) == TYPE_INT and typeof(args[1]) == TYPE_INT else maxf(args[0], args[1])
			if Def.is_ref_func(fname):
				# v0.2 生成型函数:执行并返回实体/区域引用
				return _host.action(fname, args, ctx)
			return _host.query(fname, args, ctx)
		"binop":
			var op: String = expr.get("op", "")
			var l: Variant = _eval(expr.get("l", {}), ctx)
			if op == "&&":
				return 1 if (_coerce_bool(l) and _coerce_bool(_eval(expr.get("r", {}), ctx))) else 0
			if op == "||":
				return 1 if (_coerce_bool(l) or _coerce_bool(_eval(expr.get("r", {}), ctx))) else 0
			var r: Variant = _eval(expr.get("r", {}), ctx)
			match op:
				"+":
					return l + r
				"-":
					return l - r
				"*":
					return l * r
				"/":
					return l / r if not _is_zero(r) else 0
				"%":
					return int(l) % int(r) if not _is_zero(r) else 0
				"<":
					return 1 if l < r else 0
				">":
					return 1 if l > r else 0
				"<=":
					return 1 if l <= r else 0
				">=":
					return 1 if l >= r else 0
				"==":
					return 1 if l == r else 0
				"!=":
					return 1 if l != r else 0
			_breach("unknown binop '%s'" % op)
			return 0
		"unop":
			var v: Variant = _eval(expr.get("e", {}), ctx)
			match expr.get("op", ""):
				"-":
					return -v
				"!":
					return 0 if _coerce_bool(v) else 1
	return 0


func _do_action(fname: String, args: Array, ctx: Dictionary) -> void:
	_stats.get("calls", {})[fname] = _stats.get("calls", {}).get(fname, 0) + 1
	if fname == "set_weapon_state":
		if args.size() == 2:
			_host.write_weapon_state(str(args[0]), args[1])
		return
	_host.action(fname, args, ctx)


func _coerce_bool(v: Variant) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return v != 0
	return v != null and v != ""


func _is_zero(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT and v == 0) or (typeof(v) == TYPE_FLOAT and v == 0.0)


## ---------------- 预算与熔断 ----------------

func _tick() -> void:
	_steps += 1
	if _steps > _max_steps:
		_breach("step budget exceeded (%d > %d)" % [_steps, _max_steps])


func _breach(reason: String) -> void:
	if not _breached:
		_stats["breached"] = true
		_stats["breach_reason"] = reason
	_breached = true
