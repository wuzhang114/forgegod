## 锻造面板场景 v2(四页签 · 顺序流程 · 事实卡右侧) —— M1 上游。
## 运行: godot --path godot-prototype scenes/forge/forge_scene.tscn
## 流程: 熔炼(确定) → 锻打(确定) → 热处理(确定) → 装配(完成) → 可重新锻造。
## 已确认阶段回看只读; 底栏事实卡移至右侧栏(不遮挡)。

extends Node2D

const Forge := preload("res://core/forge/forge_core.gd")
const ForgeCalculator := preload("res://domain/weapon/forge_calculator.gd")

const STAGES := [
	{"id": "melt", "name": "① 熔炼"},
	{"id": "smith", "name": "② 锻打"},
	{"id": "temper", "name": "③ 热处理"},
	{"id": "assemble", "name": "④ 装配"},
]
const KIND_CHOICES := [
	{"id": "warhammer", "name": "战锤"},
	{"id": "longsword", "name": "长剑"},
	{"id": "bow", "name": "弓"},
]
const MATERIAL_IDS := ["grey_iron", "red_copper", "blackwood", "beast_bone", "star_iron", "silverwood", "void_ore", "frost_steel"]
const QUENCH_IDS := ["water", "oil", "salt", "beast_oil", "moon"]
const TECHNIQUES := ["folded", "clad_steel", "grooved", "runeslot"]
const TECH_NAMES := {"folded": "折叠", "clad_steel": "夹钢", "grooved": "分段", "runeslot": "符槽"}
const MAT_COLOR := {
	"grey_iron": Color(0.62, 0.62, 0.66), "red_copper": Color(0.78, 0.42, 0.32),
	"blackwood": Color(0.3, 0.24, 0.18), "beast_bone": Color(0.85, 0.82, 0.72),
	"star_iron": Color(0.5, 0.55, 0.75), "silverwood": Color(0.78, 0.78, 0.6),
	"void_ore": Color(0.4, 0.28, 0.5), "frost_steel": Color(0.62, 0.78, 0.9),
}

var stage := "melt"                     # 当前可编辑阶段
var done_stages: Array = []             # 已确认阶段(可回看只读)
var kind := "warhammer"
var parts := {"action": "grey_iron", "bearing": "grey_iron", "control": "grey_iron", "medium": "grey_iron"}
var size := {"length": 0.6, "thickness": 0.5, "balance": 0.5}
var purity_roll := 0.6
var quench := "water"
var temper := false
var keep_stress := false
var balance_bias := false
var techniques: Array = []
var weapon_name := "无名武器"

var ui: Dictionary = {}
var rows: Dictionary = {}               # stage_id -> [控件]
var result_weapon := {}

const PANEL := Rect2(120, 90, 440, 330)
const RIGHT := Vector2(610, 64)
const FACTS := Rect2(610, 370, 580, 320)


func _ready() -> void:
	_build_static()
	_rebuild_right()
	_update_facts()
	_refresh_center()
	_build_run_bar()
	_build_god_panel()
	# 未配置 AI 神时提示(开始界面引导)
	var GodConfig := preload("res://adapters/negotiation/god_config.gd")
	if str(GodConfig.effective_mode(GodConfig.load_config())) == "scripted":
		ui.tip.text = "提示: 神祇当前为内置脚本;点击右上「⚙ 神祇设置」可接入本地/云端 AI"


## ---------------- 运行控制条(新游戏/继续/存档) ----------------

