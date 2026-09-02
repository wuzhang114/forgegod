## ContentRegistry: 内容唯一源(材料/武器种类/数值模板/战场/敌群/契约模板)。
## 数值仍在 balance.gd(唯一数值源);本表做内容编目,场景不再硬编码。

extends RefCounted

const Forge := preload("res://core/forge/forge_core.gd")
const Bal := preload("res://core/config/balance.gd")
const MapTemplates := preload("res://domain/battle/map_templates.gd")
const EnemyPacks := preload("res://domain/battle/enemy_packs.gd")

## 契约模板(演示/兜底;原散落在 battle_demo 的 SRC_*)
const CONTRACT_TEMPLATES := {
	"bulwark": {"label": "蓄能盾击", "src": """
device 蓄能盾击 {
  budget: { steps: 24, cooldown: 120 }
  state: { charge: 0 }
  on block {
    charge = min(charge + blocked_damage * 0.2, 8)
  }
  on heavy_blow {
    if charge >= 8 {
      damage(target, "impact", 12)
      charge = 0
    }
  }
  on overload {
    if charge >= 4 {
      damage(target, "impact", 30)
      charge = 0
      damage_weapon(4)
    }
  }
}
"""},
	"quake": {"label": "震地怒涛", "src": """
device 震地怒涛 {
  auth: item
  budget: { entities: 12, steps: 32, cooldown: 300 }
  on right_click {
    for e in units_in_range(2) {
      apply_status(e, "stunned", 60)
    }
    damage_weapon(3)
  }
}
"""},
	"scorch": {"label": "灼烧之种", "src": """
device 灼烧之种 {
  auth: item
  traits: { guaranteed_hit: true }
  budget: { entities: 12, steps: 24, cooldown: 240 }
  state: { lit: 0 }
  on right_click {
    scorch(120)
    lit = 1
  }
  on timer {
    if lit == 1 {
      for e in scorched_units() {
        damage(e, "fire", 4)
        apply_status(e, "burning", 60)
      }
    }
  }
}
"""},
	"lifesteal": {"label": "嗜血之舞", "src": """
device 嗜血之舞 {
  auth: item
  budget: { entities: 4, steps: 20, cooldown: 480 }
  state: { charges: 0 }
  on right_click {
    charges = 3
    empower(3, 1.6)
  }
  on hit {
    if charges > 0 {
      heal_self(attack_damage * 0.5)
      heal(nearest_ally(self), attack_damage * 0.5)
      charges -= 1
    }
  }
}
"""},
}


static func material(id: String) -> Dictionary:
	return Forge.MATERIALS.get(id, Forge.MATERIALS["grey_iron"])


static func weapon_kind(id: String) -> Dictionary:
	return Forge.KINDS.get(id, {})


static func hero_tpl(role: String) -> Dictionary:
	return Bal.hero_tpl(role)


static func enemy_tpl(kind: String) -> Dictionary:
	return Bal.enemy_tpl(kind)


static func map(id: String) -> Dictionary:
	return MapTemplates.get_map(id)


static func all_maps() -> Array:
	return MapTemplates.MAPS


static func enemy_pack(id: String) -> Dictionary:
	return EnemyPacks.get_pack(id)


static func contract_template(id: String) -> Dictionary:
	return CONTRACT_TEMPLATES.get(id, CONTRACT_TEMPLATES["bulwark"])
