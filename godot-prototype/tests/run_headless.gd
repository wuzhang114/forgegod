## MechLang 沙盒 headless 测试：词法 / 解析 / 静态校验 / VM 执行 / 确定性 / 熔断。
## 运行：godot --headless --path . -s tests/run_headless.gd

extends SceneTree

const Lexer := preload("res://core/mechlang/lexer.gd")
const Parser := preload("res://core/mechlang/parser.gd")
const Checker := preload("res://core/mechlang/checker.gd")
const Vm := preload("res://core/mechlang/vm.gd")
const HostBase := preload("res://core/mechlang/host_api.gd")
const SeedRng := preload("res://core/runtime/rng.gd")
const MechLangDef := preload("res://core/mechlang/mechlang_def.gd")
const CatalogA := preload("res://tests/mechlang_catalog_a.gd")
const CatalogB := preload("res://tests/mechlang_catalog_b.gd")
const BattleTests := preload("res://tests/test_battle_sim.gd")
const BattleB2 := preload("res://tests/test_battle_b2.gd")
const BoardFxTests := preload("res://tests/test_board_effects.gd")
const StickyTests := preload("res://tests/test_target_sticky.gd")
const RangedTests := preload("res://tests/test_ranged_flight.gd")
const WeaponStatsTests := preload("res://tests/test_weapon_stats.gd")
const ActiveCastTests := preload("res://tests/test_active_cast.gd")
const DotScorchTests := preload("res://tests/test_dot_scorch.gd")
const LifeStealTests := preload("res://tests/test_lifesteal.gd")
const RunStateTests := preload("res://tests/test_run_state.gd")
const BattleScenarioTests := preload("res://tests/test_battle_scenario.gd")
const ContentRegistryTests := preload("res://tests/test_content_registry.gd")
const SettlementTests := preload("res://tests/test_settlement.gd")
const NegotiationTests := preload("res://tests/test_negotiation_adapter.gd")
const ExplainerTests := preload("res://tests/test_contract_explainer.gd")
const EquipTests := preload("res://tests/test_equip_weapon.gd")
const HttpContextTests := preload("res://tests/test_http_context.gd")
const ForgeTests := preload("res://tests/test_forge.gd")
const GodTests := preload("res://tests/test_scripted_god.gd")
const BalanceTests := preload("res://tests/test_balance.gd")
const ExpeditionTests := preload("res://tests/test_expedition.gd")

## 演示契约 A/B/C 的 MechLang 源码（与 00-m1-plan.md 一致）
const SRC_RELIGHT := """
device 回雷 {
  auth: item
  budget: { entities: 4, steps: 16, cooldown: 600 }
  state: { counter: 0, stock: 0.0 }
  on block {
    stock = min(stock + blocked_damage * 0.2, 12)
    counter += 1
  }
  on heavy_blow {
    if counter >= 3 {
      reduce_armor(target, 20)
      damage(target, "impact", stock)
      damage(nearest_enemy(target), "lightning", 8)
      cost = 2
      if has_defect("stress_crack") {
        cost += 2
      }
      damage_weapon(cost)
      counter = 0
    }
  }
}
"""

const SRC_SPRITE := """
device 星火之约 {
  auth: item
  budget: { entities: 2, steps: 12, cooldown: 600 }
  state: { hits: 0 }
  on hit {
    hits += 1
    if hits >= 3 {
      spawn_sprite(2, 160, 24)
      set_mark(target)
      damage_weapon(3)
      hits = 0
    }
  }
}
"""

## 故意非法：未知动作函数
const SRC_BAD_FUNC := """
device 坏武器 {
  budget: { entities: 4, steps: 8, cooldown: 600 }
  state: { counter: 0 }
  on block {
    counter += 1
    explode_world()       # 未知函数
  }
}
"""

## 故意非法：for 无上界上限（101 超限）
const SRC_BAD_FOR := """
device 坏循环 {
  budget: { entities: 4, steps: 8, cooldown: 600 }
  state: { counter: 0 }
  on block {
    for i in 101 {
      counter += 1
    }
  }
}
"""

## 故意非法：未知查询函数出现在表达式里
const SRC_BAD_QUERY := """
device 坏位置 {
  budget: { entities: 4, steps: 8, cooldown: 600 }
  state: { counter: 0 }
  on block {
    if read_world_everything(target) > 0 {
      counter += 1
    }
  }
}
"""

## 故意非法：for 迭代源是普通数值表达式(既非整数常量也非集合查询)
const SRC_BAD_FOR_EXPR := """
device 坏迭代源 {
  budget: { entities: 4, steps: 8, cooldown: 600 }
  state: { counter: 0 }
  on block {
    for i in (1 + 2) {
      counter += 1
    }
  }
}
"""

## 用户提案 1：挥剑发射火焰剑气(远程 + 火焰伤害)
const SRC_FLAME_SLASH := """
device 焰之剑气 {
  auth: item
  budget: { entities: 2, steps: 12, cooldown: 30 }
  state: { fired: 0 }
  on attack {
    spawn_projectile(9, 0)
    damage_weapon(1)
    fired += 1
  }
  on projectile_hit {
    damage(target, "fire", 9)
    apply_status(target, "burning", 60)
  }
}
"""

## 用户提案 2：盾牌受击积攒能量,满后下一次盾击释放
const SRC_BULWARK := """
device 蓄能之盾 {
  auth: item
  budget: { entities: 1, steps: 16, cooldown: 120 }
  state: { charge: 0 }
  on block {
    charge = min(charge + blocked_damage * 0.2, 8)
  }
  on hurt {
    charge = min(charge + hurt_damage * 0.1, 8)
  }
  on heavy_blow {
    if charge >= 8 {
      damage(target, "impact", charge)
      knockback(target, 4)
      charge = 0
    }
  }
}
"""

## 用户提案 3：击杀增伤(有上限)
const SRC_KILLER := """
device 猎杀者 {
  auth: item
  budget: { entities: 0, steps: 16, cooldown: 30 }
  state: { slays: 0 }
  on kill {
    slays = min(slays + 1, 5)
  }
  on hit {
    damage(target, "impact", 6 + slays)
  }
}
"""

## ================= 经典技能复刻考卷（Diablo2 / BG3） =================
## D2-1 野蛮人·旋风斩: 旋转横扫身边所有敌人
const SRC_WHIRLWIND := """
device 旋风斩 {
  auth: item
  budget: { entities: 0, steps: 48, cooldown: 90 }
  on attack {
    for e in enemies_in_range(2) {
      damage(e, "physical", 6)
      knockback(e, 2)
    }
    damage_weapon(2)
  }
}
"""

## D2-2 亚马逊·多重箭: 一次挥出多枚箭矢
const SRC_MULTISHOT := """
device 多重箭 {
  auth: item
  budget: { entities: 4, steps: 16, cooldown: 60 }
  on attack {
    for i in 3 {
      spawn_projectile(8, 1)
    }
    damage_weapon(2)
  }
}
"""

## D2-3 亚马逊·引导箭: 必中的追踪箭矢
const SRC_GUIDED := """
device 引导箭 {
  auth: item
  budget: { entities: 1, steps: 8, cooldown: 30 }
  state: { shots: 0 }
  on attack {
    spawn_projectile(10, 1)
    shots += 1
  }
  on projectile_hit {
    damage(target, "physical", 12)
    damage_weapon(1)
  }
}
"""

## D2-4 法师·火焰墙: 地面持续燃烧区域
const SRC_FIREWALL := """
device 火焰墙 {
  auth: item
  budget: { entities: 2, steps: 24, cooldown: 300 }
  state: { wall: 0 }
  on right_click {
    w = create_zone(4, 120, 0, 0)
    set_weapon_state("firewall", w)
    consume_offering(1)
  }
  on timer {
    w = weapon_state("firewall")
    if zone_is_active(w) {
      for e in enemies_in_range(4) {
        damage(e, "fire", 3)
      }
    }
  }
}
"""

