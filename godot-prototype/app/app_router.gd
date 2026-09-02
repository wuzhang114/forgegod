## AppRouter: 流程节点注册表(纯路径解析,可单测;实际切换由 GameApp 执行)。

extends RefCounted

const SCENES := {
	"forge": "res://scenes/forge/forge_scene.tscn",
	"altar": "res://scenes/altar/altar_scene.tscn",
	"armory": "res://scenes/armory/armory_scene.tscn",
	"battle": "res://scenes/battle/battle_demo.tscn",
}


## 解析流程节点 -> 场景路径;未知节点返回 ""
func resolve(id: String) -> String:
	return SCENES.get(id, "")


func has(id: String) -> bool:
	return SCENES.has(id)
