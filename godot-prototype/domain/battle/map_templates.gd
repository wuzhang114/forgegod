## MapTemplates: 战场模板表(从 battle_demo 迁出;唯一内容源)。
## q 是左右列,r 是上下行;gap_q 中央空列。每模板保留至少 2x3 双方部署空间。

extends RefCounted

const MAPS := [
	{"id": "forge_courtyard", "label": "熔炉庭院", "q_min": 0, "q_max": 8,
		"r_min": 0, "r_max": 4, "player_q_min": 0, "player_q_max": 2,
		"enemy_q_min": 6, "enemy_q_max": 8, "gap_q": 4, "ground_y": 420},
	{"id": "ruined_road", "label": "断垣关道", "q_min": 0, "q_max": 7,
		"r_min": 0, "r_max": 4, "player_q_min": 0, "player_q_max": 1,
		"enemy_q_min": 6, "enemy_q_max": 7, "gap_q": 4, "ground_y": 468},
	{"id": "crystal_mine", "label": "蓝晶矿窟", "q_min": 0, "q_max": 6,
		"r_min": 0, "r_max": 3, "player_q_min": 0, "player_q_max": 1,
		"enemy_q_min": 5, "enemy_q_max": 6, "gap_q": 3, "ground_y": 395},
	{"id": "autumn_shrine", "label": "秋枫神台", "q_min": 0, "q_max": 8,
		"r_min": 0, "r_max": 3, "player_q_min": 0, "player_q_max": 2,
		"enemy_q_min": 6, "enemy_q_max": 8, "gap_q": 4, "ground_y": 434},
]


static func get_map(id: String) -> Dictionary:
	for m in MAPS:
		if str(m.id) == id:
			return m.duplicate(true)
	return MAPS[0].duplicate(true)


static func bounds_of(id: String) -> Dictionary:
	var m := get_map(id)
	return {"q_min": int(m.q_min), "q_max": int(m.q_max),
		"r_min": int(m.r_min), "r_max": int(m.r_max)}


static func all_ids() -> Array:
	var out: Array = []
	for m in MAPS:
		out.append(m.id)
	return out