## D2-5 死灵法师·尸爆: 尸体位置范围内的爆炸
const SRC_CORPSE := """
device 尸爆 {
  auth: item
  budget: { entities: 2, steps: 48, cooldown: 90 }
  on kill {
    for e in enemies_in_range(3) {
      damage(e, "fire", 10)
    }
    damage_weapon(1)
  }
}
"""

## D2-6 圣骑士·荆棘: 反弹所受伤害的一部分
const SRC_THORNS := """
device 荆棘 {
  auth: item
  budget: { entities: 0, steps: 8, cooldown: 0 }
  on hurt {
    damage(attacker, "thorns", hurt_damage * 0.25)
  }
}
"""

## D2-7 刺客·雷光守卫: 放置守卫,周期性电击周围
const SRC_SENTRY := """
device 雷光守卫 {
  auth: item
  budget: { entities: 1, steps: 24, cooldown: 120 }
  state: { deployed: 0 }
  on right_click {
    if deployed == 0 {
      s = spawn_sprite(1, 400, 0)
      deployed = 1
    }
    consume_offering(1)
  }
  on timer {
    if deployed == 1 {
      for e in enemies_in_range(6) {
        damage(e, "lightning", 5)
      }
    }
  }
}
"""

## D2-8 野蛮人·战吼/嗜血: 给自己上增益(需要 self 上下文)
const SRC_WARCRY := """
device 嗜血战吼 {
  auth: item
  budget: { entities: 0, steps: 8, cooldown: 600 }
  on right_click {
    apply_status(self, "enraged", 200)
    heal_weapon(1)
  }
}
"""

## BG3-1 游侠·猎人印记: 标记目标,其后的重击获得额外伤害
const SRC_HUNTMARK := """
device 猎人印记 {
  auth: item
  budget: { entities: 0, steps: 12, cooldown: 0 }
  on hit {
    set_mark(target)
  }
  on heavy_blow {
    if mark_count(target) > 0 {
      damage(target, "physical", 4)
    }
  }
}
"""

## BG3-2 圣武士·至圣斩: 消耗充能资源,重型神圣伤害
const SRC_SMITE := """
device 至圣斩 {
  auth: item
  budget: { entities: 0, steps: 12, cooldown: 0 }
  state: { smite_charges: 2 }
  on heavy_blow {
    if smite_charges > 0 {
      damage(target, "radiant", 12)
      smite_charges -= 1
    }
  }
}
"""

## BG3-3 法师·火球术: 命中后范围爆炸
const SRC_FIREBALL := """
device 火球术 {
  auth: item
  budget: { entities: 2, steps: 48, cooldown: 300 }
  on right_click {
    spawn_projectile(7, 0)
    consume_offering(2)
  }
  on projectile_hit {
    for e in enemies_in_range(3) {
      damage(e, "fire", 8)
    }
  }
}
"""

## BG3-4 德鲁伊·月火术: 延迟生成的持续灼烧区域
const SRC_MOONBEAM := """
device 月火术 {
  auth: item
  budget: { entities: 2, steps: 24, cooldown: 300 }
  on right_click {
    z = create_zone(5, 150, 0, 30)
    set_weapon_state("moon", z)
    consume_offering(1)
  }
  on timer {
    z = weapon_state("moon")
    if zone_is_active(z) {
      for e in enemies_in_range(5) {
        damage(e, "radiant", 4)
      }
    }
  }
}
"""

## ================= 想象力考卷第二季(Dota2 / LoL / 原神) =================
## Dota-1 谜团·黑洞: 区域强牵引 + 全场眩晕 + 持续伤害
const SRC_BLACKHOLE := """
device 黑洞 {
  auth: item
  budget: { entities: 2, steps: 48, cooldown: 900 }
  on right_click {
    z = create_zone(6, 60, 8, 0)
    set_weapon_state("hole", z)
    for e in enemies_in_range(6) {
      apply_status(e, "stunned", 40)
    }
    consume_offering(3)
  }
  on timer {
    z = weapon_state("hole")
    if zone_is_active(z) {
      for e in enemies_in_range(6) {
        damage(e, "void", 8)
      }
    }
  }
}
"""

## Dota-2 凤凰·太阳射线: 直线持续光束
const SRC_SUNRAY := """
device 太阳射线 {
  auth: item
  budget: { entities: 1, steps: 10, cooldown: 600 }
  on right_click {
    spawn_beam(60, 6)
    damage_weapon(2)
    consume_offering(1)
  }
}
"""

## Dota-3 水人·波浪形态: 位移并伤害沿途敌人
const SRC_WAVEFORM := """
device 波浪形态 {
  auth: item
  budget: { entities: 0, steps: 48, cooldown: 300 }
  on attack {
    dash(6)
    for e in enemies_in_range(2) {
      damage(e, "tidal", 8)
    }
  }
}
"""

## Dota-4 幽鬼·辉耀: 常驻光环灼烧周围
const SRC_RADIANCE := """
device 辉耀光环 {
  auth: item
  budget: { entities: 0, steps: 48, cooldown: 0 }
  on timer {
    for e in enemies_in_range(4) {
      damage(e, "radiant", 4)
    }
  }
}
"""

## LoL-1 辛德拉·暗黑法球: 场地攒球,攒满一次引爆
const SRC_DARKSPHERES := """
device 暗黑法球 {
  auth: item
  budget: { entities: 3, steps: 48, cooldown: 150 }
  state: { orbs: 0 }
  on right_click {
    create_zone(2, 25, 0, 0)
    orbs += 1
  }
  on heavy_blow {
    if orbs >= 3 {
      for e in enemies_in_range(3) {
        damage(e, "dark", 10)
      }
      orbs = 0
    }
  }
}
"""

## LoL-2 奈德丽·标枪: 距离越远伤害越高
const SRC_JAVELIN := """
device 标枪 {
  auth: item
  budget: { entities: 1, steps: 12, cooldown: 60 }
  on attack {
    d = distance(self, target)
    damage(target, "physical", 5 + d * 0.5)
  }
}
"""

## LoL-3 亚索·风墙: 立起阻挡敌方投射物的墙
const SRC_WINDWALL := """
device 风墙 {
  auth: item
  budget: { entities: 1, steps: 8, cooldown: 600 }
  on right_click {
    create_wall(6, 200)
    consume_offering(1)
  }
}
"""

## LoL-4 盲僧·神龙摆尾: 踢飞目标并击退
const SRC_DRAGONKICK := """
device 神龙摆尾 {
  auth: item
  budget: { entities: 0, steps: 12, cooldown: 300 }
  on heavy_blow {
    damage(target, "physical", 8)
    knockback(target, 10)
  }
}
"""

## 原神-1 菲谢尔·奥兹: 召唤随从自动雷击最近敌人
const SRC_OZ := """
device 断罪皇女 {
  auth: item
  budget: { entities: 1, steps: 12, cooldown: 150 }
  state: { oz: 0 }
  on right_click {
    s = spawn_sprite(1, 600, 0)
    oz = 1
    consume_offering(1)
  }
  on timer {
    if oz == 1 {
      t = nearest_enemy(self)
      damage(t, "electro", 4)
    }
  }
}
"""

## 原神-2 温迪·聚怪: 龙卷风聚拢并撕裂
const SRC_TEMPEST := """
device 风中愿景 {
  auth: item
  budget: { entities: 2, steps: 48, cooldown: 300 }
  on right_click {
    create_zone(5, 50, 10, 0)
    for e in enemies_in_range(5) {
      damage(e, "anemo", 5)
    }
    consume_offering(2)
  }
}
"""

