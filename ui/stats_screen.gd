class_name StatsScreen
extends Control
## Profile & statistics.

var _back: StringName = &"menu"

func set_args(args: Dictionary) -> void:
	_back = args.get("back", &"menu")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.goto(_back)

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.for_screen(&"stats"))
	var p := UIKit.panel(28)
	p.custom_minimum_size = Vector2(1000, 0)
	var v := UIKit.vbox(10)
	var head := UIKit.hbox()
	head.add_child(UIKit.label(tr("UI_STATS"), 44))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.button(tr("UI_BACK"), func() -> void: GameState.goto(_back), 200))
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 8)
	# Only count real seeds on both sides (hybrids can never be "unlocked" seeds).
	var unlocked := 0
	var seeds := 0
	for id: StringName in DB.plants:
		if (DB.plants[id] as PlantData).is_seed:
			seeds += 1
			if SaveManager.is_plant_unlocked(id): unlocked += 1
	var recipes_total := DB.recipes.size()
	var found := 0
	for r: FusionRecipe in DB.recipes:
		if SaveManager.is_recipe_discovered(r.recipe_id()): found += 1
	var seen := 0
	for id: StringName in DB.zombies:
		if SaveManager.is_zombie_seen(id): seen += 1
	var rows := [
		["STATS_CAMPAIGN", "%d / %d" % [_count(), DB.levels.size()]], ["STATS_STARS", str(SaveManager.stars())],
		["STATS_COINS", str(SaveManager.coins())], ["STATS_PLANTS", "%d / %d" % [unlocked, seeds]],
		["STATS_RECIPES", "%d / %d" % [found, recipes_total]], ["STATS_ZOMBIES", "%d / %d" % [seen, DB.zombies.size()]],
		["STATS_WINS", str(SaveManager.stat(&"wins"))], ["STATS_PLANTED", str(SaveManager.stat(&"planted"))],
		["STATS_GRAFTS", str(SaveManager.stat(&"grafts"))], ["STATS_TWIN_GRAFTS", str(SaveManager.stat(&"twin_grafts"))],
		["STATS_GLOVE", str(SaveManager.stat(&"glove_moves"))],
		["STATS_SUN", str(SaveManager.stat(&"sun"))], ["STATS_ENDLESS", str(SaveManager.get_extra("endless_best", 0))],
		["STATS_DAILIES", str(SaveManager.stat(&"dailies"))],
	]
	for r: Array in rows:
		grid.add_child(UIKit.label(tr(r[0]), 26))
		grid.add_child(UIKit.label(r[1], 26, UITheme.LEAF_DARK))
	v.add_child(grid)
	p.add_child(v)
	add_child(UIKit.centered(p))

func _count() -> int:
	var n := 0
	for map: MapData in DB.maps:
		n += CampaignProgress.cleared_count(map.id)
	return n
