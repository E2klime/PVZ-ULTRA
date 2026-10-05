extends Node
## Review capture of every UI screen, plus map + seed selection for each of the 8 worlds.
## xvfb-run godot --path . --resolution 1920x1080 res://tools/art/review/capture_screens.tscn -- <out_dir>
## Battles per world are captured by capture_battles.tscn (same out_dir).

const WORLDS: Array[StringName] = [&"lawn", &"pool", &"night", &"desert", &"roof", &"frost", &"factory", &"moon"]
const SCREENS: Array[StringName] = [&"menu", &"help", &"stats", &"hub", &"workshop", &"almanac", &"quests", &"shop", &"settings"]

var out_dir: String = "/tmp/shots"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_match_mobile_aspect()
	_seed_save()
	var main: Node = load("res://ui/main.gd").new()
	add_child(main)
	await _wait(0.6)
	await _shot("loading")
	for s: StringName in SCREENS:
		GameState.goto(s, {"back": &"menu"})
		await _wait(0.5)
		await _shot(String(s))
	_settings_tabs(main)
	await _wait(0.3)
	await _shot("settings_video")
	for w: StringName in WORLDS:
		GameState.map_id = w
		GameState.goto(&"map")
		await _wait(0.5)
		await _shot("map_%s" % w)
		GameState.level_id = StringName("%s_03" % w)
		GameState.node_id = &"qa"
		GameState.goto(&"battle")
		await _wait(0.6)
		await _shot("seed_select_%s" % w)
	get_tree().quit()

func _seed_save() -> void:
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER:
		SaveManager.unlock_plant(id)
	SaveManager.unlock_feature(&"graft")
	for z: StringName in DB.ZOMBIE_ORDER:
		SaveManager.mark_zombie_seen(z)
	for m: MapData in DB.maps:
		for n: MapNodeData in m.nodes.slice(0, 4):
			SaveManager.complete_node(n.id)
			if n.level_id != &"":
				SaveManager.award_star(n.level_id)
	SaveManager.add_coins(640)

func _settings_tabs(main: Node) -> void:
	var cur := main.get("current") as Node
	if cur == null:
		return
	var tabs := cur.find_children("*", "TabContainer", true, false)
	if not tabs.is_empty():
		(tabs[0] as TabContainer).current_tab = 1

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


## Non-16:9 windows are phone shapes: mirror project.godot's aspect.mobile="expand" so the
## narrow capture shows what a phone shows instead of a letterboxed 16:9 frame.
func _match_mobile_aspect() -> void:
	var win := DisplayServer.window_get_size()
	if absf(float(win.x) / float(win.y) - 16.0 / 9.0) > 0.02:
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
