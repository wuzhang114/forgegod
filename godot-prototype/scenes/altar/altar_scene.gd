## 神裁砧(交涉面板)v1 —— 全流程跑通版。
## 流程: 展示武器档案 -> 玩家上奏申请 -> 假神回应(QUESTION/COUNTEROFFER/PROPOSE/REFUSE)
##       -> 接受提案 -> 校验定稿(GameSession.divine_contract) -> 开始验证战斗。
## 运行: 由锻造台"前往神裁砧"进入。

extends Node2D

const God := preload("res://core/negotiation/scripted_god.gd")
const Session := preload("res://core/flow/game_session.gd")

var ui: Dictionary = {}


func _ready() -> void:
	if Session.weapon_facts.is_empty():
		# 兜底: 无锻造数据 -> 放一个示例(便于直接调试场景)
		var Forge := preload("res://core/forge/forge_core.gd")
		Session.weapon_facts = Forge.build("demo", "warhammer", "示例战锤",
			{"action": "star_iron", "bearing": "blackwood", "control": "grey_iron", "medium": "red_copper"},
			{"length": 0.7, "thickness": 0.6, "balance": 0.5},
			{"purity_roll": 0.7, "quench": "water", "temper": false, "keep_stress": false,
				"techniques": [], "balance_bias": false, "style": "steady"})
	_build_ui()
	_show_weapon()


func _build_ui() -> void:
	ui = {}
	# 背景氛围
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var title := Label.new()
	title.text = "神裁砧 · 与锻造之神赫铎恩交涉"
	title.position = Vector2(80, 30)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	add_child(title)
	# 左: 武器档案
	ui.weapon = RichTextLabel.new()
	ui.weapon.position = Vector2(80, 90)
	ui.weapon.custom_minimum_size = Vector2(420, 400)
	ui.weapon.bbcode_enabled = true
	ui.weapon.add_theme_font_size_override("normal_font_size", 14)
	add_child(ui.weapon)
	# 中: 对话流
	ui.log = RichTextLabel.new()
	ui.log.position = Vector2(540, 90)
	ui.log.custom_minimum_size = Vector2(440, 340)
	ui.log.bbcode_enabled = true
	ui.log.add_theme_font_size_override("normal_font_size", 14)
	add_child(ui.log)
	# 申请输入
	var hint := Label.new()
	hint.text = "你的申请(想要武器做到什么?):"
	hint.position = Vector2(540, 440)
	add_child(hint)
	ui.input = LineEdit.new()
	ui.input.position = Vector2(540, 462)
	ui.input.custom_minimum_size = Vector2(440, 32)
	ui.input.placeholder_text = "例:连续命中三次后召唤火花小精灵…"
	add_child(ui.input)
	ui.ask = Button.new()
	ui.ask.text = "上奏"
	ui.ask.position = Vector2(990, 460)
	ui.ask.custom_minimum_size = Vector2(90, 36)
	ui.ask.pressed.connect(_on_submit)
	add_child(ui.ask)
	ui.stance = Label.new()
	ui.stance.position = Vector2(540, 510)
	ui.stance.add_theme_font_size_override("font_size", 14)
	add_child(ui.stance)
	ui.accept = Button.new()
	ui.accept.text = "接受这份神赐契约"
	ui.accept.position = Vector2(540, 545)
	ui.accept.custom_minimum_size = Vector2(240, 36)
	ui.accept.pressed.connect(_on_accept)
	ui.accept.visible = false
	add_child(ui.accept)
	ui.retry = Button.new()
	ui.retry.text = "换一种说法上奏"
	ui.retry.position = Vector2(790, 545)
	ui.retry.custom_minimum_size = Vector2(180, 36)
	ui.retry.pressed.connect(func(): ui.accept.visible = false; ui.stance.text = "")
	add_child(ui.retry)
	ui.battle = Button.new()
	ui.battle.text = "把武器送上棋盘,开始验证战斗"
	ui.battle.position = Vector2(540, 600)
	ui.battle.custom_minimum_size = Vector2(320, 40)
	ui.battle.pressed.connect(_on_to_battle)
	ui.battle.visible = false
	add_child(ui.battle)
	ui.back = Button.new()
	ui.back.text = "← 返回锻造台"
	ui.back.position = Vector2(80, 505)
	ui.back.custom_minimum_size = Vector2(200, 32)
	ui.back.pressed.connect(func():
		GameApp.goto("forge"))
	add_child(ui.back)


func _show_weapon() -> void:
	var w := Session.weapon_facts
	var txt := "[b]%s(%s)[/b]\n四维: 纯净 %d / 结构 %d / 热处理 %d / 平衡 %d\n缺陷: %s\n\n[size=13][color=#bbbbbb]" % [
		w.name, w.kind_name, int(w.craft.purity), int(w.craft.structure),
		int(w.craft.temper), int(w.craft.balance),
		("、".join(w.defects.map(func(d): return d.label)) if w.defects.size() > 0 else "无")]
	for f in w.facts:
		txt += "· %s\n" % str(f.text)
	txt += "[/color][/size]"
	ui.weapon.text = txt


func _say(who: String, text: String) -> void:
	var color := "#f0b060" if who == "神" else "#88ccff"
	ui.log.text += "\n[color=%s][b]%s[/b][/color] %s\n" % [color, who, text]
	ui.log.scroll_to_line(ui.log.get_line_count())


func _on_submit() -> void:
	var app: String = ui.input.text.strip_edges()
	if app.is_empty():
		_say("你", "(尚未开口)")
		return
	var turn := God.adjudicate(Session.weapon_facts, app)
	Session.divine_turn = turn
	_say("你", app)
	_say("神", turn.speech)
	var stance_zh := {"QUESTION": "质询", "COUNTEROFFER": "还价", "PROPOSE": "应允", "REFUSE": "驳回"}
	if turn.stance == "QUESTION":
		ui.stance.text = "[color=#ffd27f]神说: %s[/color]" % turn.missing
	if turn.stance == "REFUSE":
		ui.stance.text = "[color=#ff8080]驳回: %s[/color]" % turn.refuse_reason
	if turn.stance in ["PROPOSE", "COUNTEROFFER"]:
		ui.stance.text = "[color=#8f8][b]神已给出契约草案(代价见右)[/b][/color]\n[draft]\n%s\n[/draft]" % str(turn.draft).strip_edges()
		ui.accept.visible = true
	else:
		ui.accept.visible = false


func _on_accept() -> void:
	var turn: Dictionary = Session.divine_turn
	if turn.is_empty() or str(turn.get("draft", "")).strip_edges().is_empty():
		return
	var res := Session.commit_contract(str(turn.draft))
	if res.ok:
		_say("你", "我接受这份契约。")
		_say("神", "刻印已成。去让沙场替我作证。")
		ui.accept.visible = false
		ui.battle.visible = true
	else:
		_say("神", "此约不可行(草案校验失败): %s" % str(res.error))


func _on_to_battle() -> void:
	# 契约定稿同步进 RunState(存档基础)
	GameApp.run.contract_src = str(Session.divine_contract.get("source", ""))
	GameApp.goto("battle")
