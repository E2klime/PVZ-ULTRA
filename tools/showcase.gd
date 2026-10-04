extends Node
## Renders animated battle showcase frames (needs a display or Xvfb):
##   godot --path . res://tools/showcase.tscn -- <out_dir> [scene] [frames]
## scene: lawn (default) | pool.  Frames are captured every other 60 fps frame
## (30 fps) and can be turned into a clip with ffmpeg (see docs/ANIMATION.md).

var out_dir: String = "/tmp/showcase"
var scene_id: String = "lawn"
var frames: int = 90

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		scene_id = args[1]
	if args.size() > 2:
		frames = int(args[2])
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER:
		SaveManager.unlock_plant(id)
	GameState.map_id = &"pool" if scene_id == "pool" else &"lawn"
	GameState.level_id = &"pool_02" if scene_id == "pool" else &"lawn_12"
	GameState.node_id = &"showcase"
	var main: Node = load("res://ui/main.gd").new()
	add_child(main)
	GameState.goto(&"battle")
	await _wait(0.4)
	var battle := main.get("current") as Battle
	battle.hud.get_child(0).get_child(battle.hud.get_child(0).get_child_count() - 1).get_child(0).queue_free()
	battle.hud.banner_label.visible = false
	var ids: Array[StringName] = [&"sunbud", &"rime_lettuce", &"sun_sovereign", &"phoenix_lily", &"storm_thistle", &"elder_oak", &"pod_shooter", &"frost_mint"]
	battle.begin(ids)
	battle.director.active = false
	var layout := [
		[0, [&"sunbud", &"pod_shooter", &"twin_pod", &"", &"", &"", &"", &"bark_wall"]],
		[1, [&"sun_sovereign", &"glacier_shooter", &"lantern_bloom", &"", &"", &"", &"rime_lettuce"]],
		[2, [&"twin_sunbud", &"phoenix_lily", &"pepper_stinger", &"", &"", &"", &"", &"elder_oak"]],
		[3, [&"sunbud", &"storm_thistle", &"pod_shooter", &"", &"", &"snapper_trap"]],
		[4, [&"dawn_bloom", &"needle_volley", &"frost_mint", &"", &"", &"", &"", &"thornwall"]],
	]
	if scene_id == "pool":
		layout = [
			[0, [&"sunbud", &"hive_pod", &"pod_shooter", &"", &"", &"", &"rime_lettuce"]],
			[1, [&"sun_sovereign", &"glacier_shooter", &"lantern_bloom", &"lily_raft", &"", &"", &"", &"bark_wall"]],
			[2, [&"twin_sunbud", &"phoenix_lily", &"pepper_stinger", &"", &"", &"", &"", &"elder_oak"]],
			[3, [&"sunbud", &"storm_thistle", &"pod_shooter", &"", &"", &"snapper_trap"]],
			[4, [&"dawn_bloom", &"needle_volley", &"frost_mint", &"", &"", &"", &"", &"thornwall"]],
		]
	for row: Array in layout:
		var cols: Array = row[1]
		for c: int in cols.size():
			var id: StringName = cols[c]
			if id != &"":
				var p: Plant = battle._make_plant(DB.plant(id), row[0], c)
				p.age = 30.0
				if battle.board.is_water(row[0], c) and id != &"lily_raft":
					p.on_raft = true
	battle.sun = 525
	var zs := [[&"cone_head", 0, 1240], [&"shambler", 1, 1180], [&"bucket_head", 2, 1300], [&"sprinter", 3, 1350],
		[&"shield_carrier", 4, 1280], [&"flagbearer", 1, 1400], [&"brute", 2, 1420], [&"hurdler", 3, 1200]]
	if scene_id == "pool":
		zs = [[&"cone_head", 0, 1240], [&"shambler", 1, 860], [&"bucket_head", 2, 1000], [&"sprinter", 3, 1350],
			[&"shield_carrier", 4, 1280], [&"flagbearer", 1, 1400], [&"brute", 2, 1420], [&"hurdler", 3, 760]]
	for z: Array in zs:
		var zz := battle.spawn_zombie(z[0], z[1])
		zz.position.x = z[2]
	await _wait(1.2)
	# statuses on display: one frozen, one burning
	for z: Zombie in battle.zombies_in_row(0):
		z.freeze(8.0)
	for z: Zombie in battle.zombies_in_row(4):
		z.burn(1.0, 6.0)
	await _wait(0.3)
	for i: int in frames:
		await get_tree().physics_frame
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("f_%03d.png" % i))
	print("SHOWCASE frames=", frames, " -> ", out_dir)
	get_tree().quit()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
