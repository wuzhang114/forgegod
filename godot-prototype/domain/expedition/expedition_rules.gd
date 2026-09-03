## ExpeditionRules: 出征规则(敌人按层缩放 / 敌群包选择 / 节点效果 / 事件池)。
## 纯逻辑,可单测;数据都在 RunState.expedition。
## 注意: 不使用 class_name(headless -s 下不可用);由调用方 preload。

extends RefCounted

## 敌群包: 层数越深越强;精英/首领用独立包(在 EnemyPacks 定义)
static func pack_for(floor_num: int, node_type: String) -> String:
	if node_type == "boss":
		return "boss_golem"
	if node_type == "elite":
		return "elite_golem"
	return "golems" if floor_num <= 2 else "mixed"


## 层数缩放: 第 1 层 = 基准,之后每层 +12% HP / +10% 攻击("每一层都变强一点点")
static func scale_for_floor(floor_num: int) -> Dictionary:
	var t := float(maxi(floor_num, 1) - 1)
	return {"hp": 1.0 + t * 0.12, "atk": 1.0 + t * 0.10}


## 战斗胜利奖励(逐层递增;Boss 另有结算)
static func reward_for_win(floor_num: int) -> Dictionary:
	return {"money": 12.0 + 6.0 * float(maxi(floor_num, 1)), "reputation": 1.0 + 0.5 * float(maxi(floor_num, 1))}


## 宝箱收益(确定性: 层数影响金币;偶数层多一块水晶)
static func reward_for_treasure(floor_num: int) -> Dictionary:
	var out := {"money": 18.0 + 4.0 * float(maxi(floor_num, 1)), "reputation": 0.0,
		"grant": {"iron_ore": 1}}
	if (floor_num % 2) == 0:
		out.grant["charm_crystal"] = 1
	return out


## 篝火增益(玩家二选一)
static func rest_option_fix(weapons: Array) -> Dictionary:
	return {"durability": 25.0}


## 战斗归来解析: 状态推进 + 奖励(纯逻辑,UI 只展示)。
## 返回 {ok, type: "won"/"lost"/"victory"/"none", text, money, reputation, floor}
static func resolve_battle(run, result: String, node_id: String, map_data: Dictionary) -> Dictionary:
	var Map = preload("res://domain/expedition/expedition_map.gd")
	var node := Map.node_of(map_data, node_id)
	if node.is_empty():
		return {"ok": false, "type": "none", "text": "", "money": 0.0, "reputation": 0.0, "floor": int(run.expedition.get("floor", 1))}
	var floor_num := int(node.get("floor", 1))
	if result != "player_win":
		run.expedition["floor"] = floor_num
		return {"ok": true, "type": "lost", "text": "队伍被击溃,退回营地喘息。",
			"money": 0.0, "reputation": 0.0, "floor": floor_num}
	var done: Dictionary = run.expedition.get("done", {})
	done[node_id] = true
	run.expedition["done"] = done
	if str(node.get("type", "")) == "boss":
		# 通关: 结算(赏金/声望/日推进/队伍伤势,与演示战斗一致),远征关闭
		var last_rep: Dictionary = run.expedition.get("last_report", {})
		if not last_rep.is_empty():
			var Settlement = preload("res://application/settle_day.gd")
			Settlement.settle(run, last_rep)
		run.expedition["active"] = false
		run.expedition["outcome"] = "victory"
		return {"ok": true, "type": "victory",
			"text": "熔核巨像轰然倒下,远征完成!赏金与声望入账,队伍回到铁匠铺。",
			"money": 0.0, "reputation": 0.0, "floor": floor_num}
	var rew := reward_for_win(floor_num)
	run.money += float(rew.money)
	run.world_flags["reputation"] = float(run.world_flags.get("reputation", 0.0)) + float(rew.reputation)
	run.expedition["floor"] = floor_num + 1
	return {"ok": true, "type": "won",
		"text": "敌群被尽数击溃,战利品塞满行囊。",
		"money": float(rew.money), "reputation": float(rew.reputation), "floor": floor_num + 1}


