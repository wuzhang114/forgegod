## GameApp: 应用根(autoload 单例名 GameApp)。
## 持有 RunState(唯一事实来源)+ SaveRepository + AppRouter;
## 场景只做输入翻译与结果渲染,流程导航统一走 goto()。

extends Node

const RunState := preload("res://app/run_state.gd")
const SaveRepository := preload("res://app/save_repository.gd")
const AppRouter := preload("res://app/app_router.gd")
const GameSession := preload("res://core/flow/game_session.gd")  # 过渡 Adapter(逐步迁移)

var run: RunState = null
var saves: SaveRepository = null
var router: AppRouter = null


func _ready() -> void:
	saves = SaveRepository.new()
	router = AppRouter.new()
	run = RunState.new()
	# 神祇配置(开始界面 API 设置;user://god_config.json)
	var GodConfig := preload("res://adapters/negotiation/god_config.gd")
	var cfg := GodConfig.load_config()
	run.world_flags["god_mode"] = GodConfig.effective_mode(cfg)
	# 无存档时自动开新局(演示默认);有存档则由 UI"继续"触发
	if not saves.has_save(0):
		run.new_run(20260902)
		run.money = 100.0


## 新游戏: 以种子重置 RunState,并清空过渡 GameSession(两边同步)
func new_game(seed_value: int = 0) -> void:
	run.new_run(seed_value)
	var GodConfig := preload("res://adapters/negotiation/god_config.gd")
	run.world_flags["god_mode"] = GodConfig.effective_mode(GodConfig.load_config())
	GameSession.reset()


## 继续游戏: 读取存档注入 RunState;成功返回 true
func continue_game(slot: int = 0) -> bool:
	var res: Dictionary = saves.load(slot)
	if not res.get("ok", false):
		return false
	run = res.run
	return true


## 快速存档(槽 0 = 自动槽)
func save_game() -> Dictionary:
	return saves.save(run, 0)


## 流程导航: id -> 场景路径 -> 切换(未知 id 忽略并告警)
func goto(id: String) -> void:
	var path: String = router.resolve(id)
	if path == "":
		push_warning("GameApp: unknown route '%s'" % id)
		return
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameApp: fail to goto '%s': %s" % [id, err])


## 供 UI 查询: 是否有可继续的存档
func has_save(slot: int = 0) -> bool:
	return saves.has_save(slot)
