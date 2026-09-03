## 铁匠铺据点: 真实 2.5D / HD-2D 原型。
## 3D 地面、正交相机、灯光和阴影提供空间层次;角色使用像素 Sprite3D。
## 复杂操作由交互点打开既有全屏 UI,据点本身只负责移动、遮挡和剧情入口。
extends Node3D

const PLAYER_SPEED := 3.8
const WORLD_LIMIT := Vector2(7.0, 5.0)
const PLAYER_TEXTURE_SIZE := Vector2(32.0, 48.0)

var player: CharacterBody3D
var player_sprite: Sprite3D
var player_shadow: MeshInstance3D
var fire_light: OmniLight3D
var interactables: Array[Dictionary] = []
var prompt: Label
var toast: Label
var hud: Label
var god_settings_panel = null # 神祇设置面板(公共组件,含 saved 信号)
var _nearby_id := ""
var _toast_until := 0.0
var _mira_spoken := false


func _ready() -> void:
	_build_environment()
	_build_workshop()
	_build_player()
	_build_hud()
	_refresh_hud()


func _process(_delta: float) -> void:
	if fire_light != null:
		fire_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.009) * 0.18
	if _toast_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _toast_until:
		toast.text = ""
	_refresh_prompt()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		# 世界 X/Z 对应屏幕斜向移动，形成逸剑风云决式斜俯视感。
		player.position.x += direction.x * PLAYER_SPEED * delta
		player.position.z += direction.y * PLAYER_SPEED * delta
		player.position.x = clampf(player.position.x, -WORLD_LIMIT.x, WORLD_LIMIT.x)
		player.position.z = clampf(player.position.z, -WORLD_LIMIT.y, WORLD_LIMIT.y)
		player_sprite.flip_h = direction.x < 0.0
		player_sprite.position.y = 0.72 + sin(Time.get_ticks_msec() * 0.012) * 0.018
		player_shadow.position = Vector3(player.position.x, 0.035, player.position.z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			_interact()
		elif event.keycode == KEY_ESCAPE:
			GameApp.goto("start")


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("151722")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9a8a9b")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.0
	camera.position = Vector3(8.0, 8.5, 10.0)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("d9c5ae")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	add_child(sun)


func _build_workshop() -> void:
	# 地面是低多边形石板，保持材质块面而不是一张平面插画。
	_add_box("Floor", Vector3(16.0, 0.18, 12.0), Vector3(0.0, -0.1, 0.0), Color("4e463f"))
	_add_box("BackWall", Vector3(16.0, 3.2, 0.28), Vector3(0.0, 1.5, -5.7), Color("302c35"))
	_add_box("LeftWall", Vector3(0.28, 3.2, 11.5), Vector3(-7.8, 1.5, 0.0), Color("292833"))
	_add_box("RightWall", Vector3(0.28, 3.2, 11.5), Vector3(7.8, 1.5, 0.0), Color("292833"))

	# 后景木梁和屋顶层次。
	_add_box("BeamTop", Vector3(15.0, 0.28, 0.45), Vector3(0.0, 3.0, -5.45), Color("614936"))
	_add_box("BeamLeft", Vector3(0.32, 2.7, 0.45), Vector3(-5.5, 1.55, -5.42), Color("614936"))
	_add_box("BeamRight", Vector3(0.32, 2.7, 0.45), Vector3(5.5, 1.55, -5.42), Color("614936"))

	# 设施位置：交互位置与视觉物件分离，方便以后替换正式资源。
	_add_forge(Vector3(-4.7, 0.0, -3.9))
	_add_altar(Vector3(0.0, 0.0, -4.1))
	_add_weapon_rack(Vector3(4.4, 0.0, -3.7))
	_add_board(Vector3(-4.7, 0.0, 1.7), Color("986340"), "委托板")
	_add_board(Vector3(4.4, 0.0, 1.7), Color("65788b"), "地图桌")
	_add_npc(Vector3(-1.65, 0.0, 1.35))
	_add_exit(Vector3(0.0, 0.0, 4.8))

	interactables = [
		{"id": "forge", "position": Vector3(-3.6, 0.0, -2.9), "label": "铁砧 · 锻造"},
		{"id": "altar", "position": Vector3(0.0, 0.0, -3.0), "label": "神裁砧 · 交涉"},
		{"id": "armory", "position": Vector3(3.5, 0.0, -2.8), "label": "武器架 · 整装"},
		{"id": "orders", "position": Vector3(-3.6, 0.0, 1.0), "label": "委托板 · 订单"},
		{"id": "adventure", "position": Vector3(3.5, 0.0, 1.0), "label": "地图桌 · 出征"},
		{"id": "mira", "position": Vector3(-1.65, 0.0, 1.35), "label": "弥菈 · 对话"},
		{"id": "exit", "position": Vector3(0.0, 0.0, 4.0), "label": "门口 · 离开铁匠铺"},
	]


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.72, 2.6)
	add_child(player)
	player_sprite = Sprite3D.new()
	player_sprite.name = "PlayerSprite"
	player_sprite.texture = _make_player_texture()
	player_sprite.pixel_size = 0.03
	player_sprite.billboard = 2 # Y billboard: 面向镜头但保持站立
	player_sprite.shaded = true
	player_sprite.texture_filter = 1 # nearest
	player.add_child(player_sprite)
	player_shadow = _add_cylinder("PlayerShadow", Vector3(0.72, 0.04, 0.42), Vector3(player.position.x, 0.035, player.position.z), Color(0.04, 0.03, 0.04, 0.6))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0.05, 0.05, 0.08, 0.82)
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 60)
	layer.add_child(top)
	hud = Label.new()
	hud.position = Vector2(28, 14)
	hud.add_theme_font_size_override("font_size", 15)
	hud.modulate = Color("ead8b8")
	layer.add_child(hud)
	var title := Label.new()
	title.text = "铁匠铺"
	title.position = Vector2(1080, 14)
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("f0bd76")
	layer.add_child(title)
	# 神祇设置入口(公共组件,与开始界面/锻造台一致)
	var god_btn := Button.new()
	god_btn.text = "⚙ 神祇设置"
	god_btn.position = Vector2(1006, 42)
	god_btn.custom_minimum_size = Vector2(160, 0)
	god_btn.pressed.connect(_toggle_god_settings)
	layer.add_child(god_btn)
	god_settings_panel = preload("res://scenes/common/god_settings_panel.gd").new()
	god_settings_panel.position = Vector2(730, 90)
	god_settings_panel.visible = false
	layer.add_child(god_settings_panel)
	prompt = Label.new()
	prompt.position = Vector2(455, 635)
	prompt.custom_minimum_size = Vector2(370, 48)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.modulate = Color("ffe0a0")
	layer.add_child(prompt)
	toast = Label.new()
	toast.position = Vector2(28, 640)
	toast.add_theme_font_size_override("font_size", 14)
	toast.modulate = Color("b6c9d2")
	layer.add_child(toast)


