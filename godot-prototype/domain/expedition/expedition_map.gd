## ExpeditionMap: 杀戮尖塔式出征地图生成(纯逻辑,可单测)。
## 结构: 一组层 rows;每层若干节点(带 col 分列);相邻层节点间生成边(分支);
## 类型: 战斗/精英/事件/篝火/宝箱;末层为 Boss。
## 用法: ExpeditionMap.generate(seed, floors) -> {"rows": [...], "edges": [...]}
## 注意: 不使用 class_name(headless -s 下不可用);由调用方 preload。

extends RefCounted

const NODE_TYPES := ["combat", "elite", "event", "rest", "treasure", "boss"]
const TYPE_LABEL := {
	"combat": "战斗", "elite": "精英", "event": "事件",
	"rest": "篝火", "treasure": "宝箱", "boss": "首领",
}
const TYPE_ICON := {
	"combat": "⚔", "elite": "✦", "event": "?",
	"rest": "♨", "treasure": "◆", "boss": "☠",
}

## 层数(含最终 Boss 层)
const FLOORS := 6

## 生成地图;同 seed 同图(存档可复现)
static func generate(seed_value: int, floors: int = FLOORS) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rows: Array = []
	var edges: Array = []
	var prev_ids: Array = []
	for f in range(1, floors + 1):
		var row: Dictionary = _row_for(rng, f, floors, prev_ids)
		rows.append(row)
		var ids: Array = []
		for n in row.nodes:
			ids.append(str(n.id))
		if not prev_ids.is_empty():
			for src in prev_ids:
				for dst in ids:
					if _cols_adjacent(src, dst, rows.size() - 2, rows.size() - 1, rows):
						edges.append({"from": str(src), "to": str(dst)})
		prev_ids = ids
	edges = _ensure_connectivity(edges, rows)
	return {"seed": seed_value, "floors": floors, "rows": rows, "edges": edges}


## 一层节点: 首层全战斗(3 个);末层单 Boss;中间层 3~5 个混合
static func _row_for(rng: RandomNumberGenerator, floor_num: int, floors: int, prev_ids: Array) -> Dictionary:
	var nodes: Array = []
	if floor_num == floors:
		nodes.append({"id": "f%d_boss" % floor_num, "floor": floor_num, "col": 1, "type": "boss"})
		return {"floor": floor_num, "nodes": nodes}
	if floor_num == 1:
		for i in range(3):
			nodes.append({"id": "f%d_n%d" % [floor_num, i + 1], "floor": floor_num,
				"col": i, "type": "combat"})
		return {"floor": floor_num, "nodes": nodes}
	var count := rng.randi_range(3, 5)
	var cols := _spread_cols(count)
	var types: Array = []
	for i in range(count):
		types.append(_roll_type(rng, floor_num))
	# 每层至少一场战斗
	if not types.has("combat") and not types.has("elite"):
		types[rng.randi_range(0, count - 1)] = "combat"
	# 第 3 层 / 第 5 层各放一个精英(替换战斗位)
	if (floor_num == 3 or floor_num == 5) and types.has("combat"):
		var idx := types.find("combat")
		types[idx] = "elite"
	for i in range(count):
		nodes.append({"id": "f%d_n%d" % [floor_num, i + 1], "floor": floor_num,
			"col": cols[i], "type": types[i]})
	return {"floor": floor_num, "nodes": nodes}


static func _spread_cols(count: int) -> Array:
	if count <= 1:
		return [1]
	if count == 2:
		return [0, 2]
	var out: Array = []
	for i in range(count):
		out.append(int(round(float(i) * 2.0 / float(count - 1))))
	return out


static func _roll_type(rng: RandomNumberGenerator, floor_num: int) -> String:
	# 越靠后,战斗越多(敌群随层变强已然压迫)
	var roll := rng.randf()
	if floor_num <= 2:
		if roll < 0.55:
			return "combat"
		if roll < 0.8:
			return "event"
		return "treasure" if roll < 0.93 else "rest"
	if roll < 0.62:
		return "combat"
	if roll < 0.85:
		return "event"
	return "treasure" if roll < 0.95 else "rest"


static func _cols_adjacent(src_id: String, dst_id: String, src_row_i: int, dst_row_i: int, rows: Array) -> bool:
	var src_col := -1
	var dst_col := -1
	if src_row_i >= 0 and src_row_i < rows.size():
		for n in rows[src_row_i].nodes:
			if str(n.id) == str(src_id):
				src_col = int(n.col)
	if dst_row_i >= 0 and dst_row_i < rows.size():
		for n in rows[dst_row_i].nodes:
			if str(n.id) == str(dst_id):
				dst_col = int(n.col)
	if src_col < 0 or dst_col < 0:
		return false
	return absi(src_col - dst_col) <= 1


## 连通性兜底: 每个非末层节点至少 1 条出边;每个非首层节点至少 1 条入边
static func _ensure_connectivity(edges: Array, rows: Array) -> Array:
	var out: Array = []
	for e in edges:
		out.append({"from": str(e.from), "to": str(e.to)})
	for i in range(rows.size() - 1):
		var layer: Dictionary = rows[i]
		for n in layer.nodes:
			if not _has_edge(out, str(n.id), true):
				var dst := _nearest(row_ids(rows[i + 1]), rows, i + 1, int(n.col))
				if dst != "":
					out.append({"from": str(n.id), "to": dst})
	for i in range(1, rows.size()):
		var layer: Dictionary = rows[i]
		for n in layer.nodes:
			if not _has_edge(out, str(n.id), false):
				var src := _nearest(row_ids(rows[i - 1]), rows, i - 1, int(n.col))
				if src != "":
					out.append({"from": src, "to": str(n.id)})
	return out


static func _has_edge(edges: Array, id: String, as_from: bool) -> bool:
	for e in edges:
		if as_from and str(e.from) == id:
			return true
		if not as_from and str(e.to) == id:
			return true
	return false


static func _nearest(ids: Array, rows: Array, row_i: int, col: int) -> String:
	var best := ""
	var best_d := 999
	for n in rows[row_i].nodes:
		var d := absi(int(n.col) - col)
		if d < best_d:
			best_d = d
			best = str(n.id)
	return best


static func row_ids(row: Dictionary) -> Array:
	var out: Array = []
	for n in row.nodes:
		out.append(str(n.id))
	return out


## 地图上的某节点
static func node_of(map_data: Dictionary, id: String) -> Dictionary:
	for row in map_data.get("rows", []):
		for n in row.nodes:
			if str(n.id) == id:
				return n
	return {}


## 节点所在层数
static func floor_of(map_data: Dictionary, id: String) -> int:
	var n := node_of(map_data, id)
	return int(n.get("floor", 1))