func _build_run_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(880, 20)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	var mk := func(txt: String, cb: Callable) -> void:
		var b := Button.new()
		b.text = txt
		b.pressed.connect(cb)
		bar.add_child(b)
	mk.call("💾 存档", func():
		var res := GameApp.save_game()
		ui.tip.text = "已存档 ✓" if res.get("ok", false) else "存档失败: %s" % str(res.get("error", "?")))
	mk.call("📂 继续", func():
		if GameApp.continue_game():
			ui.tip.text = "已读取存档(第 %d 天)" % GameApp.run.current_day
			_refresh_center()
		else:
			ui.tip.text = "没有存档")
	mk.call("🌱 新游戏", func():
		GameApp.new_game()
		_refresh_runinfo()
		ui.tip.text = "新局已开(第 1 天)")
	mk.call("⚙ 神祇设置", func():
		ui.god_panel.visible = not ui.god_panel.visible)
	# 运行信息(经济/队伍;RunState 唯一来源)
	ui.runinfo = Label.new()
	ui.runinfo.position = Vector2(400, 20)
	ui.runinfo.add_theme_font_size_override("font_size", 14)
	ui.runinfo.modulate = Color(0.85, 0.9, 0.8)
	add_child(ui.runinfo)
	_refresh_runinfo()


func _refresh_runinfo() -> void:
	var Inventory := preload("res://domain/economy/inventory.gd")
	var r := GameApp.run
	var rep := float(r.world_flags.get("reputation", 0.0))
	ui.runinfo.text = "第 %d 天 · 金币 %.0f · 声望 %.0f · %s" % [
		r.current_day, r.money, rep, Inventory.describe(r)]


## ---------------- 神祇设置面板(开始界面填写 API) ----------------

