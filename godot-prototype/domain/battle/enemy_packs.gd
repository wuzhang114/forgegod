## EnemyPacks: 敌方阵容模板(从 battle_demo 部署逻辑迁出;内容唯一源)。
## 每个 pack 按地图类型给出在敌方部署区内的相对格子(相对 enemy_q_min/enemy_q_max)。

extends RefCounted

const MapTemplates := preload("res://domain/battle/map_templates.gd")

const PACKS := {
	# 默认石甲傀儡群(5 只)
	"golems": {
		"label": "石甲傀儡群",
		"role": "brute",
		"slots": [
			{"dq": 0, "dr": 0}, {"dq": 1, "dr": 0},
			{"dq": 0, "dr": 1}, {"dq": 1, "dr": 1},
			{"dq": 1, "dr": 3},
		],
	},
	# 混合编队(近战+远程+净化者)
	"mixed": {
		"label": "混编巡逻队",
		"roles": {"brute": 3, "shooter": 1, "purger": 1},
		"slots": [
			{"dq": 0, "dr": 0, "role": "brute"}, {"dq": 1, "dr": 0, "role": "purger"},
			{"dq": 0, "dr": 1, "role": "brute"}, {"dq": 1, "dr": 1, "role": "shooter"},
			{"dq": 1, "dr": 3, "role": "brute"},
		],
	},
}

const PACK_ODDS := {"golems": 0.6, "mixed": 0.4}


static func get_pack(id: String) -> Dictionary:
	return PACKS.get(id, PACKS["golems"]).duplicate(true)


static func random_pack(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	return "golems" if roll < float(PACK_ODDS["golems"]) else "mixed"


## 生成敌方部署(相对敌区左列起步);返回 [{id, role, grid}]
static func build_deploy(pack_id: String, map_id: String, prefix: String = "enemy") -> Array:
	var m := MapTemplates.get_map(map_id)
	var eq: int = int(m.enemy_q_min)
	var r_min: int = int(m.r_min)
	var pack := get_pack(pack_id)
	var out: Array = []
	var i := 0
	for slot in pack.slots:
		var role: String = str(slot.get("role", pack.get("role", "brute")))
		var grid := Vector2i(eq + int(slot.dq), r_min + int(slot.dr))
		out.append({"id": "%s_%d" % [prefix, i + 1], "role": role,
			"name": "%s %d" % [str(pack.get("label", "敌兵")), i + 1], "grid": grid})
		i += 1
	return out
