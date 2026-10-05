extends Node
## Review capture: one battle screenshot per world with a fixed plant/zombie
## layout, so before/after art passes are comparable pixel-for-pixel.
## xvfb-run godot --path . --resolution 1920x1080 res://tools/art/review/capture_battles.tscn -- <out_dir> [world,world,...]

const WORLDS: Array[String] = ["lawn", "pool", "night", "desert", "roof", "frost", "factory", "moon"]
const PLANTS: Array = [
	[0, [&"sunbud", &"pod_shooter", &"", &"bark_wall"]],
	[1, [&"twin_sunbud", &"pod_shooter", &"frost_mint", &"", &"", &"thorn_carpet"]],
	[2, [&"sunbud", &"glacier_shooter", &"clod_catapult"]],
	[3, [&"sunbud", &"pod_shooter", &"twin_pod", &"", &"", &"", &"bramble_vine"]],
	[4, [&"lantern_bloom", &"pepper_stinger", &"", &"ironbark_wall"]],
]
const ZOMBIES: Array = [[&"shambler", 0, 1300], [&"cone_head", 1, 1240], [&"bucket_head", 2, 1380], [&"brute", 4, 1350], [&"shield_carrier", 3, 1180]]

var out_dir: String = "/tmp/shots"
var worlds: Array[String] = WORLDS.duplicate()

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		worlds.assign(args[1].split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_match_mobile_aspect()
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER:
		SaveManager.unlock_plant(id)
	var main: Node = load("res://ui/main.gd").new()
	add_child(main)
	await _wait(0.5)
	for w: String in worlds:
		await _capture_world(main, w)
	get_tree().quit()

func _capture_world(main: Node, w: String) -> void:
	GameState.level_id = StringName("%s_03" % w)
	GameState.goto(&"battle")
	await _wait(0.5)
	var battle := main.get("current") as Battle
	if battle == null:
		push_error("no battle for " + w)
		return
	battle.hud._clear_overlay()
	battle.begin([&"sunbud", &"pod_shooter"] as Array[StringName])
	var water: bool = battle.board.has_water()
	for row: Array in PLANTS:
		var cols: Array = row[1]
		for c: int in cols.size():
			var id: StringName = cols[c]
			if id == &"" or DB.plant(id) == null:
				continue
			if battle.board.is_water(row[0], c) or not battle.board.cell_empty(row[0], c):
				continue
			var p: Plant = battle._make_plant(DB.plant(id), row[0], c)
			p.age = 30.0
	for z: Array in ZOMBIES:
		var zz := battle.spawn_zombie(z[0], z[1])
		if zz:
			zz.position.x = z[2]
	battle.sun = 300
	await _wait(1.2)
	await _shot("battle_%s" % w)
	print("WATER ", w, " ", water)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


## Non-16:9 windows are phone shapes: mirror project.godot's aspect.mobile="expand" so the
## narrow capture shows what a phone shows instead of a letterboxed 16:9 frame.
func _match_mobile_aspect() -> void:
	var win := DisplayServer.window_get_size()
	if absf(float(win.x) / float(win.y) - 16.0 / 9.0) > 0.02:
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
