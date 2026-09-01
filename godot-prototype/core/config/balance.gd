class_name Balance
## 唯一数值源(战斗数值轴线): 命中/暴击/护甲/增伤区/动作倍率/单位模板。
## 原则: 所有"数字"集中于此,业务代码只引用常量;修改数值只改这里 + 跑 tests(147 项守护)。
## 材料/锻造数值在 core/forge/forge_core.gd(forge 轴线);机械语言预算在 mechlang_def.gd。

## ---- 命中判定(02-battle-system-design.md §5) ----
const HIT := {"EVADE_FLOOR": 0.05, "EVADE_CEIL": 0.95}

## ---- 三档浮动(离散,可解释性优先) ----
## roll >= ROLL_HIGH -> 暴击(×HIGH);roll <= ROLL_LOW -> 刮痧(×LOW);其余普通(×1.0)
const CRIT := {"ROLL_HIGH": 0.85, "ROLL_LOW": 0.15, "HIGH": 1.5, "LOW": 0.7}

## ---- 六区伤害公式(核心) ----
## final = 基础攻击 × 动作倍率 × (1+增伤区,≤CAP) × 暴击档 × 防御区 × (1+独立乘区)
const DAMAGE := {
	"ARMOR_BASE": 100.0,      # 护甲对抗: 100/(100+护甲-破甲)
	"BONUS_CAP": 1.0,         # 增伤区上限 +100%(创作者定值)
	"INDEP_MAX": 2.0,         # 独立乘区上限(1+Σ来源,加算桶;含武器词条+目标易伤)
}

## ---- 动作倍率(02-battle-system-design.md §6.1) ----
const ACTION := {
	"basic": 1.0,
	"heavy_blow": 1.5,
	"combo": 0.6,
	"ranged": 1.0,
	"channel": 1.2,
	"block": 0.0,
}

## ---- 单位模板(勇者固定属性 + 敌人) ----
const HEROES := {
	"guard":   {"hp": 100.0, "atk": 10.0, "armor": 5.0, "hit": 0.9, "evade": 0.05, "range_hex": 1},
	"duelist": {"hp": 90.0,  "atk": 8.0,  "armor": 3.0, "hit": 0.92, "evade": 0.05, "range_hex": 1},
	"ranger":  {"hp": 80.0,  "atk": 11.0, "armor": 2.0, "hit": 0.95, "evade": 0.05, "range_hex": 4},
}

const ENEMIES := {
	"brute":   {"hp": 40.0, "atk": 4.0,  "armor": 3.0, "hit": 0.85, "evade": 0.02, "range_hex": 1, "move_interval": 14},
	"shooter": {"hp": 34.0, "atk": 6.0,  "armor": 2.0, "hit": 0.9,  "evade": 0.03, "range_hex": 4, "move_interval": 16},
	"purger":  {"hp": 50.0, "atk": 3.0,  "armor": 4.0, "hit": 0.88, "evade": 0.04, "range_hex": 2, "move_interval": 12},
}

## ---- 棋盘(02-battle-system-design.md §2/§7) ----
const BOARD := {"Q_MIN": 0, "Q_MAX": 7, "R_MIN": 0, "R_MAX": 4, "PLAYER_ZONE_R": 1}
const MOVE_INTERVAL := 12     # 每移动一格所需 tick(基准)
const TICK_DURATION := 0.05   # 20Hz


## ---- 状态调度(25 态表,02-battle-system-design.md §4;此处为战斗侧数值) ----
## 注: 行为类状态(控制/打断/索敌)的语义由 battle_sim/decide 接线,此处登记保证完整性;
##      数值类状态在此给出调度参数。
const STATUS := {
	# DoT(跳伤 / 间隔 / 层数上限)
	"burning":     {"dot": 2.0,  "interval": 20, "stacks_max": 3},
	"poisoned":    {"dot": 3.0,  "interval": 30, "stacks_max": 3},
	"bleeding":    {"dot": 2.0,  "interval": 25, "stacks_max": 3},
	"withering":   {"dot": 1.5,  "interval": 30, "stacks_max": 3, "heal_cut": 0.5},
	# 软控/增益(乘数)
	"slowed":      {"move_mult": 0.7, "frame_mult": 1.3},
	"haste":       {"move_mult": 1.15, "frame_mult": 0.85},
	"weakened":    {"atk_mult": 0.8},
	"enraged":     {"atk_mult": 1.2},
	"corrupted":   {"armor_mult": 0.7},
	"frozen":      {"fire_vuln": 0.25},
	"weak_point":  {"vuln": 0.10},
	# 硬控(打断/时长由 sim 接线;递减规则见设计文档)
	"stunned":     {"cc": true},
	"rooted":      {"cc": true},
	"floating":    {"cc": true},
	"paralyzed":   {"cc": true},
	# 行为类(索敌/动作限制由 sim 接线)
	"silenced":    {"behavior": true},
	"disarmed":    {"behavior": true},
	"feared":      {"behavior": true},
	"taunted":     {"behavior": true},
	"trapped":     {"behavior": true},
	"cursed":      {"behavior": true, "heal_cut": 0.5},
	"guarded":     {"consumable": true},
	"invisible":   {"behavior": true},
	"shield":      {"consumable": true},
	"mined":       {"consumable": true},
}


## ---- 便捷取值 ----
static func hero_tpl(role: String) -> Dictionary:
	return HEROES.get(role, HEROES["guard"])

static func enemy_tpl(kind: String) -> Dictionary:
	return ENEMIES.get(kind, ENEMIES["brute"])

static func action_mult(tag: String) -> float:
	return ACTION.get(tag, 1.0)

static func status_cfg(id: String) -> Dictionary:
	return STATUS.get(id, {})
