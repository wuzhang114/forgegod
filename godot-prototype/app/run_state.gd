## RunState: 一局游戏的唯一事实来源(纯逻辑,可序列化,可单测)。
## 架构: GameApp(根) 持有 RunState;场景/用例只读它,不散落状态。
## 兼容: 现有 GameSession(静态)保留为过渡 Adapter,逐步迁移到本模块。
## 注意: 不使用 class_name(headless -s 下全局类解析不可用);由调用方 preload。

extends RefCounted

const SCHEMA_VERSION := 1
const START_MONEY := 100.0
const START_DAY := 1
const START_INVENTORY := {"iron_ore": 3, "coal": 2, "charm_crystal": 1}


## 一局游戏的持久状态(全部可 JSON 序列化的基本类型)
var schema_version: int = SCHEMA_VERSION
var run_id := ""
var run_seed := 0
var current_day := START_DAY
var money := START_MONEY
var inventory: Dictionary = {}          # material_id -> count
var workshop: Dictionary = {}           # 熔炉/帮手/升级等(占位,后续域模块填充)
var weapons: Array = []                 # WeaponInstance 列表 [{instance_id, facts, durability, contract_src, history}]
var roster: Array = []                  # 勇者 [{id, role, name, hp_ratio, wounds}]
var expedition: Dictionary = {}         # {route_id, node, progress}(占位)
var negotiation_history: Array = []     # [{who, text, stance, topic, weapon_id}]
var world_flags: Dictionary = {}        # 环境/剧情标记
var contract_src := ""                  # 玩家定稿的神赐契约(MechLang 源码;从 GameSession 迁移目标)


## 开新局(确定性种子;同 seed 同初始世界)
func new_run(seed_value: int = 0) -> void:
	schema_version = SCHEMA_VERSION
	run_id = "run_%d_%s" % [seed_value, str(Time.get_unix_time_from_system())]
	run_seed = seed_value
	current_day = START_DAY
	money = START_MONEY
	inventory = START_INVENTORY.duplicate(true)
	workshop = {}
	weapons = _default_weapons()
	roster = []
	expedition = {}
	negotiation_history = []
	world_flags = {}
	contract_src = ""


## 默认演示三把武器(守卫/连击手/射手;契约 = 演示神赐;武装间可换装)
static func _default_weapons() -> Array:
	var Registry := preload("res://domain/content/content_registry.gd")
	var arch := {
		"demon_bulwark": {"name": "誓约盾锤", "holder": "hero_1",
			"contracts": [{"cid": "c_bulwark", "tpl": "bulwark"}, {"cid": "c_quake", "tpl": "quake"}]},
		"demon_life": {"name": "嗜血之刃", "holder": "hero_2",
			"contracts": [{"cid": "c_life", "tpl": "lifesteal"}]},
		"demon_scorch": {"name": "灼烧之弓", "holder": "hero_3",
			"contracts": [{"cid": "c_scorch", "tpl": "scorch"}]},
	}
	var out: Array = []
	for iid in arch.keys():
		var a: Dictionary = arch[iid]
		var contracts: Array = []
		for c in a.contracts:
			contracts.append({"cid": str(c.cid), "src": str(Registry.contract_template(str(c.tpl)).src)})
		out.append({"instance_id": iid, "facts": {}, "durability": 100.0,
			"contracts": contracts, "holder_id": str(a.holder)})
	return out


## 序列化(存档/网络边缘)
func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"run_id": run_id,
		"run_seed": run_seed,
		"current_day": current_day,
		"money": money,
		"inventory": inventory,
		"workshop": workshop,
		"weapons": weapons,
		"roster": roster,
		"expedition": expedition,
		"negotiation_history": negotiation_history,
		"world_flags": world_flags,
		"contract_src": contract_src,
	}


## 反序列化(缺字段容错:旧档升级友好;由调用方 new 后调用,避免类名自引用)
func load_dict(d: Dictionary) -> void:
	schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	run_id = str(d.get("run_id", ""))
	run_seed = int(d.get("run_seed", 0))
	current_day = int(d.get("current_day", START_DAY))
	money = float(d.get("money", START_MONEY))
	inventory = d.get("inventory", START_INVENTORY.duplicate(true))
	workshop = d.get("workshop", {})
	weapons = d.get("weapons", [])
	roster = d.get("roster", [])
	expedition = d.get("expedition", {})
	negotiation_history = d.get("negotiation_history", [])
	world_flags = d.get("world_flags", {})
	contract_src = str(d.get("contract_src", ""))