## 原神-3 甘雨·霜华矢: 命中后延迟霜华绽放
const SRC_FROSTBLOOM := """
device 霜华矢 {
  auth: item
  budget: { entities: 2, steps: 16, cooldown: 90 }
  on attack {
    spawn_projectile(7, 0)
  }
  on projectile_hit {
    damage(target, "cryo", 10)
    apply_status(target, "frozen", 10)
    create_zone(3, 30, 0, 20)
  }
}
"""

## 原神-4 胡桃·蝶引来生: 燃烧生命换取火焰伤害
const SRC_BLOODBLOSSOM := """
device 蝶引来生 {
  auth: item
  budget: { entities: 0, steps: 12, cooldown: 60 }
  on heavy_blow {
    damage_self(5)
    damage(target, "pyro", 12)
  }
}
"""

## 原神-5 八重神子·杀生樱: 三座樱树周期放电
const SRC_SAKURA := """
device 杀生樱 {
  auth: item
  budget: { entities: 3, steps: 48, cooldown: 300 }
  state: { sakura: 0 }
  on right_click {
    for i in 3 {
      spawn_sprite(1, 500, 0)
    }
    sakura = 1
    consume_offering(2)
  }
  on timer {
    if sakura == 1 {
      for e in enemies_in_range(6) {
        damage(e, "electro", 3)
      }
    }
  }
}
"""

## 故意非法：未声明变量
const SRC_BAD_VAR := """
device 坏变量 {
  budget: { entities: 4, steps: 8, cooldown: 600 }
  state: { counter: 0 }
  on block {
    counter = unknown_things + 1
  }
}
"""

## 故意非法：权限层级超出
const SRC_BAD_AUTH := """
device 越界 {
  auth: world
  budget: { entities: 4, steps: 8, cooldown: 600 }
  state: { counter: 0 }
  on block {
    counter += 1
  }
}
"""

## 运行时熔断用例：for 上限合法(100) 但 steps 预算 5，循环必然超步
const SRC_BREACH := """
device 熔断 {
  budget: { entities: 2, steps: 5, cooldown: 60 }
  state: { counter: 0 }
  on block {
    for i in 100 {
      counter += 1
      damage_weapon(1)
    }
  }
}
"""


class DummyHost:
	extends HostBase
	## 测试用模拟世界：记录所有动作，供断言检查。
	var log: Array = []
	var marks: Dictionary = {}
	var weapon_state: Dictionary = {}
	var weapon_durability := 80
	var entities := 0
	var rng: SeedRng = null
	var defects := ["stress_crack"]
	var enemies := 5
	var owner_hp := 60.0
	var last_damage := 0.0
	var statuses: Dictionary = { "enemy_1": ["burning", "stun"] }
	var tags: Dictionary = { "enemy_1": ["spirit"] }
	var flags: Dictionary = { "night": 1 }
	var zones_active: Dictionary = {}
	var entity_ids: Dictionary = {}

	func _init(r = null) -> void:
		rng = r

	func query(name: String, args: Array, ctx: Dictionary) -> Variant:
		match name:
			"blocked_damage":
				return ctx.get("blocked_damage", 0.0)
			"target_hp_ratio":
				return 0.5
			"hp_value":
				return 40.0
			"has_status":
				var id := _mark_key(args[0])
				return 1 if statuses.get(id, []).has(args[1]) else 0
			"self_hp_ratio":
				return owner_hp / 100.0
			"target_has_tag":
				var id := _mark_key(args[0])
				return 1 if tags.get(id, []).has(args[1]) else 0
			"world_flag":
				return flags.get(args[0], 0)
			"zone_is_active":
				return 1 if zones_active.get(_mark_key(args[0]), 0) else 0
			"mark_count":
				return marks.get(_mark_key(args[0]), 0)
			"weapon_stock":
				return weapon_state.get("stock", 0.0)
			"has_defect":
				return 1 if args[0] in defects else 0
			"nearest_enemy":
				return { "id": "enemy_2" }
			"distance":
				return 30.0
			"rand_range":
				return rng.rand_range(args[0], args[1]) if rng != null else 0.5
			"count_entities":
				return entities
			"weapon_state":
				return weapon_state.get(args[0], null)
			"enemies_in_range":
				# 模拟战场:返回前 enemies 个敌人(含 enemy_1..enemy_N)
				var out: Array = []
				for i in range(enemies):
					out.append({ "id": "enemy_%d" % (i + 1) })
				return out
			"all_enemies":
				var out: Array = []
				for i in range(enemies):
					out.append({ "id": "enemy_%d" % (i + 1) })
				return out
			"armor_value":
				return 15.0
			"target_evade":
				return 0.1
			"attack_value":
				return 10.0
			"hit_chance":
				return 0.9
		return 0

	func action(name: String, args: Array, ctx: Dictionary) -> Variant:
		log.append({ "func": name, "args": args.duplicate(), "ctx_keys": ctx.keys() })
		match name:
			"damage":
				last_damage = args[2]
			"damage_weapon":
				weapon_durability -= args[0]
			"heal_weapon":
				weapon_durability += args[0]
			"spawn_sprite":
				entities += args[0]
				# 生成型:返回引用(取首个)
				var ref = { "id": "sprite_%d" % entities }
				entity_ids[_mark_key(ref)] = true
				return ref
			"spawn_projectile":
				var ref = { "id": "proj_%d" % entities }
				return ref
			"create_zone":
				var ref = { "id": "zone_%d" % (zones_active.size() + 1) }
				zones_active[_mark_key(ref)] = 1
				return ref
			"destroy_entity":
				zones_active.erase(_mark_key(args[0]))
				entities = maxi(entities - 1, 0)
			"dash":
				pass
			"damage_self":
				owner_hp = maxf(owner_hp - args[0], 0)
			"heal_self":
				owner_hp = owner_hp + args[0]
			"spawn_beam":
				pass
			"create_wall":
				var ref = { "id": "wall_%d" % (weapon_state.size() + 1) }
				return ref
			"set_mark":
				marks[_mark_key(args[0])] = 1
			"clear_mark":
				marks.erase(_mark_key(args[0]))
			"consume_offering":
				pass
			"set_weapon_state":
				weapon_state[args[0]] = args[1]
		return null

	func count_entities() -> int:
		return entities

	static func _mark_key(v: Variant) -> String:
		if typeof(v) == TYPE_DICTIONARY:
			return str(v.get("id", v))
		return str(v)

	func read_weapon_state(key: String) -> Variant:
		return weapon_state.get(key, null)

	func write_weapon_state(key: String, value: Variant) -> void:
		weapon_state[key] = value


var _fails := 0
var _passes := 0

func _initialize() -> void:
	print("=== MechLang 沙盒测试 ===")
	_test_lexer()
	_test_parser()
	_test_checker_accept()
	_test_checker_reject()
	_test_vm_relight()
	_test_vm_sprite()
	_test_vm_breach()
	_test_vm_determinism()
	_test_vm_collection()
	_test_vm_entity_ref()
	_test_vm_context_events()
	_test_vm_user_proposals()
	_test_vm_classic_replicas()
	_test_vm_imagination_replicas()
	_test_catalog_100()
	_test_vm_v03()
	_test_vm_overload()
	_test_battle_b1()
	_test_battle_b2()
	_test_board_fx()
	_test_sticky()
	_test_ranged()
	_test_wstats()
	_test_active()
	_test_dot()
	_test_lifesteal()
	_test_run_state()
	_test_battle_scenario()
	_test_content_registry()
	_test_settlement()
	_test_negotiation()
	_test_explainer()
	_test_equip()
	_test_http_context()
	_test_forge_core()
	_test_scripted_god()
	_test_balance()
	_test_expedition()
	print("=== 通过 %d / 失败 %d ===" % [_passes, _fails])
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL: " + label)