func _build_god_panel() -> void:
	var GodConfig := preload("res://adapters/negotiation/god_config.gd")
	var Panel := PanelContainer.new()
	Panel.position = Vector2(390, 150)
	Panel.custom_minimum_size = Vector2(500, 360)
	add_child(Panel)
	var v := VBoxContainer.new()
	Panel.add_child(v)
	var title := Label.new()
	title.text = "神祇设置(决定交涉时由谁裁决)"
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.9, 0.75, 0.5)
	v.add_child(title)
	v.add_child(Label.new())
	# 模式
	var mode_row := HBoxContainer.new()
	mode_row.add_child(Label.new())
	var mode_lbl := Label.new()
	mode_lbl.text = "神祇: "
	mode_lbl.custom_minimum_size = Vector2(90, 0)
	mode_row.add_child(mode_lbl)
	ui.god_mode = OptionButton.new()
	ui.god_mode.add_item("脚本神(内置,无需网络)", 0)
	ui.god_mode.add_item("本地 AI(填写端点+密钥)", 1)
	ui.god_mode.add_item("云端 AI(填写端点+密钥)", 2)
	mode_row.add_child(ui.god_mode)
	v.add_child(mode_row)
	v.add_child(Label.new())
	# 本地 AI
	var l1 := Label.new()
	l1.text = "本地 AI 端点(OpenAI 兼容 /v1/chat/completions)"
	v.add_child(l1)
	ui.local_endpoint = LineEdit.new()
	v.add_child(ui.local_endpoint)
	var l1b := Label.new()
	l1b.text = "本地模型名"
	v.add_child(l1b)
	ui.local_model = LineEdit.new()
	ui.local_model.placeholder_text = "如 qwen2.5:7b"
	v.add_child(ui.local_model)
	var l2 := Label.new()
	l2.text = "本地 AI 密钥"
	v.add_child(l2)
	ui.local_key = LineEdit.new()
	ui.local_key.secret = true
	v.add_child(ui.local_key)
	v.add_child(Label.new())
	# 云端 AI
	var l3 := Label.new()
	l3.text = "云端 AI 端点"
	v.add_child(l3)
	ui.remote_endpoint = LineEdit.new()
	v.add_child(ui.remote_endpoint)
	var l3b := Label.new()
	l3b.text = "云端模型名"
	v.add_child(l3b)
	ui.remote_model = LineEdit.new()
	ui.remote_model.placeholder_text = "如 deepseek-chat"
	v.add_child(ui.remote_model)
	var l4 := Label.new()
	l4.text = "云端 AI 密钥"
	v.add_child(l4)
	ui.remote_key = LineEdit.new()
	ui.remote_key.secret = true
	v.add_child(ui.remote_key)
	# 保存
	var save_row := HBoxContainer.new()
	var save := Button.new()
	save.text = "💾 保存并检测连接"
	save.pressed.connect(func():
		var mode: String = ["scripted", "local", "remote"][ui.god_mode.selected]
		var cfg := {
			"god_mode": mode,
			"local_endpoint": ui.local_endpoint.text.strip_edges(),
			"local_key": ui.local_key.text.strip_edges(),
			"local_model": ui.local_model.text.strip_edges(),
			"remote_endpoint": ui.remote_endpoint.text.strip_edges(),
			"remote_key": ui.remote_key.text.strip_edges(),
			"remote_model": ui.remote_model.text.strip_edges(),
		}
		var res := GodConfig.save_config(cfg)
		if not res.get("ok", false):
			ui.tip.text = "保存失败: %s" % str(res.get("error", "?"))
			return
		GameApp.run.world_flags["god_mode"] = GodConfig.effective_mode(cfg)
		if mode == "scripted":
			ui.tip.text = "神祇配置已保存 ✓(内置脚本神)"
			return
		# 立即检测连接 + 预加载神裁上下文(避免交涉时首轮卡顿)
		var endpoint := str(cfg.local_endpoint if mode == "local" else cfg.remote_endpoint)
		var key := str(cfg.local_key if mode == "local" else cfg.remote_key)
		var model := str(cfg.local_model if mode == "local" else cfg.remote_model)
		ui.tip.text = "检测「%s」连接中(最长 5 秒)…" % endpoint
		await get_tree().process_frame
		var HttpProbe := preload("res://adapters/negotiation/http_probe.gd")
		var pr := HttpProbe.probe(endpoint, key, model)
		if pr.get("ok", false):
			var Session := preload("res://core/flow/game_session.gd")
			var LocalAdapter := preload("res://adapters/negotiation/local_ai_adapter.gd")
			LocalAdapter.new().prepare_context(Session.weapon_facts)
			GameApp.run.world_flags["god_ctx_ready"] = true
			ui.tip.text = "连接成功 ✓ 延迟 %.0fms,神裁上下文已预加载" % float(pr.latency_ms)
		else:
			GameApp.run.world_flags["god_mode"] = "scripted"
			ui.tip.text = "连接失败: %s(已回退脚本神,可修改后重试)" % str(pr.get("error", "?")))
	save_row.add_child(save)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func(): Panel.visible = false)
	save_row.add_child(close)
	v.add_child(save_row)
	# 载入现有配置
	var c := GodConfig.load_config()
	ui.god_mode.selected = ["scripted", "local", "remote"].find(str(c.get("god_mode", "scripted")))
	ui.local_endpoint.text = str(c.get("local_endpoint", ""))
	ui.local_key.text = str(c.get("local_key", ""))
	ui.local_model.text = str(c.get("local_model", ""))
	ui.remote_endpoint.text = str(c.get("remote_endpoint", ""))
	ui.remote_key.text = str(c.get("remote_key", ""))
	ui.remote_model.text = str(c.get("remote_model", ""))
	ui.god_panel = Panel
	ui.god_panel.visible = false


## ---------------- 静态 UI ----------------

