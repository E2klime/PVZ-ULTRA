extends Node
var out_dir: String
func _ready() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	SaveManager.data = SaveManager._default_data()
	var main := load("res://ui/main.gd").new() as Node
	add_child(main)
	for screen: StringName in [&"hub", &"workshop", &"map"]:
		GameState.goto(screen)
		await _shot(String(screen))
	# v0.6: stocked workshop (tiers, owned tools) and battle tool panel showing owned tools only.
	for map: MapData in DB.maps.slice(0, 5):
		for node: MapNodeData in map.nodes: SaveManager.award_star(node.level_id)
	SaveManager.add_material("compost", 120)
	SaveManager.add_material("scrap", 90)
	SaveManager.add_material("crystal", 6)
	SaveManager.add_upgrade("sprinkler")
	for id: String in ["sun_flask", "sun_magnet", "glue_trap", "frost_bottle"]: SaveManager.add_tool(id, 2)
	GameState.goto(&"workshop")
	await _shot("workshop_v06")
	var ws := main.get("current") as Node
	var scroll := ws.find_children("*", "ScrollContainer", true, false)
	if not scroll.is_empty():
		(scroll[0] as ScrollContainer).scroll_vertical = 100000
		await _shot("workshop_v06_upgrades")
	GameState.map_id = &"moon"
	GameState.level_id = &"moon_25"
	GameState.node_id = &"moon_25"
	GameState.goto(&"battle")
	await _shot("moon_seed_select")
	var battle := main.get("current") as Battle
	battle.hud._clear_overlay()
	battle.begin([&"sunbud", &"pod_shooter", &"bark_wall", &"frost_mint"] as Array[StringName])
	for r: int in 5:
		battle._make_plant(DB.plant(&"pod_shooter"),r,2)
	for i: int in 3:
		var z := battle.spawn_zombie(StringName(["gargantuan_granite","gargantuan_furnace","gargantuan_storm"][i]),i+1)
		z.position.x = 1220
	await _shot("moon_battle")
	get_tree().quit()
func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name+".png"))
	print("CAPTURE ",name)
