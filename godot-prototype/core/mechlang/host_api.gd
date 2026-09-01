class_name MechLangHost
## MechLang 宿主接口：VM 通过它访问游戏世界。
## 游戏侧(sim / 战斗 / 神裁幻境)实现本接口；VM 只认识白名单函数名。
## 宿主负责：确定性 RNG、实体上限、武器/队伍状态、事件上下文解释(target 等)。


## 查询函数（无副作用）返回值；args 已求值
func query(_name: String, _args: Array, _ctx: Dictionary) -> Variant:
	push_error("MechLangHost.query 未实现")
	return 0


## 动作函数（有副作用）；args 已求值。生成型函数(spawn_*/create_zone)应返回实体/区域引用，
## 其余动作返回 null。
func action(_name: String, _args: Array, _ctx: Dictionary) -> Variant:
	push_error("MechLangHost.action 未实现")
	return null


## 当前由该契约管理的实体数（VM 用它做实体预算检查）
func count_entities() -> int:
	return 0


## 事件冷却检查与登记（true = 允许触发）
func check_cooldown(_event: String, _now_tick: int) -> bool:
	return true


## 读取武器/队伍公开状态
func read_weapon_state(_key: String) -> Variant:
	return null


## 写入武器/队伍公开状态
func write_weapon_state(_key: String, _value: Variant) -> void:
	pass
