## GodConfig: 神祇配置(API 端点/密钥/模式),存 user://god_config.json。
## 开始界面填写,LocalAI/RemoteAI 适配器运行时读取。

extends RefCounted

const PATH := "user://god_config.json"
## 测试可注入(避免污染真实配置)
static var override_path := ""

const DEFAULTS := {
	"god_mode": "scripted",        # scripted | local | remote
	"local_endpoint": "",
	"local_key": "",
	"local_model": "",
	"remote_endpoint": "",
	"remote_key": "",
	"remote_model": "",
}


static func _path() -> String:
	return override_path if override_path != "" else PATH


static func load_config() -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(_path()):
		return out
	var f := FileAccess.open(_path(), FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for k in DEFAULTS.keys():
		out[k] = parsed.get(k, DEFAULTS[k])
	return out


## 保存;返回 {ok, error}
static func save_config(cfg: Dictionary) -> Dictionary:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "cannot write %s" % _path()}
	f.store_string(JSON.stringify(cfg, "\t"))
	f.close()
	return {"ok": true}


## 从配置构建运行时模式(密钥未填 -> 自动回落脚本神)
static func effective_mode(cfg: Dictionary) -> String:
	var mode := str(cfg.get("god_mode", "scripted"))
	if mode == "local" and str(cfg.get("local_key", "")).strip_edges() == "":
		return "scripted"
	if mode == "remote" and str(cfg.get("remote_key", "")).strip_edges() == "":
		return "scripted"
	return mode if mode in ["scripted", "local", "remote"] else "scripted"
