class_name MechLangDef
## MechLang 语言定义（v0.2）：关键字、事件、宿主函数白名单、预算常量。
## 语言设计目标：语法简单可解析、宿主函数白名单、可静态验证、无用户自定义函数（无递归入口）。
## v0.2 新增：集合查询(可迭代)、生成型函数返回值(实体/区域引用)、目标状态/标签/环境查询、
##          新事件(attack / projectile_hit / healed)与新上下文(hurt_damage / attack_damage)。

## ---- 关键字 ----
const KEYWORDS := {
	"device": true,
	"auth": true,
	"budget": true,
	"state": true,
	"on": true,
	"if": true,
	"else": true,
	"for": true,
	"in": true,
	"true": true,
	"false": true,
}

## ---- 权限层级（M1 只实现 item） ----
const AUTH_LEVELS := ["item", "squad", "world"]

## ---- 事件白名单（由 sim 订阅注册） ----
const EVENTS := [
	"hit", "block", "heavy_blow", "hurt", "kill",
	"right_click", "timer", "entity_removed",
	"attack",           # 持有者发起攻击（ctx: target, attack_damage）
	"projectile_hit",   # 本武器弹道命中（ctx: target）
	"healed",           # 持用者接受治疗（ctx: target=被治疗者）
	"overload",         # v0.4 玩家过载指令:触发契约第二形态(更强、代价更大)
]

## ---- 动作函数白名单（只能出现在语句位置，产生副作用） ----
const ACTION_FUNCS := {
	"damage": 3,            # (target, type, amount)
	"reduce_armor": 2,      # (target, amount)
	"knockback": 2,         # (target, power)
	"apply_status": 3,      # (target, status, ticks)
	"spawn_sprite": 3,      # (count, lifetime_ticks, orbit_px)
	"spawn_projectile": 2,  # (speed, homing)
	"create_zone": 4,       # (radius, lifetime_ticks, pull_power, delay_ticks)
	"damage_weapon": 1,     # (amount)
	"heal_weapon": 1,       # (amount)
	"set_mark": 1,          # (target)
	"clear_mark": 1,        # (target)
	"consume_offering": 1,  # (amount)
	"set_weapon_state": 2,  # (key, value)
	"destroy_entity": 1,    # (entity_ref)
	"dash": 1,              # (distance) v0.2.1 向目标方向位移自身(波浪形态/掘地穿刺)
	"damage_self": 1,       # (amount) v0.2.1 消耗持有者生命(胡桃血梅/血沸)
	"heal_self": 1,         # (amount) v0.2.1 治疗持有者(芭芭拉/战吼恢复)
	"spawn_beam": 2,        # (duration_ticks, damage) v0.2.1 沿攻击方向持续光束(太阳射线/终极闪光)
	"create_wall": 2,       # (length, lifetime) v0.2.1 阻挡敌方投射物的规则墙(亚索风墙)
	"scorch": 1,            # (lifetime) v0.5 当前攻击目标格点燃灼烧地面(灼烧之种)
	"heal": 2,              # (target, amount) v0.5 治疗一个友军(嗜血之舞)
	"empower": 2,           # (charge_count, speed_mult) v0.5 接下来 N 次攻击攻速提升(封顶×2)
}

## ---- 生成型函数（v0.2：可出现在表达式位置，返回实体/区域引用） ----
const REF_FUNCS := {
	"spawn_sprite": 3,      # -> 返回首个生成实体的引用
	"spawn_projectile": 2,  # -> 返回投射物引用
	"create_zone": 4,       # -> 返回区域引用
}