func _build_static() -> void:
	ui = {}
	var t := Label.new()
	t.text = "余火铁匠铺 · 锻造台"
	t.position = Vector2(120, 24)
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
	add_child(t)
	ui.tip = Label.new()
	ui.tip.position = Vector2(120, 48)
	ui.tip.add_theme_font_size_override("font_size", 13)
	ui.tip.modulate = Color(0.8, 0.8, 0.75)
	add_child(ui.tip)
	# 进度指示
	ui.progress = Label.new()
	ui.progress.position = Vector2(120, 56)
	ui.progress.add_theme_font_size_override("font_size", 14)
	add_child(ui.progress)
	# 页签
	var x := 120.0
	for st in STAGES:
		var b := Button.new()
		b.text = st.name
		b.position = Vector2(x, 82)
		b.custom_minimum_size = Vector2(92, 28)
		b.pressed.connect(func(): _on_tab_clicked(st.id))
		add_child(b)
		ui["tab_" + st.id] = b
		x += 98.0
	# 中央工件面板
	var center := PanelContainer.new()
	center.position = PANEL.position
	center.custom_minimum_size = PANEL.size
	add_child(center)
	ui.info = Label.new()
	ui.info.position = PANEL.position + Vector2(6, 302)
	ui.info.add_theme_font_size_override("font_size", 13)
	add_child(ui.info)
	# 右栏控件区(下移,给属性面板让位)
	var right := VBoxContainer.new()
	right.position = Vector2(610, 64)
	right.custom_minimum_size = Vector2(580, 220)
	add_child(right)
	ui.right = right
	# 右上: 基础属性面板(实时)
	_build_stats_panel()
	# 页签下"确定/下一步"按钮
	ui.next_btn = Button.new()
	ui.next_btn.position = Vector2(RIGHT.x, 320)
	ui.next_btn.custom_minimum_size = Vector2(580, 34)
	ui.next_btn.pressed.connect(_on_next)
	add_child(ui.next_btn)
	# 事实卡(右侧下层, ScrollContainer;只垂直滚动,Label 占满宽度)
	var sc := ScrollContainer.new()
	sc.position = FACTS.position
	sc.custom_minimum_size = FACTS.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	ui.facts = Label.new()
	ui.facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.facts.custom_minimum_size = Vector2(FACTS.size.x - 26, 0)
	ui.facts.add_theme_font_size_override("font_size", 12)
	ui.facts.modulate = Color(0.92, 0.92, 0.92)
	sc.add_child(ui.facts)
	# 左下: 武器名 + 基础属性 + 结果(完成后显示)
	var name_label := Label.new()
	name_label.text = "武器名"
	name_label.position = Vector2(120, 432)
	add_child(name_label)
	var name_box := LineEdit.new()
	name_box.text = weapon_name
	name_box.position = Vector2(120, 454)
	name_box.custom_minimum_size = Vector2(200, 30)
	name_box.text_changed.connect(func(txt: String): weapon_name = txt)
	add_child(name_box)
	ui.name_box = name_box
	ui.result = Label.new()
	ui.result.position = Vector2(120, 676)
	ui.result.custom_minimum_size = Vector2(440, 42)
	ui.result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.result.add_theme_font_size_override("font_size", 13)
	ui.result.modulate = Color(0.85, 0.95, 0.85)
	add_child(ui.result)
	ui.reset_btn = Button.new()
	ui.reset_btn.text = "重新锻造"
	ui.reset_btn.position = Vector2(330, 454)
	ui.reset_btn.custom_minimum_size = Vector2(200, 30)
	ui.reset_btn.pressed.connect(_reset)
	ui.reset_btn.visible = false
	add_child(ui.reset_btn)


## ---------------- 右栏控件(当前阶段) ----------------

func _rebuild_right() -> void:
	for c in ui.right.get_children():
		c.queue_free()
	rows = {}
	_build_melt()
	_build_smith()
	_build_temper()
	_build_assemble()
	_apply_stage_ui()


