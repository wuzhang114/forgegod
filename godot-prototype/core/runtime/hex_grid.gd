class_name HexGrid
## 六边形棋盘(axial 坐标 q,r),pointy-top。
## sim 完全网格化(整数坐标,整数距离);播放器负责像素投影与滑动插值。
## 坐标 -> 屏幕(斜俯视): y 轴压扁,制造金铲铲式 54° 视角感。

const DIRS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func dist(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


static func neighbors(c: Vector2i) -> Array:
	var out: Array = []
	for d in DIRS:
		out.append(c + d)
	return out


## 半径 radius 内的所有格(含自身),用于区域/范围查询
static func cells_in_range(c: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dq in range(-radius, radius + 1):
		for dr in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			out.append(Vector2i(c.x + dq, c.y + dr))
	return out


## 沿方向的单步移动(用于击退/dash);bypass_occupied 由调用方检查
static func step_from(c: Vector2i, dir_index: int, steps: int) -> Vector2i:
	return c + DIRS[wrapi(dir_index, 0, 6)] * steps


## 朝目标方向的"移动方向索引"(选择使距离减少的邻居;返回 -1 表示已可达)
static func direction_toward(from: Vector2i, to: Vector2i) -> int:
	var best := -1
	var best_d := dist(from, to)
	for i in 6:
		var n: Vector2i = from + DIRS[i]
		var d := dist(n, to)
		if d < best_d or (d == best_d and best == -1):
			best = i
			best_d = d
	return best


## 轴向坐标 -> 像素(未投影,pointy-top,size=G)
static func to_pixel(c: Vector2i, g: float) -> Vector2:
	var x := g * sqrt(3.0) * (float(c.x) + float(c.y) / 2.0)
	var y := g * 1.5 * float(c.y)
	return Vector2(x, y)


## 像素 -> 轴向(用于拾取/最近格;对投影做逆变换)
static func to_axial(p: Vector2, g: float) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * p.x - p.y / 3.0) / g
	var r := (2.0 / 3.0 * p.y) / g
	return axial_round(q, r)


static func axial_round(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rx: float = round(x)
	var ry: float = round(y)
	var rz: float = round(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	return Vector2i(int(rx), int(rz))