func _refresh_hud() -> void:
	if hud == null or GameApp.run == null:
		return
	var Inventory := preload("res://domain/economy/inventory.gd")
	var rep := float(GameApp.run.world_flags.get("reputation", 0.0))
	hud.text = "第 %d 天   金币 %.0f   声望 %.0f   %s" % [GameApp.run.current_day, GameApp.run.money, rep, Inventory.describe(GameApp.run)]


func _refresh_prompt() -> void:
	if player == null or prompt == null:
		return
	var nearest := ""
	var nearest_label := ""
	var best := 1.15
	for item in interactables:
		var distance := player.position.distance_to(item.position)
		if distance < best:
			best = distance
			nearest = str(item.id)
			nearest_label = str(item.label)
	_nearby_id = nearest
	prompt.text = "[E]  " + nearest_label if nearest != "" else "WASD / 方向键移动 · 靠近设施按 E 互动"


func _interact() -> void:
	if _nearby_id == "":
		return
	match _nearby_id:
		"forge":
			GameApp.goto("forge")
		"altar":
			GameApp.goto("altar")
		"armory":
			GameApp.goto("armory")
		"adventure":
			GameApp.goto("expedition")
		"orders":
			var r := GameApp.run
			var weapon_count := r.weapons.size() if r != null and r.weapons != null else 0
			if weapon_count == 0:
				_show_toast("委托板空空如也——先在铁砧打一把武器,神明才会接下订单。")
			else:
				_show_toast("委托板: 带着武器出征验证机制,胜利会带来订单与酬劳。")
		"exit":
			GameApp.goto("start")
		"mira":
			if _mira_spoken:
				_show_toast("弥菈：先把第一件武器打出来，神明才会认真听。")
			else:
				_mira_spoken = true
				GameApp.run.world_flags["intro_mira_met"] = true
				_show_toast("弥菈：欢迎来到余火铁匠铺。铁砧在左边，出征地图还在等我们。")
		_:
			_show_toast("这里的功能正在准备中。")


func _show_toast(text_value: String) -> void:
	toast.text = text_value
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.2


func _toggle_god_settings() -> void:
	if god_settings_panel == null:
		return
	god_settings_panel.visible = not god_settings_panel.visible


func _add_forge(pos: Vector3) -> void:
	_add_box("ForgeBase", Vector3(2.2, 0.8, 1.3), pos + Vector3(0, 0.4, 0), Color("5e4b42"))
	_add_box("ForgeHood", Vector3(1.7, 1.4, 1.0), pos + Vector3(0, 1.4, -0.1), Color("39333a"))
	var coal := _add_box("ForgeFire", Vector3(0.75, 0.48, 0.12), pos + Vector3(0, 0.76, -0.56), Color("eb622e"))
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color("ff8844")
	fire_light.light_energy = 2.0
	fire_light.omni_range = 5.0
	fire_light.shadow_enabled = true
	fire_light.position = pos + Vector3(0, 1.2, -0.8)
	add_child(fire_light)
	_add_label("ForgeLabel", "铁砧", pos + Vector3(0, 2.35, 0), Color("ffd39a"))


