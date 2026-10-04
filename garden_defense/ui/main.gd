extends Node
## Root: owns the theme and swaps screens on EventBus.screen_requested.

var current: Node

func _ready() -> void:
	EventBus.screen_requested.connect(_show)
	# Debug/QA: `-- --goto=<level_id>` jumps straight into a level's seed selection.
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--goto="):
			GameState.level_id = StringName(a.substr(7))
			GameState.node_id = &"qa"
			_show(&"battle", {})
			return
	_show(&"loading", {})

func _show(screen: StringName, args: Dictionary) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current:
		current.queue_free()
		current = null
	var next: Node
	match screen:
		&"loading":
			next = LoadingScreen.new()
		&"menu":
			next = MainMenu.new()
		&"help":
			next = HelpScreen.new()
		&"stats":
			next = StatsScreen.new()
		&"hub":
			next = HubScreen.new()
		&"map":
			next = MapScreen.new()
		&"battle":
			next = Battle.new()
		&"almanac":
			next = AlmanacScreen.new()
		&"quests":
			next = QuestScreen.new()
		&"shop":
			next = ShopScreen.new()
		&"settings":
			next = SettingsScreen.new()
		&"workshop":
			next = WorkshopScreen.new()
		_:
			next = MainMenu.new()
	if next.has_method("set_args"):
		next.call("set_args", args)
	current = next
	add_child(next)

## Android back button. The engine's default (quit_on_go_back) closed the app from any
## screen, even mid-battle; it is disabled in project.godot. Main menu, settings, help,
## stats and the battle HUD handle back themselves; this routes the remaining screens.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or current == null:
		return
	if current is MainMenu or current is SettingsScreen or current is HelpScreen or current is StatsScreen or current is LoadingScreen:
		return
	if current is Battle:
		# While playing, the HUD toggles the pause menu instead.
		if (current as Battle).phase != Battle.Phase.PLAYING:
			GameState.goto(GameState.back_screen())
		return
	if current is HubScreen:
		GameState.goto(&"menu")
	elif current is MapScreen:
		GameState.goto(&"hub")
	else:
		var back: Variant = current.get("_back")
		GameState.goto(StringName(str(back)) if back != null and str(back) != "" else &"menu")

