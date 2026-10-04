class_name SeedSelect
extends Control
## Pre-battle seed choice. Hybrids are not seeds: both ingredients must be in the set.

signal confirmed(ids: Array[StringName])
signal cancelled

var level: LevelData
var chosen: Array[StringName] = []
var _chosen_row: HBoxContainer
var _grid: GridContainer
var _slots_label: Label
var _info_title: Label
var _info_body: Label
var _start_btn: Button
var _available: Array[StringName] = []
var _locked: bool = false

func _ready() -> void:
	UIKit.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locked = not level.fixed_seeds.is_empty()
	for id: StringName in DB.PLANT_ORDER:
		var d := DB.plant(id)
		if d and (d.is_seed or (not d.is_hybrid and SaveManager.is_plant_unlocked(id))) and id != &"lily_raft" and SaveManager.is_plant_unlocked(id) and not level.banned_plants.has(id):
			_available.append(id)
	if _locked:
		for id: StringName in level.fixed_seeds:
			chosen.append(id)
	else:
		for id: StringName in GameState.last_seeds:
			if _available.has(id) and chosen.size() < SaveManager.seed_slots():
				chosen.append(id)
		if chosen.is_empty():
			for id: StringName in _available:
				if chosen.size() < SaveManager.seed_slots():
					chosen.append(id)
	_build()
	_refresh()

func _build() -> void:
	var panel := UIKit.panel(22)
	panel.position = Vector2(170, 170)
	panel.custom_minimum_size = Vector2(1150, 860)
	add_child(panel)
	var v := UIKit.vbox(12)
	panel.add_child(v)
	var head := UIKit.hbox(20)
	head.add_child(UIKit.label(tr("SEEDS_TITLE"), 38))
	head.add_child(UIKit.spacer())
	_slots_label = UIKit.label("", 28)
	head.add_child(_slots_label)
	v.add_child(head)
	var chosen_panel := PanelContainer.new()
	chosen_panel.add_theme_stylebox_override("panel", UITheme.kit("board", 14))
	chosen_panel.custom_minimum_size = Vector2(0, 162)
	_chosen_row = UIKit.hbox(6)
	chosen_panel.add_child(_chosen_row)
	v.add_child(chosen_panel)
	if _locked:
		v.add_child(UIKit.label(tr("SEEDS_FIXED"), 24, UITheme.BAD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	v.add_child(scroll)
	var info := UIKit.panel(12)
	info.custom_minimum_size = Vector2(0, 120)
	var iv := UIKit.vbox(4)
	_info_title = UIKit.label(tr("SEEDS_HOVER_HINT"), 26)
	_info_body = UIKit.wrap("", 22)
	iv.add_child(_info_title)
	iv.add_child(_info_body)
	info.add_child(iv)
	v.add_child(info)
	var foot := UIKit.hbox(16)
	var hyb := ""
	if not SaveManager.has_feature(&"graft") or level.hybrid_cap <= 0:
		hyb = ""
	elif level.allow_hybrids:
		hyb = tr("SEEDS_HYBRIDS_ALLOWED").format({"n": level.hybrid_cap})
	else:
		hyb = tr("SEEDS_HYBRIDS_BANNED")
	foot.add_child(UIKit.label(hyb, 24))
	foot.add_child(UIKit.spacer())
	foot.add_child(UIKit.button(tr("UI_BACK"), func() -> void: cancelled.emit(), 200))
	_start_btn = UIKit.button(tr("SEEDS_START"), _on_start, 260)
	foot.add_child(_start_btn)
	v.add_child(foot)
	# Zombie list on the right
	var zp := UIKit.panel(16)
	zp.position = Vector2(1345, 170)
	zp.custom_minimum_size = Vector2(110, 0)
	var zv := UIKit.vbox(6)
	zv.add_child(UIKit.label(tr("SEEDS_ZOMBIES"), 24))
	for id: StringName in level.zombie_pool:
		var zd := DB.zombie(id)
		if zd:
			zv.add_child(UIKit.label("• " + tr(zd.name_key), 22))
	zv.add_child(UIKit.label(tr("SEEDS_WAVES").format({"n": level.waves}), 22))
	zp.add_child(zv)
	add_child(zp)

func _refresh() -> void:
	for c: Node in _chosen_row.get_children():
		c.queue_free()
	for c: Node in _grid.get_children():
		c.queue_free()
	for i: int in chosen.size():
		var card := SeedCard.new(DB.plant(chosen[i]), i)
		card.pressed.connect(_on_chosen_pressed)
		card.hovered.connect(_on_hover)
		_chosen_row.add_child(card)
	for i: int in range(chosen.size(), SaveManager.seed_slots()):
		var empty := Panel.new()
		empty.custom_minimum_size = SeedCard.SIZE
		empty.add_theme_stylebox_override("panel", UITheme.kit("card", 0, Color(0.42, 0.34, 0.26, 0.55)))
		_chosen_row.add_child(empty)
	for id: StringName in _available:
		var card := SeedCard.new(DB.plant(id))
		card.dimmed = chosen.has(id) or _locked
		card.pressed.connect(_on_grid_pressed)
		card.hovered.connect(_on_hover)
		_grid.add_child(card)
	_slots_label.text = tr("SEEDS_SLOTS").format({"n": chosen.size(), "max": SaveManager.seed_slots()})
	_start_btn.disabled = chosen.is_empty()

func _on_chosen_pressed(card: SeedCard) -> void:
	if _locked:
		return
	chosen.erase(card.data.id)
	_refresh()

func _on_grid_pressed(card: SeedCard) -> void:
	if _locked:
		return
	var id := card.data.id
	if chosen.has(id):
		chosen.erase(id)
	elif chosen.size() < SaveManager.seed_slots():
		chosen.append(id)
	_refresh()

func _on_hover(card: SeedCard) -> void:
	var d := card.data
	_info_title.text = "%s  —  %s %d  ·  %s %s" % [tr(d.name_key), tr("UI_COST"), d.cost, tr("UI_RECHARGE"), tr("UNIT_SEC").format({"n": "%.1f" % d.recharge})]
	_info_body.text = tr(d.desc_key)

func _on_start() -> void:
	if chosen.is_empty():
		return
	confirmed.emit(chosen.duplicate())