func _add_altar(pos: Vector3) -> void:
	_add_cylinder("Altar", Vector3(1.0, 0.28, 1.0), pos + Vector3(0, 0.18, 0), Color("6f6687"))
	_add_box("AltarStone", Vector3(0.7, 0.6, 0.7), pos + Vector3(0, 0.62, 0), Color("8f82a4"))
	_add_label("AltarLabel", "神裁砧", pos + Vector3(0, 1.55, 0), Color("d0c1ef"))


func _add_weapon_rack(pos: Vector3) -> void:
	_add_box("Rack", Vector3(2.4, 1.9, 0.35), pos + Vector3(0, 0.95, 0), Color("684a37"))
	for x in [-0.7, 0.0, 0.7]:
		_add_box("RackWeapon", Vector3(0.1, 1.2, 0.1), pos + Vector3(x, 1.2, -0.28), Color("b88b54"))
	_add_label("RackLabel", "武器架", pos + Vector3(0, 2.25, 0), Color("f0d19a"))


func _add_board(pos: Vector3, color: Color, label_text: String) -> void:
	_add_box(label_text, Vector3(1.7, 1.7, 0.25), pos + Vector3(0, 0.85, 0), color)
	_add_box(label_text + "Post", Vector3(0.16, 1.0, 0.3), pos + Vector3(-0.65, 0.5, 0), Color("4c382c"))
	_add_box(label_text + "Post2", Vector3(0.16, 1.0, 0.3), pos + Vector3(0.65, 0.5, 0), Color("4c382c"))
	_add_label(label_text + "Label", label_text, pos + Vector3(0, 2.0, 0), Color("d8d2c2"))


func _add_exit(pos: Vector3) -> void:
	_add_box("ExitDoor", Vector3(1.8, 2.6, 0.3), pos + Vector3(0, 1.3, -0.1), Color("352b35"))
	_add_box("ExitGlow", Vector3(1.1, 1.8, 0.08), pos + Vector3(0, 1.1, -0.28), Color("6e5261"))
	_add_label("ExitLabel", "出口", pos + Vector3(0, 2.9, 0), Color("c6b7be"))


func _add_npc(pos: Vector3) -> void:
	var npc := Node3D.new()
	npc.name = "Mira"
	npc.position = pos
	add_child(npc)
	var sprite := Sprite3D.new()
	sprite.name = "MiraSprite"
	sprite.texture = _make_player_texture()
	sprite.modulate = Color("d9a2c1")
	sprite.pixel_size = 0.03
	sprite.billboard = 2
	sprite.shaded = true
	sprite.texture_filter = 1
	npc.add_child(sprite)
	_add_label("MiraLabel", "弥菈", pos + Vector3(0, 1.65, 0), Color("f0b9d5"))


func _add_label(node_name: String, text_value: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text_value
	label.position = pos
	label.modulate = color
	label.font_size = 32
	label.outline_size = 8
	label.outline_modulate = Color(0.05, 0.04, 0.06, 0.85)
	label.billboard = 1
	add_child(label)


func _add_box(node_name: String, box_size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	add_child(node)
	return node


func _add_cylinder(node_name: String, dimensions: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = dimensions.x * 0.5
	mesh.bottom_radius = dimensions.x * 0.5
	mesh.height = dimensions.y
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.scale.z = dimensions.z / maxf(dimensions.x, 0.01)
	node.position = pos
	node.material_override = _material(color)
	add_child(node)
	return node


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _make_player_texture() -> Texture2D:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var skin := Color("dca982")
	var coat := Color("3f6c82")
	var apron := Color("c58b52")
	var dark := Color("1d2430")
	var boot := Color("3b2a2b")
	# 32x48 的块面像素人：头、围裙、手臂、靴子和锤子。
	_fill_pixels(image, Rect2i(11, 5, 10, 9), skin)
	_fill_pixels(image, Rect2i(9, 3, 14, 4), dark)
	_fill_pixels(image, Rect2i(8, 14, 16, 15), coat)
	_fill_pixels(image, Rect2i(11, 17, 10, 16), apron)
	_fill_pixels(image, Rect2i(6, 16, 4, 13), coat)
	_fill_pixels(image, Rect2i(22, 16, 4, 13), coat)
	_fill_pixels(image, Rect2i(10, 29, 5, 14), dark)
	_fill_pixels(image, Rect2i(17, 29, 5, 14), dark)
	_fill_pixels(image, Rect2i(8, 41, 8, 4), boot)
	_fill_pixels(image, Rect2i(16, 41, 8, 4), boot)
	_fill_pixels(image, Rect2i(24, 22, 7, 3), Color("b9c1c2"))
	_fill_pixels(image, Rect2i(29, 20, 3, 7), Color("d9a45a"))
	return ImageTexture.create_from_image(image)


func _fill_pixels(image: Image, rect: Rect2i, color: Color) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			image.set_pixel(x, y, color)
