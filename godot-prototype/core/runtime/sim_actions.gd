class_name SimActionDef
## 动作标签与帧数据(02-battle-system-design.md §6.1)。
## 每个动作 = 前摇 windup → 判定窗 active → 后摇 recover,单位 tick(20Hz)。

const ACTIONS := {
	"basic": {
		"mult": 1.0, "damage_type": "physical",
		"windup": 12, "active": 6, "recover": 14,
	},
	"heavy_blow": {
		"mult": 1.5, "damage_type": "impact", "armor_shred": 20,
		"windup": 30, "active": 8, "recover": 22,
	},
	"block": {
		"mult": 0.0, "damage_type": "none", "blocks": true,
		"windup": 10, "active": 20, "recover": 10,
	},
	"ranged": {
		"mult": 1.0, "damage_type": "physical", "projectile": true,
		"windup": 20, "active": 6, "recover": 16,
	},
	"combo": {
		"mult": 0.6, "damage_type": "physical",
		"windup": 8, "active": 5, "recover": 9,
	},
}

static func get_def(tag: String) -> Dictionary:
	return ACTIONS.get(tag, ACTIONS["basic"])

static func is_block_tag(tag: String) -> bool:
	return ACTIONS.get(tag, {}).get("blocks", false)

static func mult_of(tag: String) -> float:
	return float(ACTIONS.get(tag, ACTIONS["basic"]).get("mult", 1.0))
