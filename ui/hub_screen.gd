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
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 18)
	for map: MapData in DB.maps:
		var playable := CampaignProgress.world_unlocked(map.id)
		var status := tr("HUB_CLEARED").format({"n": CampaignProgress.cleared_count(map.id), "max": map.nodes.size()})
		if not playable:
			var prev := DB.map(map.previous_world)
			status = tr("HUB_NEEDS_WORLD").format({"n": prev.nodes.size() if prev else 0, "name": Loc.text(prev.name_key) if prev else String(map.previous_world)})
		var card := HubWorldCard.new(map, playable, status)
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