func _compile(src: String, enforce_item: bool = true) -> Dictionary:
	var p := Parser.new()
	var parsed := p.parse(src)
	if not parsed.ok:
		return { "ok": false, "errors": parsed.errors, "stage": "parse" }
	var c := Checker.new()
	var checked := c.check(parsed.ast, enforce_item)
	return { "ok": checked.ok, "errors": checked.errors, "ast": checked.ast, "stage": "check" }


func _test_lexer() -> void:
	print("-- lexer --")
	var l := Lexer.new()
	var toks := l.tokenize("device 回雷 {\n  on block { counter += 1 }\n}")
	var types := []
	for t in toks:
		types.append(t["type"])
	_check("WORD" in types and "SYMBOL" in types and "NEWLINE" in types and "EOF" in types,
		"lexer token 类型齐全")
	var l2 := Lexer.new()
	var toks2 := l2.tokenize("stock = min(stock + blocked_damage * 0.2, 12)")
	var words := []
	for t in toks2:
		if t["type"] == "WORD":
			words.append(t["value"])
	_check("stock" in words and "min" in words and "blocked_damage" in words, "lexer 标识符正确")


func _test_parser() -> void:
	print("-- parser --")
	var p := Parser.new()
	var r := p.parse(SRC_RELIGHT)
	_check(r.ok, "回雷源码可解析: " + str(r.errors))
	if r.ok:
		var ast: Dictionary = r.ast
		_check(ast.name == "回雷" and ast.kind == "program", "program 结构正确")
		_check(ast.handlers.size() == 2, "两个 handler(block/heavy_blow)")
		_check(ast.state.has("counter") and ast.state.has("stock"), "状态声明正确")
		_check(ast.budget["cooldown"] == 600, "预算解析正确")


func _test_checker_accept() -> void:
	print("-- checker accept --")
	var r := _compile(SRC_RELIGHT)
	_check(r.ok, "回雷通过静态校验 " + str(r.errors))
	if r.ok:
		var ast: Dictionary = r.ast
		_check(ast.budget.has("cooldown"), "budget 已规范化为含 cooldown")
	_check(_compile(SRC_SPRITE).ok, "星火之约通过静态校验")


func _test_checker_reject() -> void:
	print("-- checker reject --")
	_check(not _compile(SRC_BAD_FUNC).ok, "未知函数被拒")
	_check(not _compile(SRC_BAD_FOR).ok, "for 超上界被拒")
	_check(not _compile(SRC_BAD_QUERY).ok, "未知查询函数被拒")
	_check(not _compile(SRC_BAD_FOR_EXPR).ok, "for 迭代源为数值表达式被拒")
	_check(not _compile(SRC_BAD_VAR).ok, "未声明变量被拒")
	_check(not _compile(SRC_BAD_AUTH).ok, "超出权限层级被拒")


func _test_vm_relight() -> void:
	print("-- vm 回雷契约 --")
	var comp := _compile(SRC_RELIGHT)
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	# 三次格挡: 每次格挡 10 点伤害 -> stock = min(10*0.2*3, 12) = 6, counter = 3
	for i in 3:
		var res := vm.run_event("block", { "blocked_damage": 10.0 })
		_check(res.triggered and not res.breached, "block 触发 %d" % (i + 1))
	_check(vm.get_state()["counter"] == 3, "counter == 3 (实际 %s)" % str(vm.get_state()["counter"]))
	_check(abs(float(vm.get_state()["stock"]) - 6.0) < 0.001, "stock == 6.0 (实际 %s)" % str(vm.get_state()["stock"]))
	# 重击释放
	host.log.clear()
	var res2 := vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	_check(res2.triggered, "heavy_blow 触发")
	var damages := []
	for entry in host.log:
		if entry["func"] == "damage":
			damages.append(entry["args"])
	_check(damages.size() == 2, "两次 damage(主目标+电弧) 实际 %d" % damages.size())
	if damages.size() == 2:
		_check(damages[0][2] == 6.0, "主目标伤害 == stock(6.0), 实际 %s" % str(damages[0][2]))
		_check(damages[1][2] == 8.0, "电弧伤害 == 8")
	_check(host.weapon_durability == 80 - 4, "耐久 -4(裂纹额外+2), 实际 %d" % host.weapon_durability)
	_check(vm.get_state()["counter"] == 0, "释放后 counter 归零")


func _test_vm_sprite() -> void:
	print("-- vm 星火之约 --")
	var comp := _compile(SRC_SPRITE)
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	for i in 2:
		vm.run_event("hit", { "target": { "id": "enemy_1" } })
	_check(host.entities == 0, "未满 3 次前不生成小精灵")
	vm.run_event("hit", { "target": { "id": "enemy_1" } })
	_check(host.entities == 2, "满 3 次生成 2 只小精灵, 实际 %d" % host.entities)
	_check(host.marks.has("enemy_1"), "目标被标记")
	_check(host.weapon_durability == 77, "耐久 -3, 实际 %d" % host.weapon_durability)


func _test_vm_breach() -> void:
	print("-- vm 熔断 --")
	var comp := _compile(SRC_BREACH)
	_check(comp.ok, "熔断用例通过静态校验(for=100 ≤ 100)")
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	var res := vm.run_event("block", {})
	_check(res.breached, "超步数被熔断")
	_check(res.steps > 0 and res.steps <= MechLangDef.MAX_STEPS_PER_HANDLER, "熔断发生在上限以内")
	# 熔断语义:已执行的副作用保留,但不会无限执行下去
	_check(host.weapon_durability < 80, "熔断前部分副作用已生效(耐久 %d < 80)" % host.weapon_durability)
	_check(host.weapon_durability >= 70, "熔断及时停止,未消耗全部耐久(耐久 %d)" % host.weapon_durability)
	# 确定性:相同 seed 复跑,熔断点一致
	var host2 := DummyHost.new()
	var vm2 := Vm.new(comp.ast, host2)
	var res2 := vm2.run_event("block", {})
	_check(res2.breached and host2.weapon_durability == host.weapon_durability,
		"熔断结果可复现(两次耐久一致 %d / %d)" % [host.weapon_durability, host2.weapon_durability])


func _test_vm_determinism() -> void:
	print("-- vm 确定性 --")
	var comp := _compile(SRC_RELIGHT)
	var host_a := DummyHost.new(SeedRng.new(42))
	var vm_a := Vm.new(comp.ast, host_a)
	vm_a.run_event("block", { "blocked_damage": 10.0 })
	var r1: float = host_a.rng.rand_range(0.0, 100.0)
	var host_b := DummyHost.new(SeedRng.new(42))
	var vm_b := Vm.new(comp.ast, host_b)
	vm_b.run_event("block", { "blocked_damage": 10.0 })
	var r2: float = host_b.rng.rand_range(0.0, 100.0)
	_check(r1 == r2, "相同 seed 随机序列一致 (%f vs %f)" % [r1, r2])
	var host_c := DummyHost.new(SeedRng.new(43))
	host_c.rng.rand_range(0.0, 100.0)
	var r3: float = host_c.rng.rand_range(0.0, 100.0)
	_check(r1 != r3, "不同 seed 序列不同")


## v0.2: 集合迭代 —— 火种传染(击杀点燃目标 -> 范围内全体敌人受火伤)
const SRC_CHAIN_FIRE := """
device 火种引信 {
  auth: item
  budget: { entities: 4, steps: 48, cooldown: 600 }
  state: { burns: 0 }
  on kill {
    if has_status(target, "burning") {
      for e in enemies_in_range(6) {
        damage(e, "fire", 4)
        burns += 1
      }
    }
  }
}
"""