## ---------------- 事件池 ----------------
const EVENTS := [
	{
		"id": "caravan", "title": "游商车队",
		"text": "一辆被强盗撵得满身尘土的车队停在路边。车夫喘着粗气：『用得上就买，老子还得赶路。』",
		"options": [
			{"label": "花 30 金补给我(铁锭×2 煤×1)", "effect": {"money": -30.0, "grant": {"iron_ore": 2, "coal": 1}}},
			{"label": "买一张灵符(声望+3)", "effect": {"money": -15.0, "reputation": 3.0}},
			{"label": "什么都不买,离开", "effect": {}},
		],
	},
	{
		"id": "ruins", "title": "废弃营地",
		"text": "前人败退的营地,一口半埋的铁箱在余烬里泛着冷光。箱角压着一截断矛。",
		"options": [
			{"label": "只挑走散落的硬币(稳妥)", "effect": {"money": 15.0}},
			{"label": "撬开暗格(可能引来埋伏!)", "effect": {"money": 10.0, "grant": {"charm_crystal": 1}, "ambush": true}},
			{"label": "此地不宜久留,离开", "effect": {}},
		],
	},
	{
		"id": "shrine", "title": "余烬祭坛",
		"text": "古老祭坛上的火焰终年不熄,石壁上刻满了求福者的名字。神明在火里看着你。",
		"options": [
			{"label": "献祭 20 金,求神保佑(声望+4)", "effect": {"money": -20.0, "reputation": 4.0}},
			{"label": "献上 1 块铁矿(声望+3)", "effect": {"consume": {"iron_ore": 1}, "reputation": 3.0}},
			{"label": "保持沉默,离开", "effect": {}},
		],
	},
	{
		"id": "refugee", "title": "伤兵",
		"text": "一名断臂的佣兵靠在路碑上,三天没吃东西了。他抬眼看着你,没开口。",
		"options": [
			{"label": "给他 15 金(声望+3)", "effect": {"money": -15.0, "reputation": 3.0}},
			{"label": "无视他,继续赶路(声望-2)", "effect": {"reputation": -2.0}},
		],
	},
]

## 事件池展开: 每行一层后 从一个常用池随机(在资源层选一个;这里提供顺序取用)
static func random_event(rng: RandomNumberGenerator) -> Dictionary:
	return EVENTS[rng.randi_range(0, EVENTS.size() - 1)]


## 应用事件选项效果到 run;返回 {ambush: bool}(伏击标识供 UI 转战斗)
static func apply_effect(run, eff: Dictionary) -> Dictionary:
	var out := {"ambush": bool(eff.get("ambush", false))}
	if eff.has("money"):
		run.money = maxf(run.money + float(eff.money), 0.0)
	if eff.has("reputation"):
		run.world_flags["reputation"] = float(run.world_flags.get("reputation", 0.0)) + float(eff.reputation)
	if eff.has("grant"):
		var Inventory = preload("res://domain/economy/inventory.gd")
		Inventory.grant(run, eff.grant)
	if eff.has("consume"):
		var Inventory2 = preload("res://domain/economy/inventory.gd")
		Inventory2.consume(run, eff.consume)
	return out


## 节点效果(非战斗节点: 篝火/宝箱);返回描述文本
static func apply_node(run, node: Dictionary) -> Dictionary:
	var out := {"ok": true, "text": ""}
	match str(node.get("type", "")):
		"treasure":
			var r := reward_for_treasure(int(node.get("floor", 1)))
			run.money += float(r.money)
			var Inventory = preload("res://domain/economy/inventory.gd")
			Inventory.grant(run, r.grant)
			out.text = "宝箱开启: 金币 +%.0f,铁锭 +1%s" % [float(r.money), ("、水晶 +1" if r.grant.has("charm_crystal") else "")]
		"rest":
			var durability := 25.0
			for w in run.weapons:
				w["durability"] = minf(float(w.get("durability", 100.0)) + durability, 100.0)
			out.text = "篝火旁休整: 全部武器耐久 +%.0f" % durability
		_:
			out.text = ""
	return out
