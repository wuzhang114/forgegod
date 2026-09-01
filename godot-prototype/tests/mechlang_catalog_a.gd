## mechlang_catalog_a.gd —— 100 机制目录(前 45 条 A 级)的 MechLang 源码。
## 结构: 每条 {id, name, src, seq:[{event, ctx}], expect}
## 测试通过 tests/run_headless.gd 加载并逐条做"解析→校验→触发→无熔断"验证。

const CATALOG_A := [
	# ============ A 组: 状态与异常(10) ============
	{
		"id": "A-1", "name": "电磁波麻痹(宝可梦)",
		"src": """
device 电磁麻痹 {
  budget: { cooldown: 60 }
  on hit {
    if rand_range(0, 1) < 0.25 {
      apply_status(target, "paralyzed", 90)
    }
  }
}
""", "seq": [{"event": "hit"}], "expect": "概率麻痹"
	},
	{
		"id": "A-2", "name": "缄默之印(星穹铁道)",
		"src": """
device 缄默之印 {
  budget: { cooldown: 90 }
  on hit {
    apply_status(target, "silenced", 120)
  }
}
""", "seq": [{"event": "hit"}], "expect": "禁技能"
	},
	{
		"id": "A-3", "name": "破胆怒吼(魔兽世界·战士)",
		"src": """
device 破胆怒吼 {
  budget: { cooldown: 240 }
  on right_click {
    for e in enemies_in_range(4) {
      apply_status(e, "feared", 60)
    }
  }
}
""", "seq": [{"event": "right_click"}], "expect": "全敌恐惧"
	},
	{
		"id": "A-4", "name": "藤蔓绞杀(魔兽世界·德鲁伊)",
		"src": """
device 藤蔓绞杀 {
  budget: { cooldown: 80 }
  on hit {
    apply_status(target, "rooted", 80)
  }
}
""", "seq": [{"event": "hit"}], "expect": "定身"
	},
	{
		"id": "A-5", "name": "缴械(魔兽世界·盗贼)",
		"src": """
device 缴械 {
  budget: { cooldown: 100 }
  on heavy_blow {
    apply_status(target, "disarmed", 60)
    damage(target, "physical", 5)
  }
}
""", "seq": [{"event": "heavy_blow"}], "expect": "禁攻击+伤害"
	},
	{
		"id": "A-6", "name": "凋零诅咒(魔兽世界·术士)",
		"src": """
device 凋零诅咒 {
  budget: { cooldown: 0 }
  on hit {
    apply_status(target, "withering", 60)
  }
}
""", "seq": [{"event": "hit"}], "expect": "持续掉血状态"
	},
	{
		"id": "A-7", "name": "隐身水(以撒/塞尔达)",
		"src": """
device 隐身水 {
  budget: { cooldown: 300 }
  on right_click {
    apply_status(self, "invisible", 120)
  }
}
""", "seq": [{"event": "right_click"}], "expect": "自身隐身"
	},
	{
		"id": "A-8", "name": "浮空裂空(怪物猎人)",
		"src": """
device 浮空裂空 {
  budget: { cooldown: 90 }
  on heavy_blow {
    damage(target, "physical", 8)
    apply_status(target, "floating", 50)
  }
}
""", "seq": [{"event": "heavy_blow"}], "expect": "击飞浮空"
	},
	{
		"id": "A-9", "name": "虚弱诅咒(魔兽世界)",
		"src": """
device 虚弱诅咒 {
  budget: { cooldown: 0 }
  on hit {
    apply_status(target, "weakened", 90)
  }
}
""", "seq": [{"event": "hit"}], "expect": "敌方减伤"
	},
	{
		"id": "A-10", "name": "剧毒叠层(宝可梦·剧毒)",
		"src": """
device 剧毒叠层 {
  budget: { steps: 24, cooldown: 30 }
  state: { venom: 0 }
  on hit {
    venom = min(venom + 1, 5)
    if venom >= 5 {
      damage(target, "poison", venom * 3)
      venom = 0
    }
  }
}
""", "seq": [{"event": "hit"}, {"event": "hit"}, {"event": "hit"}, {"event": "hit"}, {"event": "hit"}], "expect": "叠 5 层爆发 15 毒伤"
	},

	# ============ B 组: 弹道变体(8) ============
	{
		"id": "B-1", "name": "冰霜箭(植物大战僵尸·冰豌豆)",
		"src": """
device 冰霜箭 {
  budget: { cooldown: 30 }
  on attack {
    spawn_projectile(9, 0)
  }
  on projectile_hit {
    damage(target, "cryo", 4)
    apply_status(target, "slowed", 50)
  }
}
""", "seq": [{"event": "attack"}, {"event": "projectile_hit"}], "expect": "冰冻减速"
	},
	{
		"id": "B-2", "name": "毒液弹(以撒)",
		"src": """
device 毒液弹 {
  budget: { cooldown: 30 }
  on projectile_hit {
    damage(target, "poison", 3)
    apply_status(target, "poisoned", 60)
  }
}
""", "seq": [{"event": "projectile_hit"}], "expect": "持续毒伤"
	},
	{
		"id": "B-3", "name": "震荡弹(魔兽争霸·山丘之王)",
		"src": """
device 震荡弹 {
  budget: { cooldown: 60 }
  on projectile_hit {
    damage(target, "physical", 5)
    apply_status(target, "stunned", 20)
  }
}
""", "seq": [{"event": "projectile_hit"}], "expect": "命中眩晕"
	},
	{
		"id": "B-4", "name": "分裂弹(元气骑士·分裂弓)",
		"src": """
device 分裂弹 {
  budget: { entities: 3, steps: 16, cooldown: 60 }
  on projectile_hit {
    spawn_projectile(6, 0)
    spawn_projectile(6, 0)
  }
}
""", "seq": [{"event": "projectile_hit"}], "expect": "命中后一分为二"
	},
	{
		"id": "B-5", "name": "跳弹(挺进地牢·反弹)",
		"src": """
device 跳弹 {
  budget: { steps: 16, cooldown: 60 }
  on projectile_hit {
    t = nearest_enemy(target)
    damage(t, "physical", 6)
  }
}
""", "seq": [{"event": "projectile_hit"}], "expect": "弹向最近敌人"
	},
	{
		"id": "B-8", "name": "流星火雨(魔兽·术士)",
		"src": """
device 流星火雨 {
  budget: { entities: 2, steps: 16, cooldown: 300 }
  on right_click {
    create_zone(6, 20, 0, 90)
    consume_offering(2)
  }
  on timer {
    for e in enemies_in_range(6) {
      damage(e, "fire", 6)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "延迟大范围火伤"
	},
	{
		"id": "B-10", "name": "双侧弹幕(以撒·双子)",
		"src": """
device 双侧弹幕 {
  budget: { entities: 2, steps: 12, cooldown: 45 }
  on attack {
    spawn_projectile(8, 0)
    spawn_projectile(8, 0)
  }
}
""", "seq": [{"event": "attack"}], "expect": "左右同时发射"
	},

	# ============ C 组: 区域与地形(9) ============
	{
		"id": "C-1", "name": "守护之环(炉石/魔兽)",
		"src": """
device 守护之环 {
  budget: { entities: 2, steps: 16, cooldown: 300 }
  on right_click {
    z = create_zone(4, 120, 0, 0)
    set_weapon_state("ring", z)
  }
  on timer {
    z = weapon_state("ring")
    if zone_is_active(z) {
      heal_self(2)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "领域内周期自愈"
	},
	{
		"id": "C-2", "name": "荆棘陷阱(魔兽·猎人)",
		"src": """
device 荆棘陷阱 {
  budget: { steps: 24, cooldown: 120 }
  on right_click {
    create_zone(3, 300, 0, 0)
  }
  on timer {
    for e in enemies_in_range(3) {
      if !has_status(e, "trapped") {
        damage(e, "physical", 6)
        apply_status(e, "trapped", 300)
        apply_status(e, "rooted", 40)
      }
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "踩中一次刺+定身"
	},
	{
		"id": "C-3", "name": "三发雷区(以撒)",
		"src": """
device 三发雷区 {
  budget: { steps: 24, cooldown: 150 }
  state: { charges: 3 }
  on timer {
    if charges > 0 {
      for e in enemies_in_range(3) {
        damage(e, "fire", 8)
      }
      charges -= 1
    }
  }
}
""", "seq": [{"event": "timer"}, {"event": "timer"}, {"event": "timer"}, {"event": "timer"}], "expect": "限次 3 发"
	},
	{
		"id": "C-4", "name": "熔岩领域(魔兽·火法)",
		"src": """
device 熔岩领域 {
  budget: { steps: 24, cooldown: 240 }
  on right_click {
    for e in enemies_in_range(5) {
      apply_status(e, "burning", 90)
      damage(e, "fire", 5)
    }
  }
}
""", "seq": [{"event": "right_click"}], "expect": "全场引燃"
	},
	{
		"id": "C-5", "name": "冰封之面(塞尔达/以撒)",
		"src": """
device 冰封之面 {
  budget: { steps: 24, cooldown: 240 }
  on right_click {
    for e in enemies_in_range(5) {
      apply_status(e, "slowed", 120)
    }
  }
}
""", "seq": [{"event": "right_click"}], "expect": "全场减速"
	},
	{
		"id": "C-6", "name": "剧毒沼泽(魔兽·德鲁伊)",
		"src": """
device 剧毒沼泽 {
  budget: { steps: 24, cooldown: 240 }
  on timer {
    for e in enemies_in_range(4) {
      damage(e, "poison", 3)
    }
  }
}
""", "seq": [{"event": "timer"}], "expect": "区域持续毒伤"
	},
	{
		"id": "C-7", "name": "天怒降罚(黑神话·禅意)",
		"src": """
device 天怒降罚 {
  budget: { entities: 2, steps: 24, cooldown: 600 }
  on right_click {
    create_zone(8, 15, 0, 120)
    damage_weapon(4)
  }
  on timer {
    for e in enemies_in_range(8) {
      damage(e, "radiant", 10)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "超大范围延迟天击"
	},
	{
		"id": "C-8", "name": "祝福之地(炉石/祭坛)",
		"src": """
device 祝福之地 {
  budget: { entities: 2, steps: 16, cooldown: 300 }
  on right_click {
    z = create_zone(3, 240, 0, 0)
    set_weapon_state("bless", z)
  }
  on timer {
    z = weapon_state("bless")
    if zone_is_active(z) {
      heal_self(3)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "圣地持续自疗"
	},
	{
		"id": "C-9", "name": "寒冰巨网(魔兽·猎人冻网)",
		"src": """
device 寒冰巨网 {
  budget: { steps: 24, cooldown: 240 }
  on right_click {
    for e in enemies_in_range(4) {
      apply_status(e, "rooted", 60)
      apply_status(e, "slowed", 60)
    }
  }
}
""", "seq": [{"event": "right_click"}], "expect": "区域定身+减速"
	},

	# ============ D 组: 召唤与随从(9) ============
	{
		"id": "D-1", "name": "蜂群爆发(以撒·蜂)",
		"src": """
device 蜂群爆发 {
  budget: { entities: 3, steps: 24, cooldown: 150 }
  on right_click {
    for i in 3 {
      spawn_sprite(1, 200, 0)
    }
    consume_offering(1)
  }
  on timer {
    if rand_range(0, 1) < 0.7 {
      e = nearest_enemy(self)
      damage(e, "physical", 2)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "3 蜂随机蜇人"
	},
	{
		"id": "D-2", "name": "石像守卫(魔兽/泰拉瑞亚)",
		"src": """
device 石像守卫 {
  budget: { entities: 2, steps: 24, cooldown: 300 }
  on right_click {
    s = spawn_sprite(1, 800, 0)
    set_weapon_state("statue", s)
  }
  on timer {
    s = weapon_state("statue")
    if zone_is_active(s) {
      for e in enemies_in_range(4) {
        apply_status(e, "slowed", 20)
      }
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "雕像减速光环"
	},
	{
		"id": "D-3", "name": "龙鹰喷吐(魔兽·猎)",
		"src": """
device 龙鹰喷吐 {
  budget: { entities: 2, steps: 24, cooldown: 150 }
  on right_click {
    s = spawn_sprite(1, 400, 0)
    set_weapon_state("pet", s)
  }
  on timer {
    for e in enemies_in_range(4) {
      damage(e, "fire", 3)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "宠物扇形喷火"
	},
	{
		"id": "D-4", "name": "亡骨兵队(暗黑3·死灵)",
		"src": """
device 亡骨兵队 {
  budget: { entities: 3, steps: 12, cooldown: 0 }
  on kill {
    spawn_sprite(1, 300, 0)
  }
}
""", "seq": [{"event": "kill"}], "expect": "击杀召唤骷髅"
	},
	{
		"id": "D-5", "name": "藤妖缠绕(魔兽·德鲁伊)",
		"src": """
device 藤妖缠绕 {
  budget: { entities: 2, steps: 24, cooldown: 240 }
  on right_click {
    s = spawn_sprite(1, 400, 0)
    set_weapon_state("vine", s)
  }
  on timer {
    for e in enemies_in_range(4) {
      if !has_status(e, "rooted") {
        apply_status(e, "rooted", 40)
      }
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "附近敌人被缠"
	},
	{
		"id": "D-6", "name": "护符精灵(以撒/原神)",
		"src": """
device 护符精灵 {
  budget: { entities: 1, steps: 12, cooldown: 300 }
  on right_click {
    s = spawn_sprite(1, 600, 16)
    apply_status(self, "guarded", 600)
  }
}
""", "seq": [{"event": "right_click"}], "expect": "替挡一次的精灵"
	},
	{
		"id": "D-8", "name": "稻草人嘲讽(魔兽·猎)",
		"src": """
device 稻草人嘲讽 {
  budget: { entities: 2, steps: 24, cooldown: 300 }
  on right_click {
    s = spawn_sprite(1, 120, 0)
    set_weapon_state("scarecrow", s)
  }
  on timer {
    s = weapon_state("scarecrow")
    if zone_is_active(s) {
      for e in enemies_in_range(5) {
        apply_status(e, "taunted", 30)
      }
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "嘲讽周围敌人"
	},
	{
		"id": "D-9", "name": "猎龙幼兽(怪物猎人)",
		"src": """
device 猎龙幼兽 {
  budget: { entities: 2, steps: 24, cooldown: 240 }
  on right_click {
    s = spawn_sprite(1, 500, 0)
    set_weapon_state("hound", s)
  }
  on heavy_blow {
    apply_status(target, "silenced", 40)
  }
}
""", "seq": [{"event": "right_click"}, {"event": "heavy_blow"}], "expect": "宠物打断施法"
	},
	{
		"id": "D-10", "name": "孢子蘑菇(以撒)",
		"src": """
device 孢子蘑菇 {
  budget: { entities: 2, steps: 24, cooldown: 150 }
  on right_click {
    create_zone(2, 60, 0, 45)
  }
  on timer {
    for e in enemies_in_range(2) {
      damage(e, "poison", 5)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "timer"}], "expect": "延迟爆炸的孢子"
	},

	# ============ E 组: 能量、资源与蓄力(10) ============
	{
		"id": "E-1", "name": "怒气沸腾(魔兽·狂战士)",
		"src": """
device 怒气沸腾 {
  budget: { steps: 24, cooldown: 0 }
  state: { rage: 0 }
  on hurt {
    rage = min(rage + hurt_damage * 0.4, 20)
  }
  on attack {
    if rage > 8 {
      damage(target, "physical", 3 + rage * 0.5)
      rage = 0
    }
  }
}
""", "seq": [{"event": "hurt"}, {"event": "attack"}], "expect": "受伤积怒换输出"
	},
	{
		"id": "E-2", "name": "蓄力狙击(魔兽/无主之地)",
		"src": """
device 蓄力狙击 {
  budget: { steps: 24, cooldown: 60 }
  state: { charge: 0 }
  on timer {
    charge = min(charge + 5, 20)
  }
  on attack {
    if charge >= 20 {
      damage(target, "physical", 20)
      charge = 0
    }
  }
}
""", "seq": [{"event": "timer"}, {"event": "timer"}, {"event": "timer"}, {"event": "attack"}], "expect": "满档 20 伤"
	},
	{
		"id": "E-3", "name": "灵魂碎片(魔兽·术士)",
		"src": """
device 灵魂碎片 {
  budget: { steps: 16, cooldown: 30 }
  state: { shards: 0 }
  on kill {
    shards = min(shards + 1, 3)
  }
  on right_click {
    if shards >= 1 {
      for e in enemies_in_range(4) {
        damage(e, "shadow", 7)
      }
      shards -= 1
    }
  }
}
""", "seq": [{"event": "kill"}, {"event": "right_click"}], "expect": "碎片换 AoE"
	},
	{
		"id": "E-4", "name": "扒窃(魔兽·盗贼)",
		"src": """
device 扒窃 {
  budget: { steps: 12, cooldown: 60 }
  state: { gold: 0 }
  on hit {
    gold += 3
    set_weapon_state("gold", gold)
  }
}
""", "seq": [{"event": "hit"}, {"event": "hit"}], "expect": "命中偷金"
	},
	{
		"id": "E-5", "name": "封印祭献(暗黑3·血祭)",
		"src": """
device 封印祭献 {
  budget: { steps: 16, cooldown: 300 }
  on right_click {
    if has_status(self, "blessed") {
      for e in enemies_in_range(4) {
        damage(e, "radiant", 12)
      }
      damage_weapon(3)
    }
  }
}
""", "seq": [{"event": "right_click"}], "expect": "献祭状态换爆发"
	},
	{
		"id": "E-6", "name": "锅炉超温(怪物猎人·弩炮)",
		"src": """
device 锅炉超温 {
  budget: { steps: 16, cooldown: 0 }
  state: { heat: 0 }
  on attack {
    heat = heat + 10
    if heat <= 100 {
      damage(target, "physical", 6 + heat * 0.05)
    } else {
      damage_weapon(2)
    }
  }
  on timer {
    heat = max(heat - 2, 0)
  }
}
""", "seq": [{"event": "attack"}, {"event": "attack"}, {"event": "attack"}], "expect": "高热高伤,过热惩罚"
	},
	{
		"id": "E-7", "name": "影能聚积(风暴·伊利丹)",
		"src": """
device 影能聚积 {
  budget: { steps: 24, cooldown: 0 }
  state: { shadow: 0 }
  on kill {
    shadow = min(shadow + 1, 5)
  }
  on attack {
    if shadow >= 5 {
      damage(target, "shadow", 15)
      for e in enemies_in_range(2) {
        damage(e, "shadow", 8)
      }
      shadow = 0
    }
  }
}
""", "seq": [{"event": "kill"}, {"event": "kill"}, {"event": "kill"}, {"event": "kill"}, {"event": "kill"}, {"event": "attack"}], "expect": "满 5 影能新星"
	},
	{
		"id": "E-8", "name": "弹药管理(怪猎·弓箭)",
		"src": """
device 弹药管理 {
  budget: { steps: 16, cooldown: 0 }
  state: { ammo: 3 }
  on attack {
    if ammo > 0 {
      spawn_projectile(9, 0)
      ammo -= 1
    } else {
      damage_weapon(1)
    }
  }
  on timer {
    ammo = min(ammo + 1, 3)
  }
}
""", "seq": [{"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}], "expect": "3 发装填耗尽罚耐"
	},
	{
		"id": "E-9", "name": "月光层(魔兽·平衡德)",
		"src": """
device 月光层 {
  budget: { steps: 24, cooldown: 0 }
  state: { moon: 0 }
  on timer {
    moon = min(moon + 1, 4)
  }
  on attack {
    if moon >= 4 {
      damage(target, "arcane", 10)
      apply_status(target, "slowed", 40)
      moon = 0
    }
  }
}
""", "seq": [{"event": "timer"}, {"event": "timer"}, {"event": "timer"}, {"event": "timer"}, {"event": "attack"}], "expect": "4 层月光附伤"
	},
	{
		"id": "E-10", "name": "魔力回流(魔兽·奥法)",
		"src": """
device 魔力回流 {
  budget: { steps: 12, cooldown: 0 }
  on projectile_hit {
    heal_weapon(1)
  }
}
""", "seq": [{"event": "projectile_hit"}, {"event": "projectile_hit"}], "expect": "弹道命中返还耐久"
	},
]

static func get_items() -> Array:
	return CATALOG_A
