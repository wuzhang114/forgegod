## 武装间: 神裁后整装 —— 多武器库界面(装备/换装/卸下),确认后出战。
## 数据: GameApp.run.weapons(武器实例库)+ roster loadout;不强制换装(默认演示三把已装备)。

extends Node2D

const EquipWeapon := preload("res://application/equip_weapon.gd")
const Explainer := preload("res://domain/weapon/contract_explainer.gd")
const WeaponStats := preload("res://core/forge/weapon_stats.gd")

const HEROES := [
	{"id": "hero_1", "role": "guard", "name": "守卫·布兰特"},
	{"id": "hero_2", "role": "duelist", "name": "连击手·莉娅"},
	{"id": "hero_3", "role": "ranger", "name": "射手·锡拉"},
]

var ui: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var t := Label.new()
	t.text = "武装间 · 神裁已定 · 请为小队整装"
	t.position = Vector2(80, 24)
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	add_child(t)
	ui.tip = Label.new()
	ui.tip.position = Vector2(80, 52)
	ui.tip.modulate = Color(0.85, 0.85, 0.8)
	ui.tip.text = "点武器卡上的「装备给…」换装;卸下按「卸下」;不强制换装"
	add_child(ui.tip)
	# 主容器(ScrollContainer 内 VBox)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 90)
	scroll.custom_minimum_size = Vector2(1100, 480)
	add_child(scroll)
	ui.container = VBoxContainer.new()
	ui.container.custom_minimum_size = Vector2(1060, 0)
	ui.container.add_theme_constant_override("separation", 8)
	scroll.add_child(ui.container)
	# 底栏
	var bottom := HBoxContainer.new()
	bottom.position = Vector2(80, 600)
	bottom.add_theme_constant_override("separation", 12)
	add_child(bottom)
	var go := Button.new()
	go.text = "⚔ 出战验证(棋盘)"
	go.custom_minimum_size = Vector2(220, 40)
	go.pressed.connect(func(): GameApp.goto("battle"))
	bottom.add_child(go)
	var back := Button.new()
	back.text = "← 回神裁砧"
	back.custom_minimum_size = Vector2(160, 40)
	back.pressed.connect(func(): GameApp.goto("altar"))
	bottom.add_child(back)
	var home := Button.new()
	home.text = "⟲ 回铁匠铺"
	home.custom_minimum_size = Vector2(160, 40)
	home.pressed.connect(func(): GameApp.goto("forge"))
	bottom.add_child(home)


func _refresh() -> void:
	for c in ui.container.get_children():
		c.queue_free()
	var run = GameApp.run
	# 队伍行
	var squad := Label.new()
	squad.text = "—— 小队当前武装 ——"
	squad.modulate = Color(1.0, 0.85, 0.6)
	ui.container.add_child(squad)
	for hero in HEROES:
		var h := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = str(hero.name)
		name_l.custom_minimum_size = Vector2(140, 0)
		h.add_child(name_l)
		var inst := EquipWeapon.loadout_of(run, str(hero.id))
		var cur := ""
		if not inst.is_empty():
			var nm := str(inst.get("facts", {}).get("name", ""))
			var nm2 := nm if nm != "" else "演示武器"
			cur = "「%s」" % nm2
		h.add_child(Label.new())
		var cur_l := Label.new()
		cur_l.text = "当前装备: " + (cur if cur != "" else "(徒手)")
		cur_l.custom_minimum_size = Vector2(300, 0)
		h.add_child(cur_l)
		if not inst.is_empty():
			var un := Button.new()
			un.text = "卸下"
			un.pressed.connect(func():
				for m in run.roster:
					if str(m.get("id", "")) == str(hero.id):
						m["weapon_id"] = ""
				_refresh())
			h.add_child(un)
		ui.container.add_child(h)
	ui.container.add_child(Label.new())
	# 武器库
	var lib := Label.new()
	lib.text = "—— 武器库(%d 件)——" % run.weapons.size()
	lib.modulate = Color(1.0, 0.85, 0.6)
	ui.container.add_child(lib)
	var new_weapon_marked := false
	for inst in run.weapons:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(1040, 0)
		var v := VBoxContainer.new()
		card.add_child(v)
		var facts: Dictionary = inst.get("facts", {})
		var nm := str(facts.get("name", "演示武器"))
		var line1 := "%s [%s]" % [nm, str(facts.get("kind_name", "演示"))]
		var with_contract := _has_contract(inst)
		if with_contract:
			line1 += " ★神赐"
		var holder := str(inst.get("holder_id", ""))
		if holder != "":
			line1 += " · 已装备: %s" % _hero_name(holder)
		else:
			line1 += " · 未装备"
		var l1 := Label.new()
		l1.text = line1
		l1.modulate = Color(0.95, 0.9, 0.7)
		v.add_child(l1)
		# 四维/面板
		var l2 := Label.new()
		if not facts.is_empty():
			var ws := WeaponStats.from_facts(facts)
			l2.text = "四维 纯%d/构%d/热%d/衡%d · 攻×%.2f 暴×%.2f 破甲+%.0f 独立+%.0f%% 耐久%.0f · %s" % [
				int(facts.craft.purity), int(facts.craft.structure), int(facts.craft.temper),
				int(facts.craft.balance), ws.atk_mult, ws.crit_mult, ws.shred * 100.0,
				ws.wbonus * 100.0, ws.durability,
				("、".join(facts.get("defects", []).map(func(d): return d.label)) if facts.get("defects", []).size() > 0 else "无缺陷")]
		else:
			l2.text = "演示武器(默认均衡面板)"
		l2.add_theme_font_size_override("font_size", 12)
		l2.modulate = Color(0.75, 0.8, 0.75)
		v.add_child(l2)
		# 契约说明(优先 AI 生成的技能描述 summary;否则本地转译)
		for c in inst.get("contracts", []):
			var src := str(c.get("src", ""))
			if src.strip_edges() == "":
				continue
			var summary := str(c.get("summary", "")).strip_edges()
			var cl := Label.new()
			if summary != "":
				cl.text = "  ✦ 神谕描述: " + summary
				cl.modulate = Color(1.0, 0.9, 0.6)
			else:
				var lines := Explainer.explain(src)
				cl.text = "  · " + "\n  · ".join(lines)
				cl.modulate = Color(0.8, 0.9, 1.0)
			cl.add_theme_font_size_override("font_size", 12)
			v.add_child(cl)
		# 装备按钮行
		var row := HBoxContainer.new()
		var tip_l := Label.new()
		tip_l.text = "装备给:"
		row.add_child(tip_l)
		for hero in HEROES:
			var b := Button.new()
			b.text = str(hero.name)
			b.custom_minimum_size = Vector2(120, 0)
			b.pressed.connect(func():
				EquipWeapon.equip(GameApp.run, inst.duplicate(true), str(hero.id))
				_refresh())
			row.add_child(b)
		v.add_child(row)
		if with_contract and not new_weapon_marked:
			new_weapon_marked = true
			var warn := Label.new()
			warn.text = "※ 该武器携带神赐契约;确认由出战的英雄装备,契约才会在棋盘上生效"
			warn.add_theme_font_size_override("font_size", 12)
			warn.modulate = Color(1.0, 0.8, 0.4)
			v.add_child(warn)
		ui.container.add_child(card)


static func _has_contract(inst: Dictionary) -> bool:
	for c in inst.get("contracts", []):
		if str(c.get("src", "")).strip_edges() != "":
			return true
	return false


static func _hero_name(id: String) -> String:
	for hero in HEROES:
		if str(hero.id) == id:
			return str(hero.name)
	return id
