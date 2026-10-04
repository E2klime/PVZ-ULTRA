extends Node
## Renders a few screens to PNG (needs a real display or Xvfb).
## godot --path . res://tools/screenshot.tscn -- <out_dir> [locale]

var out_dir: String = "/tmp/shots"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		Settings.set_value(&"language", args[1], false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER:
		SaveManager.unlock_plant(id)
	SaveManager.unlock_feature(&"graft")
	for z: StringName in DB.ZOMBIE_ORDER:
		SaveManager.mark_zombie_seen(z)
	for n: String in ["n_01", "n_02", "n_03", "n_04", "n_05", "n_06", "n_b1", "n_07"]:
		SaveManager.complete_node(StringName(n))
	for l: String in ["lawn_01", "lawn_02", "lawn_03", "lawn_04", "lawn_05", "lawn_06", "lawn_bonus_1", "lawn_07"]:
		SaveManager.award_star(StringName(l))
	SaveManager.discover_recipe(&"pod_shooter+frost_mint")
	SaveManager.add_coins(640)
	SaveManager.set_current_node(&"lawn", &"n_07")
	var main: Node = load("res://ui/main.gd").new()
	add_child(main)
	await _wait(0.6)
	await _shot("loading")
	for s: StringName in [&"menu", &"help", &"stats", &"hub", &"map", &"almanac", &"shop", &"settings"]:
		GameState.goto(s, {"back": &"menu"})
		await _wait(0.5)
		await _shot(String(s))
		if s == &"almanac":
			var al := main.get("current") as AlmanacScreen
			if al:
				al._show_plant(&"sky_dragon")
				await _wait(0.3)
				await _shot("almanac_plant")
				al._show_zombie(&"box_zombie")
				await _wait(0.3)
				await _shot("almanac_zombie")
	GameState.level_id = &"pool_17"
	GameState.node_id = &"n_17"
	GameState.goto(&"battle")
	await _wait(0.6)
	await _shot("seed_select")
	var battle := main.get("current") as Battle
	battle.hud._clear_overlay()
	var ids: Array[StringName] = [&"sunbud", &"pod_shooter", &"pumpkin_shell", &"pea_bedding", &"garlic_drone", &"turbo_bean", &"clod_catapult", &"thorn_carpet", &"sky_dragon"]
	battle.begin(ids)
	battle.board.set_layout(PackedStringArray([".........", ".........", "..~~~~~..", ".........", "........."]))
	var layout := [
		[0, [&"sunbud", &"twin_sunbud", &"pod_shooter", &"glacier_shooter", &"clod_catapult", &"", &"", &"ironbark_wall"]],
		[1, [&"sunbud", &"turbo_bean", &"twin_pod", &"pod_shooter", &"sky_dragon", &"", &"thorn_carpet", &"bark_wall"]],
		[2, [&"sunbud", &"pod_shooter", &"lily_raft", &"lily_raft", &"", &"", &"", &""]],
		[3, [&"twin_sunbud", &"pod_shooter", &"pod_shooter", &"frost_mint", &"lava_catapult", &"thorn_carpet", &"", &"bramble_vine"]],
		[4, [&"sunbud", &"lantern_bloom", &"pepper_stinger", &"pod_shooter", &"chrono_clover", &"", &"", &"bark_wall"]],
	]
	for row: Array in layout:
		var cols: Array = row[1]
		for c: int in cols.size():
			var id: StringName = cols[c]
			if id != &"" and DB.plant(id):
				var p: Plant = battle._make_plant(DB.plant(id), row[0], c)
				p.age = 30.0
	var extra := [[&"pea_bedding", 0, 2], [&"pumpkin_shell", 0, 2], [&"garlic_drone", 1, 3], [&"pea_bedding", 3, 1], [&"thorn_pumpkin", 3, 7], [&"aegis_pumpkin", 4, 7], [&"chili_drone", 3, 2], [&"frost_bedding", 4, 3]]
	for e: Array in extra:
		var d := DB.plant(e[0])
		if d and battle.board.get_layer(e[1], e[2], d.layer) == null:
			var q: Plant = battle._make_plant(d, e[1], e[2])
			battle.board.set_layer(e[1], e[2], d.layer, q)
			q.age = 30.0
	battle.sun = 425
	var zs := [[&"shambler", 0, 1300], [&"box_zombie", 0, 1370], [&"cone_head", 1, 1240], [&"balloon_zombie", 1, 1150], [&"slingshot_zombie", 3, 1350], [&"shield_carrier", 3, 1260], [&"brute", 4, 1350],
		[&"bucket_head", 2, 1420], [&"box_zombie", 4, 1450]]
	for z: Array in zs:
		var zz := battle.spawn_zombie(z[0], z[1])
		zz.position.x = z[2]
	battle.spawn_sun(Board.cell_feet(2, 1) + Vector2(0, -60), 25, false)
	battle.director.wave = 6
	await _wait(1.6)
	battle.selected = 3
	battle.hud.refresh_selection()
	Input.warp_mouse(Vector2(700, 330))
	await _wait(0.2)
	await _shot("battle")
	battle.deselect()
	battle.hud.show_plant_info(battle.top_plant(Vector2i(4, 1)))
	await _wait(0.3)
	await _shot("battle_info")
	battle.hud.toggle_pause()
	await _wait(0.3)
	await _shot("pause")
	get_tree().quit()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)
