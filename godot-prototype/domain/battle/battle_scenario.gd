## BattleScenario: 一次战斗的完整输入(可序列化;存档/复现/回放统一来源)。
## 内容: 规则版本 / 种子 / 地图 id+bounds+阻挡 / 双方部署 / 契约 / 技能输入(主动技)。
## BattleSim 只消费本对象;表现层不再自行决定地图与敌群。

extends RefCounted

const SCHEMA_VERSION := 1
const RULES_VERSION := 1          # 与 balance.gd 数值轴同步;公式变更时 +1

const MapTemplates := preload("res://domain/battle/map_templates.gd")
const EnemyPacks := preload("res://domain/battle/enemy_packs.gd")

var schema_version := SCHEMA_VERSION
var rules_version := RULES_VERSION
var scenario_id := ""
var seed := 0
var map_id := ""                  # 地图模板 id
var bounds: Dictionary = {}       # {q_min,q_max,r_min,r_max} (+blocked 可加)
var blocked_cells: Array = []     # Vector2i 数组(可空)
var player_deploy: Array = []     # [{id, role, name, grid}]
var enemy_deploy: Array = []      # [{id, role, name, grid}]
var contracts: Array = []         # [{cid, src, holder_id}]
var skill_inputs: Array = []      # [{cid, at}](玩家主动技;确定性输入一部分)


## 工厂: 由"地图 + 敌群包 + 种子 + 我方阵容 + 契约"构造场景(实例方法,避免静态自引用坑)
func init_build(map_id: String, pack_id: String, seed_value: int,
		roster: Array, contract_srcs: Array) -> void:
	self.map_id = map_id
	self.seed = seed_value
	scenario_id = "sc_%s_%d" % [map_id, seed_value]
	var m := MapTemplates.get_map(map_id)
	bounds = MapTemplates.bounds_of(map_id)
	player_deploy = _deploy_from_roster(roster, map_id)
	enemy_deploy = EnemyPacks.build_deploy(pack_id, map_id)
	for i in contract_srcs.size():
		var c: Dictionary = contract_srcs[i]
		contracts.append({"cid": str(c.get("cid", "c_%d" % (i + 1))),
			"src": str(c.get("src", "")), "holder_id": str(c.get("holder_id", ""))})


## 我方部署: 队伍占位(默认英雄阵容;后续由 Roster 域模块提供)
static func _deploy_from_roster(roster: Array, map_id: String) -> Array:
	var m := MapTemplates.get_map(map_id)
	var pq: int = int(m.player_q_min)
	var r_min: int = int(m.r_min)
	var r_max: int = int(m.r_max)
	var r_mid: int = floori(float(r_min + r_max) / 2.0)
	if roster.is_empty():
		roster = [
			{"id": "hero_1", "role": "guard", "name": "守卫·布兰特"},
			{"id": "hero_2", "role": "duelist", "name": "连击手·莉娅"},
			{"id": "hero_3", "role": "ranger", "name": "射手·锡拉"},
		]
	var cells := [Vector2i(pq + 1, r_mid), Vector2i(pq, r_mid), Vector2i(pq, r_min)]
	var out: Array = []
	for i in roster.size():
		var r: Dictionary = roster[i]
		out.append({"id": str(r.get("id", "hero_%d" % (i + 1))),
			"role": str(r.get("role", "guard")),
			"name": str(r.get("name", "勇者 %d" % (i + 1))),
			"grid": cells[i % cells.size()]})
	return out


## 种子派生(报告: BattleSeed = f(RunSeed, map, day) 的轻量实现)
static func derive_battle_seed(run_seed: int, map_id: String, day: int) -> int:
	# 用字符串哈希混合,确定性且跨地图不同
	var s: String = "%d|%s|%d" % [run_seed, map_id, day]
	var h := 0
	for i in s.length():
		h = (h * 31 + int(s.unicode_at(i))) % 1000000007
	return h


func to_dict() -> Dictionary:
	return {"schema_version": schema_version, "rules_version": rules_version,
		"scenario_id": scenario_id, "seed": seed, "map_id": map_id,
		"bounds": bounds, "blocked_cells": blocked_cells,
		"player_deploy": player_deploy, "enemy_deploy": enemy_deploy,
		"contracts": contracts, "skill_inputs": skill_inputs}


func load_dict(d: Dictionary) -> void:
	schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	rules_version = int(d.get("rules_version", RULES_VERSION))
	scenario_id = str(d.get("scenario_id", ""))
	seed = int(d.get("seed", 0))
	map_id = str(d.get("map_id", ""))
	bounds = d.get("bounds", {})
	blocked_cells = d.get("blocked_cells", [])
	player_deploy = d.get("player_deploy", [])
	enemy_deploy = d.get("enemy_deploy", [])
	contracts = d.get("contracts", [])
	skill_inputs = d.get("skill_inputs", [])


## 边界判定(与 BattleSim.configure_board 对齐)
func is_inside(c: Vector2i) -> bool:
	return c.x >= int(bounds.get("q_min", 0)) and c.x <= int(bounds.get("q_max", 7)) \
		and c.y >= int(bounds.get("r_min", 0)) and c.y <= int(bounds.get("r_max", 4))