## ---- 查询函数白名单（只能出现在表达式位置，无副作用） ----
const QUERY_FUNCS := {
	"blocked_damage": 0,
	"target_hp_ratio": 1,       # (target)
	"hp_value": 1,              # (entity) -> 当前 HP，v0.2
	"has_status": 2,            # (entity, status_id) -> 0/1，v0.2
	"self_hp_ratio": 0,         # -> 持有者生命比例，v0.2
	"target_has_tag": 2,        # (entity, tag) -> 0/1，v0.2
	"world_flag": 1,            # (flag_id) -> 0/1，v0.2（夜晚/水域/城市等）
	"zone_is_active": 1,        # (zone_ref) -> 0/1，v0.2
	"mark_count": 1,            # (target)
	"weapon_stock": 0,
	"has_defect": 1,            # (defect_id)
	"nearest_enemy": 1,         # (target) -> 距离最近的其他敌人
	"distance": 2,              # (a, b)
	"rand_range": 2,            # (min, max) —— 确定性随机，RNG 由宿主注入
	"count_entities": 0,
	"weapon_state": 1,          # (key)
	"min": 2,                   # 纯数值函数(VM 内建)
	"max": 2,                   # 纯数值函数(VM 内建)
	"armor_value": 1,           # (target) v0.3 -> 目标护甲值
	"target_evade": 1,          # (target) v0.3 -> 目标闪避率 0-1
	"attack_value": 0,          # v0.3 -> 持有者本次攻击的基础攻击值
	"hit_chance": 1,            # (target) v0.3 -> 本击对目标的命中率 0-1
	"nearest_ally": 1,          # (entity) v0.5 -> 距离最近的友军(嗜血之舞)
}

## ---- 集合查询（v0.2：只能作为 for 的迭代源，返回实体/区域列表） ----
const COLLECTION_FUNCS := {
	"enemies_in_range": 1,      # (radius) -> 范围内敌人实体列表
	"all_enemies": 0,           # -> 战场全部敌人
	"units_in_range": 1,        # (radius) -> 范围内全部实体(不分阵营,主动 AOE 用, v0.5)
	"scorched_units": 0,        # v0.5 本武器灼烧格上的敌人(via weapon_state)
}

## ---- 事件上下文保留变量(handler 内可直接读取,由 sim 提供) ----
const CONTEXT_VARS := ["target", "attacker", "self", "blocked_damage", "hurt_damage", "attack_damage", "tick",
	"hit_landed",      # v0.3 本击是否命中(0/1, on attack/hit 事件)
	"hit_crit",        # v0.3 本次伤害档位倍率(暴击 1.5 / 普通 1.0 / 刮痧 0.7)
]

## ---- 契约特性(traits)白名单:由 sim 在判定链中读取 ----
## ignores_evade: bool 必中(无视目标闪避,仍可被格挡)
## guaranteed_hit: bool 必中且不可被格挡/闪避(锁定弹级)
## crit_mult: float 1.0-3.0 每次命中的暴击倍率(默认 1.5)
const TRAITS := {
	"ignores_evade": "bool",
	"guaranteed_hit": "bool",
	"crit_mult": "float",
}

static func is_trait(name: String) -> bool:
	return TRAITS.has(name)

static func trait_type(name: String) -> String:
	return TRAITS.get(name, "")

## ---- 预算限制 ----
const MAX_FOR_RANGE := 100          # for 整数循环上界（静态）
const MAX_COLLECTION_ITER := 32     # for 集合迭代的静态估计上界（按实体预算上限保守估计）
const MAX_HANDLER_STMTS := 50       # 每个 handler 直接语句数上限（静态）
const MAX_EXPANDED_STEPS := 1000    # 静态展开估计上限（嵌套 for 展开）
const MAX_STEPS_PER_HANDLER := 512  # VM 运行时单次 handler 步数上限（动态熔断）
const MAX_BLOCK_DEPTH := 16         # if/for 嵌套深度（parser 限制）

const DEFAULT_BUDGET := {"entities": 4, "steps": 64, "cooldown": 600}

static func is_keyword(word: String) -> bool:
	return KEYWORDS.has(word)

static func is_event(name: String) -> bool:
	return name in EVENTS

static func is_action_func(name: String) -> bool:
	return ACTION_FUNCS.has(name)

static func is_query_func(name: String) -> bool:
	return QUERY_FUNCS.has(name)

static func is_ref_func(name: String) -> bool:
	return REF_FUNCS.has(name)

static func is_collection_func(name: String) -> bool:
	return COLLECTION_FUNCS.has(name)

static func action_arity(name: String) -> int:
	return ACTION_FUNCS.get(name, -1)

static func query_arity(name: String) -> int:
	return QUERY_FUNCS.get(name, -1)

static func ref_arity(name: String) -> int:
	return REF_FUNCS.get(name, -1)

static func collection_arity(name: String) -> int:
	return COLLECTION_FUNCS.get(name, -1)
