## SaveRepository: 文件存档(user://),纯逻辑可单测(base_dir 可注入)。
## 格式: JSON(RunState.to_dict);schema_version 预留在 from_dict 做版本迁移。

extends RefCounted

const RunState := preload("res://app/run_state.gd")


var base_dir := "user://saves"


func _init(dir: String = "") -> void:
	if dir != "":
		base_dir = dir


func _slot_path(slot: int) -> String:
	return base_dir + "/slot_%d.json" % slot


## 存档;slot 0 为自动槽。返回 {ok, error}
func save(run: RunState, slot: int = 0) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(base_dir)
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "cannot open %s: %s" % [_slot_path(slot), error_string(FileAccess.get_open_error())]}
	f.store_string(JSON.stringify(run.to_dict(), "\t"))
	f.close()
	return {"ok": true}


## 读取档;返回 {ok, run, error}
func load(slot: int = 0) -> Dictionary:
	if not has_save(slot):
		return {"ok": false, "error": "no save at slot %d" % slot}
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "cannot read %s" % _slot_path(slot)}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "corrupted save (not a JSON object)"}
	var r := RunState.new()
	r.load_dict(parsed)
	return {"ok": true, "run": r}


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: int = 0) -> void:
	DirAccess.remove_absolute(_slot_path(slot))