func _row(parent: Control, stage_id: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(580, 32)
	parent.add_child(h)
	if not rows.has(stage_id):
		rows[stage_id] = []
	rows[stage_id].append(h)
	return h


func _opt_row(stage_id: String, label: String, options: Array, cur: Callable, cb: Callable) -> void:
	var h := _row(ui.right, stage_id)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(108, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	for o in options:
		opt.add_item(str(o))
	opt.selected = cur.call()
	opt.item_selected.connect(func(idx: int): cb.call(idx))
	opt.set_meta("stage", stage_id)
	h.add_child(opt)
	rows[stage_id].append(opt)


func _slider_row(stage_id: String, label: String, val: float, cb: Callable, meta_key: String) -> void:
	var h := _row(ui.right, stage_id)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(108, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(300, 20)
	s.value_changed.connect(func(v: float): cb.call(v, meta_key))
	s.set_meta("stage", stage_id)
	h.add_child(s)
	var v := Label.new()
	v.text = "%.2f" % val
	s.value_changed.connect(func(v2: float): v.text = "%.2f" % v2)
	h.add_child(v)
	rows[stage_id].append(s)


func _checkbox_row(stage_id: String, label: String, initial: bool, cb: Callable) -> void:
	var h := _row(ui.right, stage_id)
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = initial
	c.toggled.connect(func(on: bool): cb.call(on))
	c.set_meta("stage", stage_id)
	h.add_child(c)
	rows[stage_id].append(c)


func _build_melt() -> void:
	_opt_row("melt", "武器类型", KIND_CHOICES.map(func(k): return k.name),
		func(): return _kind_idx(),
		func(idx: int): kind = KIND_CHOICES[idx].id; _refresh_center(); _update_facts())
	for role in ["action", "bearing", "control", "medium"]:
		var rname: String = {"action": "作用部件", "bearing": "承力部件", "control": "操控部件", "medium": "媒介部件"}[role]
		_opt_row("melt", rname, MATERIAL_IDS.map(func(m): return Forge.MATERIALS[m].name),
			func(): return MATERIAL_IDS.find(parts[role]),
			func(idx: int): parts[role] = MATERIAL_IDS[idx]; _update_facts(); _refresh_center())
	_slider_row("melt", "熔炼把握", purity_roll,
		func(v: float, _k: String): purity_roll = v; _update_facts(); _refresh_center(), "purity")


func _build_smith() -> void:
	_slider_row("smith", "长度", size.length, func(v: float, k: String): size[k] = v; _update_facts(); _refresh_center(), "length")
	_slider_row("smith", "厚度", size.thickness, func(v: float, k: String): size[k] = v; _update_facts(); _refresh_center(), "thickness")
	_slider_row("smith", "配重", size.balance, func(v: float, k: String): size[k] = v; _update_facts(); _refresh_center(), "balance")
	var h := _row(ui.right, "smith")
	var l := Label.new()
	l.text = "技法"
	l.custom_minimum_size = Vector2(108, 0)
	h.add_child(l)
	var opt := OptionButton.new()
	opt.add_item("无")
	for tc in TECHNIQUES:
		opt.add_item(TECH_NAMES[tc])
	opt.selected = 0
	opt.item_selected.connect(func(idx: int):
		techniques = [TECHNIQUES[idx - 1]] if idx > 0 else []
		_update_facts(); _refresh_center())
	opt.set_meta("stage", "smith")
	h.add_child(opt)
	rows["smith"].append(opt)
	_checkbox_row("smith", "保留应力(故意裂纹,危险契约门票)", keep_stress,
		func(on: bool): keep_stress = on; _update_facts(); _refresh_center())


func _build_temper() -> void:
	_opt_row("temper", "淬火介质", QUENCH_IDS.map(func(q): return Forge.QUENCH_MEDIA[q].label),
		func(): return QUENCH_IDS.find(quench),
		func(idx: int): quench = QUENCH_IDS[idx]; _update_facts(); _refresh_center())
	_checkbox_row("temper", "回火(牺牲硬度换韧性)", temper,
		func(on: bool): temper = on; _update_facts(); _refresh_center())


func _build_assemble() -> void:
	_slider_row("assemble", "重心", size.balance,
		func(v: float, k: String): size[k] = v; _update_facts(); _refresh_center(), "balance")
	_checkbox_row("assemble", "故意偏置(操控下降,部分动作收益)", balance_bias,
		func(on: bool): balance_bias = on; _update_facts(); _refresh_center())


## ---------------- 基础属性面板(实时;唯一来源 ForgeCalculator) ----------------

func _build_stats_panel() -> void:
	ui.stats_holder = VBoxContainer.new()
	ui.stats_holder.position = Vector2(120, 494)
	ui.stats_holder.custom_minimum_size = Vector2(440, 170)
	add_child(ui.stats_holder)
	ui.stats = {}
	var title := Label.new()
	title.text = "基础属性"
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color(1.0, 0.8, 0.6)
	ui.stats_holder.add_child(title)
	for key in ["攻击", "坚韧", "速度", "操控", "导能", "稳定"]:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = key
		l.custom_minimum_size = Vector2(56, 0)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.custom_minimum_size = Vector2(260, 14)
		bar.show_percentage = false
		var v := Label.new()
		v.text = "0"
		v.custom_minimum_size = Vector2(34, 0)
		h.add_child(l)
		h.add_child(bar)
		h.add_child(v)
		ui.stats_holder.add_child(h)
		ui.stats[key] = {"bar": bar, "label": v}
	# 战斗换算(预览 == 战斗同通道;面板所见即战斗所用)
	ui.combat = Label.new()
	ui.combat.add_theme_font_size_override("font_size", 12)
	ui.combat.modulate = Color(0.75, 0.9, 0.75)
	ui.stats_holder.add_child(ui.combat)


func _stats() -> Dictionary:
	# 唯一归属: ForgeCalculator.material_preview(公式不再在此散落第二套)
	return ForgeCalculator.material_preview(parts, size)


func _update_stats() -> void:
	if not ui.has("stats"):
		return
	var s := _stats()
	for k in s.keys():
		if not ui.stats.has(k):
			continue
		ui.stats[k].bar.value = float(s[k])
		ui.stats[k].label.text = str(s[k])
	# 战斗换算(预览 == 战斗同一 build 通道;面板数值 = 战斗生效数值)
	var craft_choices := {"purity_roll": purity_roll, "quench": quench, "temper": temper,
		"keep_stress": keep_stress, "techniques": techniques, "balance_bias": balance_bias,
		"style": "steady"}
	var preview := ForgeCalculator.preview_build("preview", kind, parts, size, craft_choices)
	var cs := ForgeCalculator.combat_summary(preview)
	if ui.has("combat"):
		var txt: Array = []
		for k in ["攻×", "暴×", "破甲+", "独立+", "耐久", "攻速×"]:
			txt.append("%s %s" % [k, str(cs[k])])
		ui.combat.text = "战斗换算: " + " · ".join(txt)
		if (cs.get("缺陷", []) as Array).size() > 0:
			ui.combat.text += "\n缺陷: " + "、".join(cs.get("缺陷", []))


## ---------------- 流程控制 ----------------

func _on_tab_clicked(t: String) -> void:
	if t in done_stages:
		stage = t          # 回看已确认(只读)
	elif t == stage:
		pass               # 当前阶段
	else:
		return             # 未解锁,不允许
	_apply_stage_ui()
	_refresh_center()


func _on_next() -> void:
	# 已完成全部阶段 -> 消耗材料 -> 入库(装备在神裁后的武装间决定)
	if _is_finished() and not result_weapon.is_empty():
		var Settlement := preload("res://application/settle_day.gd")
		var Inventory := preload("res://domain/economy/inventory.gd")
		if not Settlement.can_forge(GameApp.run):
			ui.tip.text = "材料不足(需铁矿石×1 + 煤×1),先去回收吧"
			return
		Inventory.consume(GameApp.run, Settlement.FORGE_COST)
		_refresh_runinfo()
		var Session := preload("res://core/flow/game_session.gd")
		Session.weapon_facts = result_weapon
		# 武器入库(未装配;神裁后到"武装间"决定持有者)
		var instance := {"instance_id": "w_%d_%s" % [GameApp.run.current_day, Time.get_ticks_msec()],
			"facts": result_weapon, "durability": 100.0, "contracts": [], "holder_id": ""}
		GameApp.run.weapons.append(instance)
		Session.weapon_instance_id = str(instance.instance_id)
		GameApp.goto("altar")
		return
	# 确定当前阶段
	if not stage in done_stages:
		done_stages.append(stage)
	# 进入下一阶段或完成
	var idx := 0
	for i in STAGES.size():
		if STAGES[i].id == stage:
			idx = i
			break
	if idx + 1 < STAGES.size():
		stage = STAGES[idx + 1].id
	else:
		_finish()
		_apply_stage_ui()
		return
	_apply_stage_ui()
	_refresh_center()


func _finish() -> void:
	result_weapon = Forge.build("w_forged_%d" % Time.get_ticks_msec(), kind, weapon_name, parts, size,
		{"purity_roll": purity_roll, "quench": quench, "temper": temper,
			"keep_stress": keep_stress, "techniques": techniques,
			"balance_bias": balance_bias, "style": _style()})
	var w := result_weapon
	var txt := "=== %s(%s)已锻造完成 ===\n四维: 纯净 %d / 结构 %d / 热处理 %d / 平衡 %d\n缺陷: %s\n指纹: %s\n\n下一步: 放入神裁砧,与锻造之神交涉" % [
		w.name, w.kind_name, int(w.craft.purity), int(w.craft.structure),
		int(w.craft.temper), int(w.craft.balance),
		("、".join(w.defects.map(func(d): return d.label)) if w.defects.size() > 0 else "无"),
		w.fingerprint.left(16) + "…"]
	ui.result.text = txt
	ui.reset_btn.visible = true


func _reset() -> void:
	stage = "melt"
	done_stages = []
	purity_roll = 0.6
	quench = "water"
	temper = false
	keep_stress = false
	balance_bias = false
	techniques = []
	parts = {"action": "grey_iron", "bearing": "grey_iron", "control": "grey_iron", "medium": "grey_iron"}
	size = {"length": 0.6, "thickness": 0.5, "balance": 0.5}
	ui.result.text = ""
	ui.reset_btn.visible = false
	_rebuild_right()
	_update_facts()
	_refresh_center()


func _apply_stage_ui() -> void:
	# 页签启用状态
	for st in STAGES:
		var b: Button = ui.get("tab_" + st.id)
		var unlocked: bool = st.id in done_stages or st.id == stage
		b.disabled = not unlocked
		b.modulate = Color(1, 1, 1) if st.id == stage else (Color(0.85, 0.85, 0.85) if st.id in done_stages else Color(0.5, 0.5, 0.5))
	# 控件只读性(仅当前可编辑)
	for sid in rows.keys():
		var editable: bool = (sid == stage)
		for c in rows[sid]:
			c.visible = (sid == stage)         # 只显示当前阶段
			if c is OptionButton:
				c.disabled = not editable
			elif c is HSlider:
				c.editable = editable
			elif c is CheckButton:
				c.disabled = not editable
			elif c is HBoxContainer:
				c.visible = (sid == stage)
				for sub in c.get_children():
					if sub is OptionButton:
						sub.disabled = not editable
					elif sub is HSlider:
						sub.editable = editable
					elif sub is CheckButton:
						sub.disabled = not editable
	# 进度显示
	var stage_names := []
	for st in STAGES:
		var mark := "✓" if st.id in done_stages else ("▶" if st.id == stage else "·")
		stage_names.append("%s%s" % [mark, st.name])
	ui.progress.text = "  ".join(stage_names)
	# 下一步按钮
	if _is_finished() and not result_weapon.is_empty():
		ui.next_btn.text = "前往神裁砧(交涉) >"
	elif stage == "assemble":
		ui.next_btn.text = "完成锻造(前往神前交涉)"
	else:
		var nxt := ""
		for i in STAGES.size():
			if STAGES[i].id == stage:
				if i + 1 < STAGES.size():
					nxt = STAGES[i + 1].name.replace("① ", "").replace("② ", "").replace("③ ", "").replace("④ ", "").replace("⑤ ", "")
		ui.next_btn.text = "确定并进入下一步(%s) >" % nxt


func _is_finished() -> bool:
	return done_stages.size() >= STAGES.size()


## ---------------- 事实卡与预览 ----------------

func _style() -> String:
	if keep_stress:
		return "cracksman"
	if quench in ["salt", "beast_oil"]:
		return "daring"
	return "steady"


func _update_facts() -> void:
	_update_stats()
	var w := Forge.build("preview", kind, weapon_name, parts, size,
		{"purity_roll": purity_roll, "quench": quench, "temper": temper,
			"keep_stress": keep_stress, "techniques": techniques,
			"balance_bias": balance_bias, "style": _style()})
	var lines := "【档案事实卡 · 将被神引用】\n"
	for f in w.facts:
		lines += "· %s\n" % str(f.text)
	ui.facts.text = lines


func _refresh_center() -> void:
	queue_redraw()


func _kind_idx() -> int:
	for i in KIND_CHOICES.size():
		if KIND_CHOICES[i].id == kind:
			return i
	return 0


func _draw() -> void:
	var c := PANEL.position + PANEL.size / 2.0
	draw_rect(PANEL, Color(0.16, 0.13, 0.1))
	draw_rect(PANEL, Color(0.5, 0.4, 0.3, 0.6), false, 2.0)
	draw_rect(Rect2(c + Vector2(-160, 60), Vector2(320, 26)), Color(0.45, 0.3, 0.2))
	var action_c: Color = MAT_COLOR.get(parts.action, Color.WHITE)
	var bearing_c: Color = MAT_COLOR.get(parts.bearing, Color.WHITE)
	var control_c: Color = MAT_COLOR.get(parts.control, Color.WHITE)
	var medium_c: Color = MAT_COLOR.get(parts.medium, Color.WHITE)
	match kind:
		"warhammer":
			draw_rect(Rect2(c + Vector2(-28, -60), Vector2(56, 84)), action_c)
			draw_rect(Rect2(c + Vector2(-6, 24), Vector2(12, 72)), bearing_c)
			draw_rect(Rect2(c + Vector2(-14, 88), Vector2(28, 14)), control_c)
			draw_circle(c + Vector2(0, 0), 7.0, medium_c)
			if keep_stress:
				draw_line(c + Vector2(-16, -30), c + Vector2(24, 18), Color(1.0, 0.3, 0.2), 3.0)
		"longsword":
			draw_rect(Rect2(c + Vector2(-8, -150), Vector2(16, 160)), action_c)
			draw_rect(Rect2(c + Vector2(-34, 10), Vector2(68, 10)), bearing_c)
			draw_rect(Rect2(c + Vector2(-10, 20), Vector2(20, 66)), control_c)
			if keep_stress:
				draw_line(c + Vector2(-4, -110), c + Vector2(5, -60), Color(1.0, 0.3, 0.2), 2.0)
		"bow":
			draw_arc(c + Vector2(0, -10), 120.0, -1.2, 1.2, 40, action_c, 8.0)
			draw_arc(c + Vector2(0, -10), 132.0, -1.2, 1.2, 40, bearing_c, 3.0)
			draw_line(c + Vector2(72, 102), c + Vector2(-72, 102), control_c, 2.0)
			draw_circle(c + Vector2(0, 10), 7.0, medium_c)
	# 阶段信息
	var info := ""
	match stage:
		"melt":
			info = "温区: 把握 %.2f" % purity_roll
		"smith":
			info = "尺寸: 长%.2f 厚%.2f 配重%.2f" % [size.length, size.thickness, size.balance]
		"temper":
			info = "介质: %s · %s" % [Forge.QUENCH_MEDIA[quench].label, "已回火" if temper else "不回火"]
		"assemble":
			info = "重心 %.2f · %s" % [size.balance, "故意偏置" if balance_bias else "标准装配"]
	if ui.has("info") and ui.info != null:
		ui.info.text = info
	if stage in ["smith", "assemble"]:
		var gx: float = (size.balance - 0.5) * 60.0
		draw_line(c + Vector2(gx - 6, -120), c + Vector2(gx + 6, -120), Color(1.0, 0.9, 0.5), 2.0)
		draw_line(c + Vector2(gx, -120), c + Vector2(gx, 60), Color(1.0, 0.9, 0.5, 0.4), 1.0)
