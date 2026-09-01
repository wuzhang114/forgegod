## mechlang_catalog_b.gd —— 100 机制目录(后 39 条 A 级)的 MechLang 源码。
## 结构同 mechlang_catalog_a.gd。

const CATALOG_B := [
	# ============ F 组: 位移、牵引与物理(9) ============
	{
		"id": "F-1", "name": "猛扑撕咬(艾尔登·猎犬)",
		"src": """
device 猛扑撕咬 {
  budget: { steps: 12, cooldown: 90 }
  on attack {
    dash(4)
    damage(target, "physical", 8)
  }
}
""", "seq": [{"event": "attack"}], "expect": "跃向目标撕咬"
	},
	{
		"id": "F-2", "name": "冲锋撞击(魔兽·战士)",
		"src": """
device 冲锋撞击 {
  budget: { steps: 12, cooldown: 120 }
  on attack {
    dash(5)
    apply_status(target, "stunned", 30)
  }
}
""", "seq": [{"event": "attack"}], "expect": "冲撞眩晕"
	},
	{
		"id": "F-3", "name": "击飞上挑(黑神话·棍法)",
		"src": """
device 击飞上挑 {
  budget: { steps: 16, cooldown: 60 }
  on heavy_blow {
    damage(target, "physical", 7)
    apply_status(target, "floating", 50)
  }
}
""", "seq": [{"event": "heavy_blow"}], "expect": "浮空连击"
	},
	{
		"id": "F-4", "name": "大地践踏(艾尔登·战灰)",
		"src": """
device 大地践踏 {
  budget: { steps: 48, cooldown: 240 }
  on right_click {
    for e in enemies_in_range(3) {
      damage(e, "physical", 9)
      knockback(e, 5)
    }
  }
}
""", "seq": [{"event": "right_click"}], "expect": "范围震击击退"
	},
	{
		"id": "F-5", "name": "相位突袭(魔兽·虚空)",
		"src": """
device 相位突袭 {
  budget: { steps: 16, cooldown: 180 }
  on attack {
    dash(4)
    apply_status(self, "invulnerable", 30)
    damage(target, "shadow", 6)
  }
}
""", "seq": [{"event": "attack"}], "expect": "无敌位移+伤"
	},
	{
		"id": "F-8", "name": "借力后跃(元气骑士)",
		"src": """
device 借力后跃 {
  budget: { steps: 12, cooldown: 60 }
  on block {
    dash(3)
  }
}
""", "seq": [{"event": "block"}], "expect": "格挡后拉开距离"
	},
	{
		"id": "F-9", "name": "跃落震击(魔兽·大跳)",
		"src": """
device 跃落震击 {
  budget: { steps: 24, cooldown: 150 }
  on attack {
    dash(5)
    for e in enemies_in_range(2) {
      damage(e, "physical", 10)
      apply_status(e, "slowed", 40)
    }
  }
}
""", "seq": [{"event": "attack"}], "expect": "跳落震地"
	},
	{
		"id": "F-10", "name": "连环推撞(Brawl Stars)",
		"src": """
device 连环推撞 {
  budget: { steps: 24, cooldown: 120 }
  on attack {
    for i in 3 {
      knockback(target, 3)
    }
    damage(target, "physical", 5)
  }
}
""", "seq": [{"event": "attack"}], "expect": "三连推击"
	},

	# ============ G 组: 链式、传染与组合(9) ============
	{
		"id": "G-1", "name": "毒爆传染(以撒·脓泡)",
		"src": """
device 毒爆传染 {
  budget: { steps: 48, cooldown: 0 }
  on kill {
    if has_status(target, "poisoned") {
      for e in enemies_in_range(3) {
        damage(e, "poison", 6)
        apply_status(e, "poisoned", 60)
      }
    }
  }
}
""", "seq": [{"event": "kill"}], "expect": "毒尸爆发"
	},
	{
		"id": "G-2", "name": "终结打击(怪物猎人·骑乘)",
		"src": """
device 终结打击 {
  budget: { steps: 16, cooldown: 60 }
  on heavy_blow {
    if has_status(target, "floating") {
      damage(target, "physical", 18)
    }
  }
}
""", "seq": [{"event": "heavy_blow"}], "expect": "击飞处决"
	},
	{
		"id": "G-3", "name": "腐蚀升档(魔兽·腐蚀术)",
		"src": """
device 腐蚀升档 {
  budget: { steps: 24, cooldown: 0 }
  state: { corr: 0 }
  on hit {
    corr = min(corr + 1, 3)
    if corr >= 3 {
      damage(target, "shadow", 15)
      apply_status(target, "weakened", 60)
      corr = 0
    }
  }
}
""", "seq": [{"event": "hit"}, {"event": "hit"}, {"event": "hit"}], "expect": "3 层质变"
	},
	{
		"id": "G-4", "name": "双重施法(魔兽·奥法)",
		"src": """
device 双重施法 {
  budget: { entities: 2, steps: 24, cooldown: 120 }
  state: { double: 0 }
  on right_click {
    if double > 0 {
      spawn_projectile(8, 1)
      spawn_projectile(8, 1)
      double = 0
    } else {
      spawn_projectile(8, 1)
      double = 1
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "right_click"}], "expect": "隔发双弹"
	},
	{
		"id": "G-5", "name": "药剂连锁(魔兽·炼金)",
		"src": """
device 药剂连锁 {
  budget: { steps: 48, cooldown: 300 }
  on right_click {
    if has_status(self, "enraged") {
      for e in enemies_in_range(4) {
        damage(e, "fire", 8)
      }
    }
  }
}
""", "seq": [{"event": "right_click"}], "expect": "引爆自身增益"
	},
	{
		"id": "G-6", "name": "奥术共振(魔兽·奥法)",
		"src": """
device 奥术共振 {
  budget: { steps: 16, cooldown: 90 }
  state: { resonates: 0 }
  on projectile_hit {
    resonates += 1
    if resonates >= 3 {
      damage(target, "arcane", 12)
      resonates = 0
    }
  }
}
""", "seq": [{"event": "projectile_hit"}, {"event": "projectile_hit"}, {"event": "projectile_hit"}], "expect": "三连命中共振"
	},
	{
		"id": "G-7", "name": "连环点燃(魔兽·火法)",
		"src": """
device 连环点燃 {
  budget: { steps: 48, cooldown: 0 }
  on kill {
    for e in enemies_in_range(4) {
      apply_status(e, "burning", 80)
    }
  }
}
""", "seq": [{"event": "kill"}], "expect": "点燃下一个"
	},
	{
		"id": "G-9", "name": "随机加护(以撒·随机)",
		"src": """
device 随机加护 {
  budget: { steps: 24, cooldown: 60 }
  on hit {
    r = rand_range(0, 3)
    if r < 1 {
      apply_status(target, "burning", 60)
    } else if r < 2 {
      apply_status(target, "slowed", 60)
    } else {
      apply_status(target, "poisoned", 60)
    }
  }
}
""", "seq": [{"event": "hit"}], "expect": "随机三选一状态"
	},
	{
		"id": "G-10", "name": "诅咒传递(魔兽·痛苦术)",
		"src": """
device 诅咒传递 {
  budget: { steps: 16, cooldown: 0 }
  on kill {
    if has_status(target, "cursed") {
      t = nearest_enemy(self)
      apply_status(t, "cursed", 90)
    }
  }
}
""", "seq": [{"event": "kill"}], "expect": "死时传给最近敌人"
	},

	# ============ H 组: 生存、恢复与受击反制(9) ============
	{
		"id": "H-1", "name": "吸血刃(泰拉瑞亚)",
		"src": """
device 吸血刃 {
  budget: { steps: 12, cooldown: 0 }
  on hit {
    heal_self(attack_damage * 0.15)
  }
}
""", "seq": [{"event": "hit"}], "expect": "命中按伤害回血"
	},
	{
		"id": "H-2", "name": "战斗口粮(魔兽·战士)",
		"src": """
device 战斗口粮 {
  budget: { steps: 12, cooldown: 0 }
  on kill {
    heal_self(5)
  }
}
""", "seq": [{"event": "kill"}], "expect": "击杀回血"
	},
	{
		"id": "H-3", "name": "冰箱(炉石传说)",
		"src": """
device 冰箱 {
  budget: { steps: 24, cooldown: 300 }
  state: { saves: 1 }
  on hurt {
    if saves > 0 {
      if self_hp_ratio() < 0.05 {
        heal_self(30)
        apply_status(self, "frozen", 40)
        saves = 0
      }
    }
  }
}
""", "seq": [{"event": "hurt"}], "expect": "致死前救一次"
	},
	{
		"id": "H-4", "name": "坚盾壁垒(魔兽·防骑)",
		"src": """
device 坚盾壁垒 {
  budget: { steps: 12, cooldown: 120 }
  state: { shield: 0 }
  on block {
    shield = 1
  }
  on hurt {
    if shield > 0 {
      shield = 0
      heal_self(10)
    }
  }
}
""", "seq": [{"event": "block"}, {"event": "hurt"}], "expect": "格挡后获得吸收"
	},
	{
		"id": "H-5", "name": "治愈信标(魔兽·圣骑士)",
		"src": """
device 治愈信标 {
  budget: { steps: 12, cooldown: 0 }
  on timer {
    heal_self(2)
  }
}
""", "seq": [{"event": "timer"}, {"event": "timer"}], "expect": "周期回血"
	},
	{
		"id": "H-6", "name": "生命契约(魔兽·术士)",
		"src": """
device 生命契约 {
  budget: { steps: 16, cooldown: 150 }
  state: { shield: 0 }
  on right_click {
    damage_self(10)
    shield = 10
  }
  on hurt {
    if shield > 0 {
      shield = max(shield - hurt_damage, 0)
    }
  }
}
""", "seq": [{"event": "right_click"}, {"event": "hurt"}], "expect": "血换盾"
	},
	{
		"id": "H-7", "name": "蜂巢血脉(空洞骑士)",
		"src": """
device 蜂巢血脉 {
  budget: { steps: 24, cooldown: 300 }
  on hurt {
    if self_hp_ratio() < 0.25 {
      heal_self(30)
      apply_status(self, "frozen", 20)
    }
  }
}
""", "seq": [{"event": "hurt"}], "expect": "濒死自愈"
	},
	{
		"id": "H-8", "name": "不灭意志(魔兽·兽人)",
		"src": """
device 不灭意志 {
  budget: { steps: 24, cooldown: 0 }
  on timer {
    if self_hp_ratio() < 0.3 {
      apply_status(self, "enraged", 40)
    }
  }
}
""", "seq": [{"event": "timer"}], "expect": "低血强化"
	},
	{
		"id": "H-10", "name": "恶魔契约(魔兽·术士)",
		"src": """
device 恶魔契约 {
  budget: { steps: 48, cooldown: 0 }
  state: { deaths: 2 }
  on hurt {
    if self_hp_ratio() < 0.05 {
      if deaths > 0 {
        for e in enemies_in_range(4) {
          damage(e, "fire", 12)
        }
        heal_self(40)
        deaths -= 1
      }
    }
  }
}
""", "seq": [{"event": "hurt"}], "expect": "濒死自爆复活"
	},

	# ============ I 组: 成长、记忆与条件(9) ============
	{
		"id": "I-1", "name": "连击专精(空洞骑士·无上)",
		"src": """
device 连击专精 {
  budget: { steps: 16, cooldown: 0 }
  state: { combo: 0 }
  on hit {
    combo = min(combo + 1, 8)
    damage(target, "physical", 4 + combo * 0.5)
  }
  on timer {
    combo = max(combo - 1, 0)
  }
}
""", "seq": [{"event": "hit"}, {"event": "hit"}, {"event": "hit"}], "expect": "连击窗口增伤"
	},
	{
		"id": "I-2", "name": "影刃暴击(魔兽·敏锐)",
		"src": """
device 影刃暴击 {
  budget: { steps: 16, cooldown: 30 }
  on hit {
    if mark_count(target) > 0 {
      if rand_range(0, 1) < 0.5 {
        damage(target, "shadow", 6)
        damage(target, "shadow", 6)
      }
    }
  }
}
""", "seq": [{"event": "hit"}], "expect": "标记目标双倍"
	},
	{
		"id": "I-3", "name": "处决线(明日方舟/魔兽)",
		"src": """
device 处决线 {
  budget: { steps: 16, cooldown: 60 }
  on attack {
    if target_hp_ratio(target) < 0.3 {
      damage(target, "physical", 20)
    } else {
      damage(target, "physical", 5)
    }
  }
}
""", "seq": [{"event": "attack"}], "expect": "斩杀阈值"
	},
	{
		"id": "I-4", "name": "怒涛(魔兽·狂暴战)",
		"src": """
device 怒涛 {
  budget: { steps: 16, cooldown: 0 }
  on attack {
    damage(target, "physical", 6 + (1 - self_hp_ratio()) * 15)
  }
}
""", "seq": [{"event": "attack"}], "expect": "血越少伤越高"
	},
	{
		"id": "I-5", "name": "满血势(怪物猎人·无伤)",
		"src": """
device 满血势 {
  budget: { steps: 16, cooldown: 0 }
  on attack {
    if self_hp_ratio() > 0.99 {
      damage(target, "physical", 8)
    }
  }
}
""", "seq": [{"event": "attack"}], "expect": "满血特攻"
	},
	{
		"id": "I-6", "name": "觉醒(以撒·恶魔)",
		"src": """
device 觉醒 {
  budget: { steps: 16, cooldown: 0 }
  state: { awake: 0 }
  on hurt {
    if awake == 0 {
      awake = 1
      apply_status(self, "enraged", 300)
    }
  }
}
""", "seq": [{"event": "hurt"}], "expect": "首次受击变强"
	},
	{
		"id": "I-7", "name": "记仇(魔兽·被击方)",
		"src": """
device 记仇 {
  budget: { steps: 16, cooldown: 0 }
  state: { grudge: 0 }
  on hurt {
    grudge = min(grudge + 1, 5)
  }
  on attack {
    if grudge >= 3 {
      damage(target, "shadow", 4 + grudge)
      grudge = 0
    }
  }
}
""", "seq": [{"event": "hurt"}, {"event": "hurt"}, {"event": "hurt"}, {"event": "attack"}], "expect": "挨打叠仇,爆发"
	},
	{
		"id": "I-8", "name": "磨刀(魔兽·杀人书)",
		"src": """
device 磨刀 {
  budget: { steps: 12, cooldown: 0 }
  on kill {
    apply_status(self, "sharpened", 300)
  }
}
""", "seq": [{"event": "kill"}], "expect": "击杀短增攻"
	},
	{
		"id": "I-9", "name": "破军(王者·特攻)",
		"src": """
device 破军 {
  budget: { steps: 16, cooldown: 0 }
  on attack {
    damage(target, "physical", 5 + (1 - target_hp_ratio(target)) * 10)
  }
}
""", "seq": [{"event": "attack"}], "expect": "目标血越少越痛"
	},

	# ============ J 组: 攻击样式与武器改造(9) ============
	{
		"id": "J-1", "name": "反击架势(黑神话·盾反)",
		"src": """
device 反击架势 {
  budget: { steps: 12, cooldown: 60 }
  on block {
    damage(attacker, "physical", 6)
    knockback(attacker, 3)
  }
}
""", "seq": [{"event": "block"}], "expect": "格挡立即反击"
	},
	{
		"id": "J-2", "name": "高热过冲(怪物猎人·铳枪)",
		"src": """
device 高热过冲 {
  budget: { steps: 16, cooldown: 0 }
  state: { heat: 0 }
  on attack {
    heat = min(heat + 10, 100)
    if heat > 70 {
      damage(target, "physical", 9 + heat * 0.05)
    } else {
      damage(target, "physical", 6)
    }
  }
}
""", "seq": [{"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}], "expect": "高温热强"
	},
	{
		"id": "J-3", "name": "锯齿之刃(宝可梦/以撒)",
		"src": """
device 锯齿之刃 {
  budget: { steps: 16, cooldown: 0 }
  on hit {
    damage(target, "physical", 4)
    apply_status(target, "bleeding", 60)
  }
}
""", "seq": [{"event": "hit"}], "expect": "命中流血"
	},
	{
		"id": "J-4", "name": "蓄力重斩(怪物猎人·大剑)",
		"src": """
device 蓄力重斩 {
  budget: { steps: 24, cooldown: 90 }
  state: { q: 0 }
  on timer {
    q = min(q + 1, 3)
  }
  on heavy_blow {
    if q >= 3 {
      damage(target, "physical", 16 + q * 3)
      q = 0
    } else {
      damage(target, "physical", 8)
    }
  }
}
""", "seq": [{"event": "timer"}, {"event": "timer"}, {"event": "timer"}, {"event": "heavy_blow"}], "expect": "蓄满重击 25"
	},
	{
		"id": "J-5", "name": "挥空强化(元气骑士·狂战)",
		"src": """
device 挥空强化 {
  budget: { steps: 16, cooldown: 45 }
  state: { ready: 0 }
  on attack {
    if attack_damage <= 0 {
      ready = 1
    } else {
      if ready > 0 {
        damage(target, "physical", 6)
        ready = 0
      }
    }
  }
}
""", "seq": [{"event": "attack"}, {"event": "attack"}], "expect": "挥空后强击"
	},
	{
		"id": "J-7", "name": "月下斩(魔兽·德鲁伊)",
		"src": """
device 月下斩 {
  budget: { steps: 16, cooldown: 0 }
  on attack {
    if world_flag("night") {
      damage(target, "arcane", 9)
    } else {
      damage(target, "physical", 5)
    }
  }
}
""", "seq": [{"event": "attack"}], "expect": "夜间加成"
	},
	{
		"id": "J-8", "name": "灼热连打(魔兽·圣骑士)",
		"src": """
device 灼热连打 {
  budget: { steps: 16, cooldown: 0 }
  state: { heat: 0 }
  on attack {
    heat = min(heat + 5, 30)
    if heat >= 20 {
      damage(target, "fire", 10)
      heat = 0
    } else {
      damage(target, "physical", 5)
    }
  }
}
""", "seq": [{"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}, {"event": "attack"}], "expect": "热满爆发火伤"
	},
	{
		"id": "J-9", "name": "符文轮换(魔兽·附魔)",
		"src": """
device 符文轮换 {
  budget: { steps: 24, cooldown: 0 }
  state: { phase: 0 }
  on hit {
    if phase == 0 {
      apply_status(target, "burning", 60)
    } else if phase == 1 {
      apply_status(target, "slowed", 60)
    } else {
      t = nearest_enemy(target)
      damage(t, "lightning", 5)
    }
    phase = (phase + 1) % 3
  }
}
""", "seq": [{"event": "hit"}, {"event": "hit"}, {"event": "hit"}, {"event": "hit"}], "expect": "火冰雷轮换"
	},
]

static func get_items() -> Array:
	return CATALOG_B
