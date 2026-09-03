## 开始界面: 新游戏/继续游戏入口。真正的游戏从 WorkshopScene 开始。
extends Control

var continue_button: Button
var settings_panel: PanelContainer
var message: Label


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	_build_ui()
	queue_redraw()


func _draw() -> void:
	# 低饱和深色底 + 手绘式铁匠铺剪影，避免把整张插画当作可走地图。
	draw_rect(Rect2(Vector2.ZERO, size), Color("151722"))
	draw_rect(Rect2(0, size.y * 0.62, size.x, size.y * 0.38), Color("201b25"))
	var roof := PackedVector2Array([
		Vector2(80, 470), Vector2(260, 270), Vector2(530, 270), Vector2(710, 470)])
	draw_colored_polygon(roof, Color("302b37"))
	draw_polyline(roof, Color("9a6846"), 5.0)
	draw_rect(Rect2(170, 450, 450, 180), Color("29212a"))
	draw_rect(Rect2(275, 505, 100, 125), Color("120f18"))
	draw_rect(Rect2(425, 505, 100, 125), Color("120f18"))
	# 火炉的三层发光色块，保持像素边缘。
	for r in [75.0, 54.0, 34.0]:
		draw_circle(Vector2(325, 470), r, Color(1.0, 0.35 + (75.0 - r) / 180.0, 0.08, 0.08))
	draw_rect(Rect2(288, 432, 74, 58), Color("6e3421"))
	draw_rect(Rect2(300, 442, 50, 46), Color("e45a22"))
	draw_rect(Rect2(312, 450, 26, 38), Color("ffc15a"))
	# 远处暖光窗户。
	for x in [230, 470]:
		draw_rect(Rect2(x, 390, 54, 42), Color("7d4f35"))
		draw_rect(Rect2(x + 8, 398, 38, 26), Color("d79345"))
	# 地面透视线。
	for i in range(7):
		var y := 650.0 + i * 18.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.32, 0.25, 0.27, 0.35), 2.0)
	# 标题区域的暗板，保证文字可读。
	draw_rect(Rect2(760, 170, 410, 390), Color(0.05, 0.05, 0.09, 0.78))
	draw_line(Vector2(760, 170), Vector2(1170, 170), Color("b8794d"), 2.0)


func _build_ui() -> void:
	var title := Label.new()
	title.text = "余火铁匠铺"
	title.position = Vector2(815, 215)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("f3c278"))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "锻造 · 神裁 · 出征"
	subtitle.position = Vector2(820, 275)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color("c7b9a0")
	add_child(subtitle)

	var menu := VBoxContainer.new()
	menu.position = Vector2(820, 345)
	menu.custom_minimum_size = Vector2(300, 0)
	menu.add_theme_constant_override("separation", 12)
	add_child(menu)

	var new_button := _menu_button("开始新游戏")
	new_button.pressed.connect(_on_new_game)
	menu.add_child(new_button)
	continue_button = _menu_button("继续游戏")
	continue_button.pressed.connect(_on_continue)
	menu.add_child(continue_button)
	var settings_button := _menu_button("设置")
	settings_button.pressed.connect(_toggle_settings)
	menu.add_child(settings_button)
	var quit_button := _menu_button("退出")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(quit_button)

	message = Label.new()
	message.position = Vector2(820, 555)
	message.custom_minimum_size = Vector2(330, 50)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.modulate = Color("c7b9a0")
	add_child(message)
	_refresh_continue()


func _menu_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(300, 46)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _refresh_continue() -> void:
	continue_button.disabled = not GameApp.has_save()
	continue_button.tooltip_text = "读取最近一次存档" if not continue_button.disabled else "暂无存档"


func _on_new_game() -> void:
	GameApp.new_game(Time.get_ticks_msec())
	GameApp.goto("workshop")


func _on_continue() -> void:
	if GameApp.continue_game():
		GameApp.goto("workshop")
	else:
		message.text = "没有可读取的存档。"


func _toggle_settings() -> void:
	if is_instance_valid(settings_panel):
		settings_panel.queue_free()
		settings_panel = null
		return
	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(710, 585)
	settings_panel.custom_minimum_size = Vector2(470, 90)
	add_child(settings_panel)
	var label := Label.new()
	var mode := str(GameApp.run.world_flags.get("god_mode", "scripted"))
	label.text = "神祇连接模式：%s\n详细 API 配置可在铁匠铺的神祇设置中调整。" % mode
	label.add_theme_font_size_override("font_size", 14)
	settings_panel.add_child(label)