func _test_vm_collection() -> void:
	print("-- vm v0.2 集合迭代 --")
	var comp := _compile(SRC_CHAIN_FIRE)
	_check(comp.ok, "火种引信通过静态校验 " + str(comp.errors))
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	# 敌人 5 个 -> 集合迭代应产生 5 次 damage
	var res := vm.run_event("kill", { "target": { "id": "enemy_1" } })
	_check(res.triggered and not res.breached, "kill 事件触发且未熔断")
	var fire_damages := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "fire":
			fire_damages += 1
	_check(fire_damages == 5, "对 5 个敌人各造成一次火伤, 实际 %d" % fire_damages)
	_check(vm.get_state()["burns"] == 5, "burns 计数器 == 5")
	# 非燃烧目标击杀 -> 不传染
	host.log.clear()
	var host2 := DummyHost.new()
	vm = Vm.new(comp.ast, host2)
	host2.statuses = {}
	memset_host(host2)
	vm.run_event("kill", { "target": { "id": "enemy_2" } })
	var fire2 := 0
	for entry in host2.log:
		if entry["func"] == "damage" and entry["args"][1] == "fire":
			fire2 += 1
	_check(fire2 == 0, "目标无燃烧状态时不传染")


func memset_host(host) -> void:
	host.statuses = {}


## v0.2: 实体引用 —— 生成型函数返回值存入变量并对其操作
const SRC_SPRITE_REF := """
device 伴灵指引 {
  auth: item
  budget: { entities: 4, steps: 48, cooldown: 300 }
  state: { picked: 0 }
  on heavy_blow {
    s = spawn_sprite(1, 160, 24)
    set_mark(s)
    if zone_is_active(s) {
      s = spawn_sprite(1, 160, 24)
    }
    picked += 1
  }
}
"""


func _test_vm_entity_ref() -> void:
	print("-- vm v0.2 实体引用 --")
	var comp := _compile(SRC_SPRITE_REF)
	_check(comp.ok, "伴灵指引通过静态校验 " + str(comp.errors))
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	vm.run_event("heavy_blow", {})
	# spawn 引用被存进局部变量 s,并作为 set_mark 参数
	var markedSprite := false
	for entry in host.log:
		if entry["func"] == "set_mark" and str(entry["args"][0]).contains("sprite_1"):
			markedSprite = true
	_check(markedSprite, "set_mark 接收到 spawn 返回的实体引用")
	# 注意:zone_is_active(s) 返回 0 -> 不重复 spawn
	_check(host.entities == 1, "未重复生成(zone_is_active=0), 实体数 == 1, 实际 %d" % host.entities)
	_check(vm.get_state()["picked"] == 1, "程序正常执行完毕")


## v0.2: 新事件与上下文 —— attack / projectile_hit / healed + hurt_damage
const SRC_CONTEXT := """
device 血怒 {
  auth: item
  budget: { entities: 2, steps: 16, cooldown: 60 }
  state: { rage: 0 }
  on attack {
    take = attack_damage * 0.1
    damage_weapon(take)
    rage += take
  }
  on projectile_hit {
    if has_status(target, "burning") {
      damage(target, "fire", 3)
    }
  }
  on healed {
    take2 = hurt_damage * 0.0
    rage += 1
    damage_weapon(2)
  }
}
"""


func _test_vm_context_events() -> void:
	print("-- vm v0.2 新事件与上下文 --")
	var comp := _compile(SRC_CONTEXT)
	_check(comp.ok, "血怒通过静态校验 " + str(comp.errors))
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	# attack 事件: attack_damage = 200 -> take = 20 -> 耐久 -20
	vm.run_event("attack", { "target": { "id": "enemy_1" }, "attack_damage": 200.0 })
	_check(host.weapon_durability == 60, "attack 事件扣耐 20, 实际 %d" % host.weapon_durability)
	_check(vm.get_state()["rage"] == 20.0, "rage == 20.0, 实际 %s" % str(vm.get_state()["rage"]))
	# projectile_hit 事件: 目标燃烧 -> 火伤
	host.log.clear()
	vm.run_event("projectile_hit", { "target": { "id": "enemy_1" } })
	var fire_hits := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "fire":
			fire_hits += 1
	_check(fire_hits == 1, "projectile_hit 触发燃烧联动")
	# healed 事件
	vm.run_event("healed", { "target": { "id": "enemy_1" }, "hurt_damage": 100.0 })
	_check(vm.get_state()["rage"] == 21.0, "healed 事件计入 rage, 实际 %s" % str(vm.get_state()["rage"]))


