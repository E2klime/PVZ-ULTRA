class_name HubScreen
extends Control
## Eight sequential campaign worlds; counts come from the loaded campaign data.

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.with_art("res://assets/art/bg/hub_greenhouse.jpg", 0.1))
	var v := UIKit.vbox(16)
	v.add_child(UIKit.title(tr("HUB_HEADER"), 48))
	v.add_child(UIKit.label(tr("HUB_CAMPAIGN").format({"n": _campaign_count(), "max": DB.levels.size()}), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	for map: MapData in DB.maps:
		var card := Button.new()
		card.custom_minimum_size = Vector2(420, 290)
		var playable := CampaignProgress.world_unlocked(map.id)
		var col := map.tint if playable else map.tint.darkened(0.5)
		card.add_theme_stylebox_override("normal", UITheme.box(col, col.darkened(0.35), 18, 4, 16))
		card.add_theme_stylebox_override("hover", UITheme.box(col.lightened(0.1), col.darkened(0.35), 18, 4, 16))
		card.add_theme_stylebox_override("disabled", UITheme.box(col, col.darkened(0.35), 18, 4, 16))
		card.add_theme_font_size_override("font_size", 24)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var status := tr("HUB_READY")
		if not playable:
			var prev := DB.map(map.previous_world)
			status = tr("HUB_NEEDS_WORLD").format({"n": prev.nodes.size() if prev else 0, "name": Loc.text(prev.name_key) if prev else String(map.previous_world)})
		card.text = "%s\n\n%s\n%s" % [Loc.text(map.name_key), tr("HUB_CLEARED").format({"n": CampaignProgress.cleared_count(map.id), "max": map.nodes.size()}), status]
		card.disabled = not playable
		card.pressed.connect(_open_map.bind(map.id))
		grid.add_child(card)
	v.add_child(grid)
	var actions := UIKit.hbox(20)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(UIKit.button(tr("UI_WORKSHOP"), func() -> void: GameState.goto(&"workshop"), 360))
	actions.add_child(UIKit.button(tr("UI_ALMANAC"), func() -> void: GameState.goto(&"almanac", {"back": &"hub"}), 280))
	actions.add_child(UIKit.button(tr("UI_BACK"), func() -> void: GameState.goto(&"menu"), 220))
	v.add_child(actions)
	add_child(UIKit.centered(v))

func _campaign_count() -> int:
	var n := 0
	for map: MapData in DB.maps: n += CampaignProgress.cleared_count(map.id)
	return n

func _open_map(id: StringName) -> void:
	if not CampaignProgress.world_unlocked(id): return
	GameState.map_id = id
	GameState.goto(&"map")
