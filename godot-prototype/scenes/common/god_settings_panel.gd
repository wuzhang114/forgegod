## 神祇设置面板(开始界面 / 铁匠铺 / 锻造台共用)。
## 决定交涉时由谁裁决: 内置脚本神 / 本地 AI / 云端 AI。
## 保存后立即探测连接,成功则预加载神裁上下文;失败自动回退脚本神。
extends PanelContainer

signal saved(mode: String)

var mode_select: OptionButton
var local_endpoint_edit: LineEdit
var local_key_edit: LineEdit
var local_model_edit: LineEdit
var remote_endpoint_edit: LineEdit
var remote_key_edit: LineEdit
var remote_model_edit: LineEdit
var tip_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.07, 0.06, 0.1, 0.95)
	frame.border_color = Color(0.72, 0.47, 0.3)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(6)
	frame.content_margin_left = 18.0
	frame.content_margin_right = 18.0
	frame.content_margin_top = 14.0
	frame.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", frame)
	_build_fields()


func _build_fields() -> void:
	var GodConfig = preload("res://adapters/negotiation/god_config.gd")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)

	var title := Label.new()
	title.text = "⚙ 神祇设置(决定交涉时由谁裁决)"
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.9, 0.75, 0.5)
	v.add_child(title)
	v.add_child(Label.new())

	# 模式
	var mode_row := HBoxContainer.new()
	var mode_lbl := Label.new()
	mode_lbl.text = "神祇"
	mode_lbl.custom_minimum_size = Vector2(84, 0)
	mode_row.add_child(mode_lbl)
	mode_select = OptionButton.new()
	mode_select.add_item("脚本神(内置,离线可用)", 0)
	mode_select.add_item("本地 AI(填端点 + 密钥)", 1)
	mode_select.add_item("云端 AI(填端点 + 密钥)", 2)
	mode_select.custom_minimum_size = Vector2(300, 0)
	mode_row.add_child(mode_select)
	v.add_child(mode_row)
	v.add_child(Label.new())

	# 本地 AI
	v.add_child(_field_label("本地 AI 端点(OpenAI 兼容 /chat/completions)"))
	local_endpoint_edit = LineEdit.new()
	v.add_child(local_endpoint_edit)
	v.add_child(_field_label("本地模型名"))
	local_model_edit = LineEdit.new()
	local_model_edit.placeholder_text = "如 qwen2.5:7b"
	v.add_child(local_model_edit)
	v.add_child(_field_label("本地密钥"))
	local_key_edit = LineEdit.new()
	local_key_edit.secret = true
	v.add_child(local_key_edit)
	v.add_child(Label.new())

	# 云端 AI
	v.add_child(_field_label("云端 AI 端点"))
	remote_endpoint_edit = LineEdit.new()
	v.add_child(remote_endpoint_edit)
	v.add_child(_field_label("云端模型名"))
	remote_model_edit = LineEdit.new()
	remote_model_edit.placeholder_text = "如 deepseek-chat"
	v.add_child(remote_model_edit)
	v.add_child(_field_label("云端密钥"))
	remote_key_edit = LineEdit.new()
	remote_key_edit.secret = true
	v.add_child(remote_key_edit)
	v.add_child(Label.new())

	# 保存并检测 / 关闭
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var save := Button.new()
	save.text = "💾 保存并检测连接"
	save.pressed.connect(_on_save_pressed)
	row.add_child(save)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void: hide())
	row.add_child(close)
	v.add_child(row)

	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(0, 20)
	tip_label.modulate = Color(0.85, 0.82, 0.72)
	v.add_child(tip_label)

	# 载入现有配置
	var c: Dictionary = GodConfig.load_config()
	mode_select.selected = ["scripted", "local", "remote"].find(str(c.get("god_mode", "scripted")))
	local_endpoint_edit.text = str(c.get("local_endpoint", ""))
	local_key_edit.text = str(c.get("local_key", ""))
	local_model_edit.text = str(c.get("local_model", ""))
	remote_endpoint_edit.text = str(c.get("remote_endpoint", ""))
	remote_key_edit.text = str(c.get("remote_key", ""))
	remote_model_edit.text = str(c.get("remote_model", ""))


func _field_label(text_value: String) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = Color(0.78, 0.74, 0.64)
	return l


func _on_save_pressed() -> void:
	var GodConfig = preload("res://adapters/negotiation/god_config.gd")
	var mode: String = ["scripted", "local", "remote"][mode_select.selected]
	var cfg := {
		"god_mode": mode,
		"local_endpoint": local_endpoint_edit.text.strip_edges(),
		"local_key": local_key_edit.text.strip_edges(),
		"local_model": local_model_edit.text.strip_edges(),
		"remote_endpoint": remote_endpoint_edit.text.strip_edges(),
		"remote_key": remote_key_edit.text.strip_edges(),
		"remote_model": remote_model_edit.text.strip_edges(),
	}
	var res: Dictionary = GodConfig.save_config(cfg)
	if not res.get("ok", false):
		tip_label.text = "保存失败: %s" % str(res.get("error", "?"))
		return
	if GameApp.run != null:
		GameApp.run.world_flags["god_mode"] = GodConfig.effective_mode(cfg)
	if mode == "scripted":
		tip_label.text = "神祇配置已保存 ✓(内置脚本神,无需网络)"
		saved.emit(mode)
		return
	# 立即检测连接 + 预加载神裁上下文(避免交涉首轮卡顿)
	var endpoint := str(cfg.local_endpoint if mode == "local" else cfg.remote_endpoint)
	var key := str(cfg.local_key if mode == "local" else cfg.remote_key)
	var model := str(cfg.local_model if mode == "local" else cfg.remote_model)
	tip_label.text = "检测「%s」连接中(最长 5 秒)…" % endpoint
	await get_tree().process_frame
	var HttpProbe = preload("res://adapters/negotiation/http_probe.gd")
	var pr: Dictionary = HttpProbe.probe(endpoint, key, model)
	if pr.get("ok", false):
		if GameApp.run != null:
			var Session = preload("res://core/flow/game_session.gd")
			var LocalAdapter = preload("res://adapters/negotiation/local_ai_adapter.gd")
			LocalAdapter.new().prepare_context(Session.weapon_facts)
			GameApp.run.world_flags["god_ctx_ready"] = true
		tip_label.text = "连接成功 ✓ 延迟 %.0fms,神裁上下文已预加载" % float(pr.latency_ms)
	else:
		if GameApp.run != null:
			GameApp.run.world_flags["god_mode"] = "scripted"
		tip_label.text = "连接失败: %s(已回退脚本神,可修改后重试)" % str(pr.get("error", "?"))
	saved.emit(mode)