## 用户三个提案的端到端验证: 火焰剑气 / 蓄能盾击 / 击杀增伤
func _test_vm_user_proposals() -> void:
	print("-- 用户提案 1: 火焰剑气 --")
	var comp := _compile(SRC_FLAME_SLASH)
	_check(comp.ok, "焰之剑气通过静态校验 " + str(comp.errors))
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	# 挥剑 -> 发射弹道 + 扣耐久
	var res := vm.run_event("attack", { "target": { "id": "enemy_1" }, "attack_damage": 10.0 })
	_check(res.triggered and not res.breached, "attack 事件触发")
	var projectile_count := 0
	for entry in host.log:
		if entry["func"] == "spawn_projectile":
			projectile_count += 1
	_check(projectile_count == 1, "每次挥剑发射 1 枚弹道, 实际 %d" % projectile_count)
	_check(host.weapon_durability == 79, "挥剑扣耗 1 耐久, 实际 %d" % host.weapon_durability)
	# 弹道命中 -> 火焰伤害 + 点燃
	host.log.clear()
	vm.run_event("projectile_hit", { "target": { "id": "enemy_1" } })
	var fire_damage := 0.0
	var burnt := false
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "fire":
			fire_damage = entry["args"][2]
		if entry["func"] == "apply_status" and entry["args"][1] == "burning":
			burnt = true
	_check(fire_damage == 9.0, "命中造成 9 火焰伤害, 实际 %s" % str(fire_damage))
	_check(burnt, "命中附加燃烧状态")

	print("-- 用户提案 2: 蓄能盾击 --")
	comp = _compile(SRC_BULWARK)
	_check(comp.ok, "蓄能之盾通过静态校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	# 三次格挡各 20 -> charge = min(4,8)=4 -> 6 -> 8
	for i in 3:
		vm.run_event("block", { "blocked_damage": 20.0 })
	_check(vm.get_state()["charge"] == 8.0, "三次格挡后储能满 8, 实际 %s" % str(vm.get_state()["charge"]))
	# 储能满后盾击 -> 释放
	host.log.clear()
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	var impact_damage := 0.0
	var knocked := false
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "impact":
			impact_damage = entry["args"][2]
		if entry["func"] == "knockback":
			knocked = true
	_check(impact_damage == 8.0, "盾击释放 8 点冲击伤害, 实际 %s" % str(impact_damage))
	_check(knocked, "盾击附带击退")
	_check(vm.get_state()["charge"] == 0.0, "释放后储能归零, 实际 %s" % str(vm.get_state()["charge"]))
	# 未满时盾击不释放
	vm.run_event("block", { "blocked_damage": 10.0 })   # charge -> 2
	host.log.clear()
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	var released := false
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "impact":
			released = true
	_check(not released and vm.get_state()["charge"] == 2.0, "储能未满不释放(仍为 2)")

	print("-- 用户提案 3: 击杀增伤 --")
	comp = _compile(SRC_KILLER)
	_check(comp.ok, "猎杀者通过静态校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	# 击杀 2 次 -> slays=2 -> 命中伤害 = 6+2 = 8
	var kill_host := host
	for i in 2:
		kill_host.log.clear()
		vm.run_event("kill", { "target": { "id": "enemy_%d" % (i + 1) } })
	_check(vm.get_state()["slays"] == 2, "两击杀后 slays == 2, 实际 %s" % str(vm.get_state()["slays"]))
	kill_host.log.clear()
	vm.run_event("hit", { "target": { "id": "enemy_1" } })
	var dmg1 := 0.0
	for entry in kill_host.log:
		if entry["func"] == "damage":
			dmg1 = entry["args"][2]
	_check(dmg1 == 8.0, "命中伤害 6+2=8, 实际 %s" % str(dmg1))
	# 击杀 7 次 -> 封顶 5 -> 命中伤害 = 6+5 = 11
	for i in 7:
		vm.run_event("kill", { "target": { "id": "enemy_%d" % (i + 1) } })
	_check(vm.get_state()["slays"] == 5, "击杀数封顶 5, 实际 %s" % str(vm.get_state()["slays"]))
	kill_host.log.clear()
	vm.run_event("hit", { "target": { "id": "enemy_1" } })
	var dmg2 := 0.0
	for entry in kill_host.log:
		if entry["func"] == "damage":
			dmg2 = entry["args"][2]
	_check(dmg2 == 11.0, "封顶后命中伤害 6+5=11, 实际 %s" % str(dmg2))


## 经典技能复刻验证(结构分组: 群体AOE / 齐射 / 区域持续 / 反伤 / 标记 / 资源 / 自增益)
func _test_vm_classic_replicas() -> void:
	print("-- D2 旋风斩(群体横扫) --")
	var comp := _compile(SRC_WHIRLWIND)
	_check(comp.ok, "旋风斩通过校验 " + str(comp.errors))
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	host.log.clear()
	vm.run_event("attack", { "target": { "id": "enemy_1" }, "attack_damage": 5.0 })
	var phys := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "physical":
			phys += 1
	_check(phys == 5, "横扫 5 名敌人(敌群规模=5), 实际 %d" % phys)
	_check(host.weapon_durability == 78, "旋斩耗耐久 2")

	print("-- D2 多重箭(齐射) --")
	comp = _compile(SRC_MULTISHOT)
	_check(comp.ok, "多重箭通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("attack", { "target": { "id": "enemy_1" }, "attack_damage": 5.0 })
	var projs := 0
	for entry in host.log:
		if entry["func"] == "spawn_projectile":
			projs += 1
	_check(projs == 3, "一次攻击发射 3 枚, 实际 %d" % projs)

	print("-- D2 火焰墙(区域持续伤害) --")
	comp = _compile(SRC_FIREWALL)
	_check(comp.ok, "火焰墙通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	_check(host.weapon_state.has("firewall"), "区域引用已存入武器状态")
	host.log.clear()
	vm.run_event("timer", {})
	var fire_ticks := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "fire":
			fire_ticks += 1
	_check(fire_ticks == 5, "区域持续伤害命中 5 名敌人, 实际 %d" % fire_ticks)

	print("-- D2 荆棘(反伤) --")
	comp = _compile(SRC_THORNS)
	_check(comp.ok, "荆棘通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("hurt", { "attacker": { "id": "enemy_1" }, "hurt_damage": 40.0 })
	var thorn_dmg := 0.0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "thorns":
			thorn_dmg = entry["args"][2]
	_check(thorn_dmg == 10.0, "反弹 40 的 25%% = 10, 实际 %s" % str(thorn_dmg))

	print("-- BG3 猎人印记(标记联动) --")
	comp = _compile(SRC_HUNTMARK)
	_check(comp.ok, "猎人印记通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("hit", { "target": { "id": "enemy_1" } })
	_check(host.marks.has("enemy_1"), "命中后目标被标记")
	host.log.clear()
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	var extra := 0.0
	for entry in host.log:
		if entry["func"] == "damage":
			extra = entry["args"][2]
	_check(extra == 4.0, "对标记目标的重击附加 4 伤害, 实际 %s" % str(extra))
	# 未标记目标没有加成
	host.log.clear()
	vm.run_event("heavy_blow", { "target": { "id": "enemy_2" } })
	var extra2 := 0.0
	for entry in host.log:
		if entry["func"] == "damage":
			extra2 = entry["args"][2]
	_check(extra2 == 0.0, "未标记目标不触发附加伤害")

	print("-- BG3 至圣斩(资源消耗) --")
	comp = _compile(SRC_SMITE)
	_check(comp.ok, "至圣斩通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	_check(vm.get_state()["smite_charges"] == 0, "两次使用后充能耗尽")
	host.log.clear()
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	var smite_count := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "radiant":
			smite_count += 1
	_check(smite_count == 0, "无充能时不再触发至圣斩")

	print("-- D2 嗜血战吼(self 自增益) --")
	comp = _compile(SRC_WARCRY)
	_check(comp.ok, "嗜血战吼通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "self": { "id": "hero" }, "target": null })
	var self_buff := false
	for entry in host.log:
		if entry["func"] == "apply_status" and entry["args"][0] is Dictionary \
				and str(entry["args"][0]).contains("hero") and entry["args"][1] == "enraged":
			self_buff = true
	_check(self_buff, "战吼对自己施加 enraged 状态")

	print("-- BG3 火球术(命中爆炸) --")
	comp = _compile(SRC_FIREBALL)
	_check(comp.ok, "火球术通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	var projectile_fb := 0
	for entry in host.log:
		if entry["func"] == "spawn_projectile":
			projectile_fb += 1
	_check(projectile_fb == 1, "右手发射 1 枚火球")
	host.log.clear()
	vm.run_event("projectile_hit", { "target": { "id": "enemy_1" } })
	var aoe_hits := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "fire":
			aoe_hits += 1
	_check(aoe_hits == 5, "火球爆炸命中范围 3 内全部 5 名敌人, 实际 %d" % aoe_hits)

	print("-- BG3 月火术(延迟区域) --")
	comp = _compile(SRC_MOONBEAM)
	_check(comp.ok, "月火术通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	host.log.clear()
	vm.run_event("timer", {})
	var beam_hits := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "radiant":
			beam_hits += 1
	_check(beam_hits == 5, "月火区灼烧 5 名敌人, 实际 %d" % beam_hits)


## 想象力考卷第二季: Dota2 / LoL / 原神
func _test_vm_imagination_replicas() -> void:
	print("-- Dota2 黑洞(牵引+眩晕+持续伤) --")
	var comp := _compile(SRC_BLACKHOLE)
	_check(comp.ok, "黑洞通过校验 " + str(comp.errors))
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	var stunned := 0
	for entry in host.log:
		if entry["func"] == "apply_status" and entry["args"][1] == "stunned":
			stunned += 1
	_check(stunned == 5, "黑洞落下全场 5 敌眩晕, 实际 %d" % stunned)
	host.log.clear()
	vm.run_event("timer", {})
	var void_hits := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "void":
			void_hits += 1
	_check(void_hits == 5, "黑洞持续伤害 5 敌, 实际 %d" % void_hits)

	print("-- Dota2 太阳射线(持续光束) --")
	comp = _compile(SRC_SUNRAY)
	_check(comp.ok, "太阳射线通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	var beam := false
	for entry in host.log:
		if entry["func"] == "spawn_beam":
			beam = true
	_check(beam, "成功施放持续光束")

	print("-- Dota2 波浪形态(位移+沿途伤害) --")
	comp = _compile(SRC_WAVEFORM)
	_check(comp.ok, "波浪形态通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("attack", { "target": { "id": "enemy_1" }, "attack_damage": 5.0 })
	var dash_ok := false
	var tidal := 0
	for entry in host.log:
		if entry["func"] == "dash":
			dash_ok = true
		if entry["func"] == "damage" and entry["args"][1] == "tidal":
			tidal += 1
	_check(dash_ok and tidal == 5, "位移并伤害沿途 5 敌(位移=%s, 命中=%d)" % [str(dash_ok), tidal])

	print("-- Dota2 辉耀光环(常驻灼烧) --")
	comp = _compile(SRC_RADIANCE)
	_check(comp.ok, "辉耀通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("timer", {})
	var aura := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "radiant":
			aura += 1
	_check(aura == 5, "光环每 tick 灼烧 5 敌, 实际 %d" % aura)

	print("-- LoL 辛德拉·暗黑法球(攒球引爆) --")
	comp = _compile(SRC_DARKSPHERES)
	_check(comp.ok, "暗黑法球通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	for i in 2:
		vm.run_event("right_click", { "target": null })
	_check(vm.get_state()["orbs"] == 2, "两球入池, orbs=2")
	host.log.clear()
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	var orb_hits := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "dark":
			orb_hits += 1
	_check(orb_hits == 0, "球数不足不引爆")
	vm.run_event("right_click", { "target": null })
	host.log.clear()
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	var orb_hits2 := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "dark":
			orb_hits2 += 1
	_check(orb_hits2 == 5, "三球引爆全场 5 敌, 实际 %d" % orb_hits2)
	_check(vm.get_state()["orbs"] == 0, "引爆后球池清空")

	print("-- LoL 奈德丽·标枪(距离加成) --")
	comp = _compile(SRC_JAVELIN)
	_check(comp.ok, "标枪通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("attack", { "self": { "id": "hero" }, "target": { "id": "enemy_1" }, "attack_damage": 5.0 })
	var javelin := 0.0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "physical":
			javelin = entry["args"][2]
	_check(javelin == 20.0, "距离 30 的标枪伤害 5+30*0.5=20, 实际 %s" % str(javelin))

	print("-- LoL 亚索·风墙(阻挡投射物) --")
	comp = _compile(SRC_WINDWALL)
	_check(comp.ok, "风墙通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	var wall := false
	for entry in host.log:
		if entry["func"] == "create_wall":
			wall = true
	_check(wall, "成功立起风墙")

	print("-- LoL 盲僧·神龙摆尾(踢飞) --")
	comp = _compile(SRC_DRAGONKICK)
	_check(comp.ok, "神龙摆尾通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	var kick_ok := false
	for entry in host.log:
		if entry["func"] == "knockback":
			kick_ok = true
	_check(kick_ok, "目标被踢飞")

	print("-- 原神 菲谢尔·奥兹(召唤随从) --")
	comp = _compile(SRC_OZ)
	_check(comp.ok, "奥兹通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "self": { "id": "hero" }, "target": null })
	_check(host.entities == 1, "召唤 1 只奥兹, 实际 %d" % host.entities)
	host.log.clear()
	vm.run_event("timer", { "self": { "id": "hero" } })
	var oz_hits := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "electro":
			oz_hits += 1
	_check(oz_hits == 1, "奥兹雷击最近目标一次, 实际 %d" % oz_hits)

	print("-- 原神 温迪·聚怪(龙卷风) --")
	comp = _compile(SRC_TEMPEST)
	_check(comp.ok, "聚怪通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	var anemo := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "anemo":
			anemo += 1
	_check(anemo == 5, "龙卷风撕裂 5 敌, 实际 %d" % anemo)

	print("-- 原神 甘雨·霜华矢(延迟绽放) --")
	comp = _compile(SRC_FROSTBLOOM)
	_check(comp.ok, "霜华矢通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	var proj := 0
	vm.run_event("attack", { "target": { "id": "enemy_1" }, "attack_damage": 1.0 })
	for entry in host.log:
		if entry["func"] == "spawn_projectile":
			proj += 1
	_check(proj == 1, "霜华矢发射")
	host.log.clear()
	vm.run_event("projectile_hit", { "target": { "id": "enemy_1" } })
	var frost := false
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "cryo":
			frost = true
	_check(frost, "命中造成冰伤并冻结")

	print("-- 原神 胡桃·蝶引来生(燃血换伤) --")
	comp = _compile(SRC_BLOODBLOSSOM)
	_check(comp.ok, "蝶引来生通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("heavy_blow", { "target": { "id": "enemy_1" } })
	_check(host.owner_hp == 55.0, "自损 5 生命, 剩余 %s" % str(host.owner_hp))
	var pyro := 0.0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "pyro":
			pyro = entry["args"][2]
	_check(pyro == 12.0, "火伤 12, 实际 %s" % str(pyro))

	print("-- 原神 八重神子·杀生樱(三樱周期放电) --")
	comp = _compile(SRC_SAKURA)
	_check(comp.ok, "杀生樱通过校验 " + str(comp.errors))
	host = DummyHost.new()
	vm = Vm.new(comp.ast, host)
	vm.run_event("right_click", { "target": null })
	_check(host.entities == 3, "生成 3 座樱树, 实际 %d" % host.entities)
	host.log.clear()
	vm.run_event("timer", {})
	var elec := 0
	for entry in host.log:
		if entry["func"] == "damage" and entry["args"][1] == "electro":
			elec += 1
	_check(elec == 5, "樱树周期电击 5 敌, 实际 %d" % elec)


## 100 机制目录自动验证: 逐条 解析 -> 校验 -> 按触发序列运行 -> 无熔断
func _test_catalog_100() -> void:
	print("-- 100 机制目录自动验证 (A 级 88 条) --")
	var items: Array = []
	items.append_array(CatalogA.get_items())
	items.append_array(CatalogB.get_items())
	_check(items.size() == 88, "目录 A 级条目数 == 88 (实际 %d)" % items.size())
	var base_ctx: Dictionary = {
		"target": { "id": "enemy_1" },
		"self": { "id": "hero" },
		"attacker": { "id": "enemy_2" },
		"blocked_damage": 20.0,
		"hurt_damage": 30.0,
		"attack_damage": 10.0,
	}
	var ok_count := 0
	var failed: Array = []
	for item in items:
		var comp := _compile(item.src)
		if not comp.ok:
			failed.append("%s/%s (校验: %s)" % [item.id, item.name, str(comp.errors)])
			continue
		var host := DummyHost.new()
		var vm := Vm.new(comp.ast, host)
		var bad := false
		var msg := ""
		for step in item.seq:
			var ctx: Dictionary = base_ctx.duplicate(true)
			if step.has("ctx"):
				for k in step.ctx:
					ctx[k] = step.ctx[k]
			var res = vm.run_event(step.event, ctx)
			if not res.triggered:
				bad = true
				msg = "事件 %s 未命中 handler" % step.event
				break
			if res.breached:
				bad = true
				msg = "事件 %s 触发熔断" % step.event
				break
		if bad:
			failed.append("%s/%s (运行: %s)" % [item.id, item.name, msg])
		else:
			ok_count += 1
	_check(failed.is_empty(), "目录 %d 条全部通过 (失败: %s)" % [ok_count, str(failed)])
	if not failed.is_empty():
		for f in failed:
			printerr("  CATALOG FAIL: " + f)


## v0.3: 契约特性(traits) + 战斗查询 + 判定结果上下文 + 伤害公式
const SRC_V03_FORMULA := """
device 穿甲计算 {
  auth: item
  traits: { ignores_evade: true, crit_mult: 1.5 }
  budget: { steps: 16, cooldown: 0 }
  on attack {
    if hit_landed > 0 {
      dmg = attack_value() * 100 / (100 + armor_value(target)) * hit_crit
      damage(target, "physical", dmg)
    }
  }
}
"""

const SRC_BAD_TRAIT := """
device 坏特性 {
  traits: { fly_mode: true }
  budget: { steps: 16, cooldown: 0 }
  on attack {
    damage(target, "physical", 1)
  }
}
"""

const SRC_BAD_TRAIT_RANGE := """
device 坏倍率 {
  traits: { crit_mult: 5.0 }
  budget: { steps: 16, cooldown: 0 }
  on attack {
    damage(target, "physical", 1)
  }
}
"""

const SRC_V03_GUARANTEED := """
device 锁定圣剑 {
  auth: item
  traits: { guaranteed_hit: true }
  budget: { steps: 16, cooldown: 60 }
  on attack {
    if hit_landed > 0 {
      damage(target, "radiant", 10)
    }
    damage_weapon(1)
  }
}
"""


func _test_vm_v03() -> void:
	print("-- v0.3 契约特性与战斗接缝 --")
	# traits 解析与校验
	var comp := _compile(SRC_V03_FORMULA)
	_check(comp.ok, "合法 traits 通过校验 " + str(comp.errors))
	if comp.ok:
		_check(comp.ast.traits.has("ignores_evade") and comp.ast.traits.get("ignores_evade").get("value") == true,
			"traits.ignores_evade == true")
		_check(comp.ast.traits.get("crit_mult").get("value") == 1.5, "traits.crit_mult == 1.5")
	_check(not _compile(SRC_BAD_TRAIT).ok, "未知特性被拒")
	_check(not _compile(SRC_BAD_TRAIT_RANGE).ok, "倍数超范围被拒")
	# 伤害公式: atk 10 × 100/(100+15) × crit 1.0 = 8.695...
	comp = _compile(SRC_V03_FORMULA)
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	vm.run_event("attack", { "target": { "id": "enemy_1" }, "hit_landed": 1, "hit_crit": 1.0 })
	var dmg := 0.0
	for entry in host.log:
		if entry["func"] == "damage":
			dmg = entry["args"][2]
	_check(abs(dmg - 8.695) < 0.01, "攻防系数伤害 10×100/115 ≈ 8.695, 实际 %s" % str(dmg))
	# 命中未落地 -> 契约读 hit_landed 判定后不处理
	host.log.clear()
	vm.run_event("attack", { "target": { "id": "enemy_1" }, "hit_landed": 0, "hit_crit": 0.0 })
	var dmg2 := 0.0
	for entry in host.log:
		if entry["func"] == "damage":
			dmg2 = entry["args"][2]
	_check(dmg2 == 0.0, "本击未命中则契约不结算伤害")
	# guaranteed_hit 特性读取
	comp = _compile(SRC_V03_GUARANTEED)
	var vm2 := Vm.new(comp.ast, DummyHost.new())
	var traits: Dictionary = vm2.get_traits()
	_check(traits.has("guaranteed_hit") and traits["guaranteed_hit"].get("value") == true,
		"sim 可读取 guaranteed_hit 特性")


## v0.4: 过载(契约第二形态)事件
const SRC_OVERLOAD := """
device 回雷过载 {
  auth: item
  budget: { steps: 24, cooldown: 60 }
  state: { counter: 0 }
  on block {
    counter += 1
  }
  on overload {
    if counter >= 3 {
      damage(target, "impact", 24)
      damage_weapon(6)
      counter = 0
    }
  }
}
"""


func _test_vm_overload() -> void:
	print("-- v0.4 过载事件 --")
	var comp := _compile(SRC_OVERLOAD)
	_check(comp.ok, "过载契约通过校验 " + str(comp.errors))
	var host := DummyHost.new()
	var vm := Vm.new(comp.ast, host)
	vm.run_event("block", { "blocked_damage": 10.0 })
	vm.run_event("block", { "blocked_damage": 10.0 })
	vm.run_event("block", { "blocked_damage": 10.0 })
	_check(vm.get_state()["counter"] == 3, "三次格挡后 counter == 3")
	vm.run_event("overload", { "target": { "id": "enemy_1" } })
	var burst := 0.0
	for entry in host.log:
		if entry["func"] == "damage":
			burst = entry["args"][2]
	_check(burst == 24.0, "过载第二形态造成 24 伤害, 实际 %s" % str(burst))
	_check(host.weapon_durability == 74, "过载代价 6 耐久, 实际 %d" % host.weapon_durability)
	_check(vm.get_state()["counter"] == 0, "过载后计数器清零")


func _test_battle_b1() -> void:
	var t := BattleTests.new()
	var r: Dictionary = t.run()
	_check(r.ok, "B1 战斗 sim: 通过 %d / 失败 %d" % [r.pass, r.fail])


func _test_battle_b2() -> void:
	var t := BattleB2.new()
	var r: Dictionary = t.run()
	_check(r.ok, "B2 战斗 sim: 通过 %d / 失败 %d" % [r.pass, r.fail])


func _test_board_fx() -> void:
	var t := BoardFxTests.new()
	var r: Dictionary = t.run()
	print("-- 格效果层: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "格效果层测试全绿")


func _test_sticky() -> void:
	var t := StickyTests.new()
	var r: Dictionary = t.run()
	print("-- 目标粘性: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "目标粘性测试全绿")


func _test_ranged() -> void:
	var t := RangedTests.new()
	var r: Dictionary = t.run()
	print("-- 远程弹道: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "远程弹道测试全绿")


func _test_wstats() -> void:
	var t := WeaponStatsTests.new()
	var r: Dictionary = t.run()
	print("-- 武器面板: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "武器面板测试全绿")


func _test_active() -> void:
	var t := ActiveCastTests.new()
	var r: Dictionary = t.run()
	print("-- 主动技: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "主动技测试全绿")


func _test_dot() -> void:
	var t := DotScorchTests.new()
	var r: Dictionary = t.run()
	print("-- DoT/灼烧格: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "DoT/灼烧格测试全绿")


func _test_lifesteal() -> void:
	var t := LifeStealTests.new()
	var r: Dictionary = t.run()
	print("-- 嗜血之舞: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "嗜血之舞测试全绿")


func _test_run_state() -> void:
	var t := RunStateTests.new()
	var r: Dictionary = t.run()
	print("-- RunState/存档/路由: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "RunState 测试全绿")


func _test_battle_scenario() -> void:
	var t := BattleScenarioTests.new()
	var r: Dictionary = t.run()
	print("-- 战斗场景/事件/战报: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "战斗场景测试全绿")


func _test_content_registry() -> void:
	var t := ContentRegistryTests.new()
	var r: Dictionary = t.run()
	print("-- 内容注册表/唯一计算: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "内容注册表测试全绿")


func _test_settlement() -> void:
	var t := SettlementTests.new()
	var r: Dictionary = t.run()
	print("-- 经营结算: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "经营结算测试全绿")


func _test_negotiation() -> void:
	var t := NegotiationTests.new()
	var r: Dictionary = t.run()
	print("-- 谈判适配器: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "谈判适配器测试全绿")


func _test_explainer() -> void:
	var t := ExplainerTests.new()
	var r: Dictionary = t.run()
	print("-- 契约说明/神祇配置: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "契约说明测试全绿")


func _test_equip() -> void:
	var t := EquipTests.new()
	var r: Dictionary = t.run()
	print("-- 装备用例: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "装备用例测试全绿")


func _test_http_context() -> void:
	var t := HttpContextTests.new()
	var r: Dictionary = t.run()
	print("-- 连接检测/上下文: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "连接检测测试全绿")


func _test_forge_core() -> void:
	var t := ForgeTests.new()
	var r: Dictionary = t.run()
	print("-- 锻造核心: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "锻造核心测试全绿")


func _test_scripted_god() -> void:
	var t := GodTests.new()
	var r: Dictionary = t.run()
	print("-- 假神核心: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "假神测试全绿")


func _test_balance() -> void:
	var t := BalanceTests.new()
	var r: Dictionary = t.run()
	print("-- 数值源: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "数值源测试全绿")


func _test_expedition() -> void:
	var t := ExpeditionTests.new()
	var r: Dictionary = t.run()
	print("-- 出征地图/规则: 通过 %d / 失败 %d --" % [r.pass, r.fail])
	_check(r.ok, "出征地图测试全绿")
