class_name SeedRng
## 确定性种子 RNG（64 位 LCG 变体）。战斗/机制模拟的所有随机都走这里，禁止调用 randf/randi。
## 常量均在有符号 64 位范围内（≤ 2^63-1），GDScript 整数乘法溢出自动 wrap，保证确定性。

var _state: int = 0

const MUL := 6364136223846793005
const ADD := 1442695040888963407


func _init(seed: int = 0) -> void:
	_state = seed


func seed(seed: int) -> void:
	_state = seed


func next_u64() -> int:
	_state = _state * MUL + ADD
	return _state ^ (_state >> 32)


## 返回 [min_v, max_v] 区间内的浮点值
func rand_range(min_v: float, max_v: float) -> float:
	if max_v <= min_v:
		return min_v
	var r := next_u64()
	var u := float(r & 0x7FFFFFFF)        # 取 31 位正值
	var span := (max_v - min_v) * 1000.0
	return min_v + fmod(u, span + 1.0) / 1000.0


## 返回 [min_v, max_v] 闭区间整数
func rand_int(min_v: int, max_v: int) -> int:
	if max_v <= min_v:
		return min_v
	var r := next_u64()
	var u := int(r & 0x7FFFFFFF)
	return mini(min_v + u % (max_v - min_v + 1), max_v)
