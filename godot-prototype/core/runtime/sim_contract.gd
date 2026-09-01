## SimContract: MechLang VM 与战斗 sim 的桥。
## 契约挂在"持有者"身上,由 BattleSim 广播战斗事件驱动;
## SimHost 把 MechLang 的白名单函数桥接到 sim 的实体/武器/场上状态。
## 说明: 本文件顶层 = SimContract(供 BattleSim 实例化);SimHost 为内部类。

extends RefCounted

const VM := preload("res://core/mechlang/vm.gd")
const HostBase := preload("res://core/mechlang/host_api.gd")
const DefEntity := preload("res://core/runtime/sim_entity.gd")
const DefAction := preload("res://core/runtime/sim_actions.gd")
const HexGrid := preload("res://core/runtime/hex_grid.gd")


## ---- MechLangHost 实现(B2 战斗桥) ----
class SimHost extends HostBase:
	var sim = null            # BattleSim
	var holder_id := ""       # 持有者实体 id
	var weapon: Dictionary = {}
	var weapon_state: Dictionary = {}
	var entities_spawned := 0
	var cooldown_until := 0   # 契约级冷却(vm budget.cooldown 简化:每契约一个)

	func _init(s, holder: String, w: Dictionary) -> void:
		sim = s
		holder_id = holder
		weapon = w

	func holder() -> Dictionary:
		return sim.get_entity(holder_id)

	# ---- 查询 ----
	func query(name: String, args: Array, ctx: Dictionary) -> Variant:
		var t := _resolve(args[0]) if args.size() > 0 else {}
		match name:
			"blocked_damage":
				return ctx.get("blocked_damage", 0.0)
			"target_hp_ratio":
				return t.hp / t.max_hp if not t.is_empty() else 0.0
			"hp_value":
				return t.hp if not t.is_empty() else 0.0
			"has_status":
				return 1 if (not t.is_empty() and DefEntity.has_status(t, str(args[1]))) else 0
			"self_hp_ratio":
				var h := holder()
				return h.hp / h.max_hp if not h.is_empty() else 0.0
			"target_has_tag":
				return 1 if (not t.is_empty() and str(args[1]) in (t.get("tags", []))) else 0
			"world_flag":
				return sim.world_flags.get(str(args[0]), 0)
			"zone_is_active":
				return sim.zone_is_active(args[0])
			"mark_count":
				return sim.get_marks(t.id) if not t.is_empty() else 0
			"weapon_stock":
				return weapon_state.get("stock", 0.0)
			"has_defect":
				return 1 if str(args[0]) in weapon.get("defects", []) else 0
			"nearest_enemy":
				var h := holder()
				if h.is_empty():
					return {}
				var e := DefEntity.nearest_enemy_of(h, sim.entities, 99999)
				return {"id": e.get("id", "")} if not e.is_empty() else {}
			"distance":
				var a := _resolve(args[0])
				var b := _resolve(args[1])
				if a.is_empty() or b.is_empty():
					return 99999
				return float(HexGrid.dist(a.grid, b.grid))
			"enemies_in_range":
				var h := holder()
				if h.is_empty():
					return []
				return sim.enemies_in_radius(h, int(args[0]))
			"all_enemies":
				var h := holder()
				if h.is_empty():
					return []
				return sim.all_enemies_of(h)
			"rand_range":
				return sim.rng.rand_range(args[0], args[1])
			"count_entities":
				return entities_spawned
			"weapon_state":
				return weapon_state.get(str(args[0]), null)
			"armor_value":
				return t.armor if not t.is_empty() else 0.0
			"target_evade":
				return t.evade if not t.is_empty() else 0.0
			"attack_value":
				var h := holder()
				return h.atk if not h.is_empty() else 0.0
			"hit_chance":
				var h := holder()
				if h.is_empty() or t.is_empty():
					return 0.0
				return clampf(h.hit - t.evade, 0.05, 0.95)
		return 0

	# ---- 动作 ----
	func action(name: String, args: Array, ctx: Dictionary) -> Variant:
		match name:
			"damage":
				var t := _resolve(args[0])
				if not t.is_empty() and t.alive:
					sim.mechanic_damage(holder_id, t, str(args[1]), float(args[2]), ctx.get("contract_id", ""))
			"reduce_armor":
				var t := _resolve(args[0])
				if not t.is_empty():
					t.armor = maxf(t.armor - args[1], 0.0)
					sim.push_event({"kind": "armor_break", "source_id": holder_id, "target_id": t.id,
						"amount": args[1], "tick": sim.tick})
			"knockback":
				var t := _resolve(args[0])
				var h := holder()
				if not t.is_empty() and not h.is_empty():
					# 沿远离持有者的方向击退 power 格(格级)
					var dir_i := HexGrid.direction_toward(h.grid, t.grid)
					if dir_i == -1:
						dir_i = 0
					var n: Vector2i = t.grid
					for _i in range(int(args[1])):
						var cand: Vector2i = n + HexGrid.DIRS[dir_i]
						if sim.cell_free(cand):
							n = cand
					t.grid = n
			"apply_status":
				var t := _resolve(args[0])
				if not t.is_empty() and t.alive:
					DefEntity.apply_status(t, str(args[1]), int(args[2]), holder_id)
					sim.push_event({"kind": "status_apply", "source_id": holder_id, "target_id": t.id,
						"status": str(args[1]), "ticks": int(args[2]), "tick": sim.tick})
			"spawn_sprite":
				var ref = sim.spawn_summon(holder_id, int(args[0]), int(args[1]), float(args[2]))
				entities_spawned += int(args[0])
				return ref
			"spawn_projectile":
				var ref = sim.spawn_projectile(holder_id, float(args[0]), bool(args[1]))
				return ref
			"create_zone":
				var ref = sim.create_zone(holder_id, float(args[0]), int(args[1]), float(args[2]), int(args[3]))
				return ref
			"damage_weapon":
				weapon.durability = maxf(float(weapon.get("durability", 100.0)) - float(args[0]), 0.0)
				sim.push_event({"kind": "weapon_cost", "source_id": holder_id, "amount": args[0],
					"tick": sim.tick, "contract_id": ctx.get("contract_id", "")})
			"heal_weapon":
				weapon.durability = minf(float(weapon.get("durability", 100.0)) + float(args[0]), float(weapon.get("max_durability", 100.0)))
			"set_mark":
				var t := _resolve(args[0])
				if not t.is_empty():
					sim.set_mark(t.id, holder_id)
			"clear_mark":
				var t := _resolve(args[0])
				if not t.is_empty():
					sim.clear_mark(t.id)
			"consume_offering":
				weapon_state["offering"] = float(weapon_state.get("offering", 0.0)) - float(args[0])
			"set_weapon_state":
				weapon_state[str(args[0])] = args[1]
			"destroy_entity":
				sim.destroy_entity(args[0])
			"dash":
				var h := holder()
				var t := _resolve(sim.get_focus_or_nearest(h))
				if not h.is_empty() and not t.is_empty():
					# 朝目标方向冲刺 int(distance) 格
					var dir_i := HexGrid.direction_toward(h.grid, t.grid)
					if dir_i == -1:
						return null
					var n: Vector2i = h.grid
					for _i in range(int(args[0])):
						var cand: Vector2i = n + HexGrid.DIRS[dir_i]
						if sim.cell_free(cand):
							n = cand
					h.grid = n
			"damage_self":
				var h := holder()
				if not h.is_empty():
					h.hp = maxf(h.hp - float(args[0]), 0.0)
			"heal_self":
				var h := holder()
				if not h.is_empty():
					h.hp = minf(h.hp + float(args[0]), h.max_hp)
			"spawn_beam":
				sim.spawn_beam(holder_id, int(args[0]), float(args[1]))
			"create_wall":
				sim.create_wall(holder_id, float(args[0]), int(args[1]))
		return null

	func count_entities() -> int:
		return entities_spawned

	func read_weapon_state(key: String) -> Variant:
		return weapon_state.get(key, null)

	func write_weapon_state(key: String, value: Variant) -> void:
		weapon_state[key] = value

	func _resolve(ref_v: Variant) -> Dictionary:
		if ref_v == null:
			return {}
		if typeof(ref_v) == TYPE_DICTIONARY:
			if ref_v.is_empty():
				return {}
			return sim.get_entity(str(ref_v.get("id", "")))
		if ref_v == "":
			return {}
		return sim.get_entity(str(ref_v))


## ---- 契约(VM + 宿主 + 触发统计) —— 顶层 = SimContract ----
var contract_id := ""
var vm = null
var host = null
var weapon_id := ""
var stats: Dictionary = {}


func _init(cid: String, ast: Dictionary, sim_holder_id: String, weapon: Dictionary, s) -> void:
	contract_id = cid
	weapon_id = str(weapon.get("id", cid))
	host = SimHost.new(s, sim_holder_id, weapon)
	vm = VM.new(ast, host)


func on_event(event: String, ctx: Dictionary) -> Dictionary:
	ctx["contract_id"] = contract_id
	var res: Dictionary = vm.run_event(event, ctx)
	if res.triggered:
		var st: Dictionary = stats.get(event, {"count": 0, "breached": 0})
		st.count += 1
		if res.breached:
			st.breached += 1
		stats[event] = st
	return res


func get_traits() -> Dictionary:
	return vm.get_traits()
