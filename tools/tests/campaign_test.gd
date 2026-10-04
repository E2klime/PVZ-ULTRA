extends Node
## Contract/instantiation coverage, not a substitute for 200 human balance playthroughs.
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CAMPAIGN TEST: " + message)

func _ready() -> void:
	Engine.max_fps = 0
	SaveManager.data = SaveManager._default_data()
	check(DB.maps.size() == 8, "eight maps")
	check(DB.levels.size() == 200, "exactly 200 levels")
	check(DB.zombies.size() == 49, "49 enemies")
	check(DB.recipes.size() == 32, "32 graft recipes (incl. 4 twin/same-plant hybrids)")
	check(CraftingSystem.recipes().size() == 20, "20 workshop recipes")
	check(CampaignProgress.level_unlocked(&"lawn_01"), "first mission available")
	check(not CampaignProgress.level_unlocked(&"lawn_02"), "second mission locked")
	check(not CampaignProgress.world_unlocked(&"pool"), "second world locked")
	var no_plant := 0
	for map: MapData in DB.maps:
		check(map.nodes.size() == 25, "%s has 25 nodes" % map.id)
		for node: MapNodeData in map.nodes:
			var level := DB.level(node.level_id)
			check(level != null, "node references level")
			check(level.water.size() == 5, "five field rows")
			for line: String in level.water: check(line.length() == 9, "nine field columns")
			check(not level.wave_specs.is_empty(), "explicit waves")
			for wave: Dictionary in level.wave_specs:
				for spawn: Dictionary in wave["spawns"]:
					check(DB.zombie(StringName(spawn["id"])) != null, "known enemy")
					check(int(spawn["row"]) >= 0 and int(spawn["row"]) < 5, "legal lane")
			if level.mode != &"defense": no_plant += 1
			GameState.level_id = level.id
			GameState.map_id = map.id
			GameState.node_id = node.id
			var battle := Battle.new()
			add_child(battle)
			await get_tree().process_frame
			if level.mode == &"defense":
				var ids: Array[StringName] = [&"sunbud", &"pod_shooter", &"bark_wall", &"frost_mint"]
				if not level.fixed_seeds.is_empty(): ids = level.fixed_seeds.duplicate()
				battle.hud._clear_overlay()
				battle.begin(ids)
			check(battle.phase == Battle.Phase.PLAYING, "mission starts %s" % level.id)
			if level.mode == &"holdout":
				check(battle.board.all_plants().size() == 25, "prepared garden")
				var plant := battle.board.get_plant(0, 5)
				plant.hp -= 1500
				var before := plant.hp
				battle.mission_actions.repair(Vector2i(5, 0))
				check(plant.hp == before + 1200, "free repair heals without planting")
			if level.mode == &"artillery":
				check(battle.seeds.is_empty(), "artillery has no seeds")
				var enemy := battle.spawn_zombie(&"shambler", 2)
				enemy.position.x = Board.cell_center(2, 4).x
				battle.mission_actions.fire(Vector2i(4, 2))
				check(not enemy.is_alive(), "artillery damages enemies")
			var allowed := not battle.objectives.planting_error(Vector2i(2, 2)).is_empty()
			check(allowed if level.mode != &"defense" else true, "no-plant rule enforced")
			battle.director.skip_to_next_wave()
			await get_tree().physics_frame
			await get_tree().physics_frame
			check(battle.director.wave == 1, "authored wave starts")
			battle.phase = Battle.Phase.LOST
			battle.queue_free()
			await get_tree().process_frame
		print("CAMPAIGN TEST: instantiated all 25 missions in ", map.id)
	check(no_plant == 16, "16 plant-free missions")
	await _objectives()
	await _enemies()
	_crafting()
	await _v06()
	_progression()
	await _screens()
	print("CAMPAIGN TEST: checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _objectives() -> void:
	GameState.level_id = &"lawn_06"
	var b := Battle.new()
	add_child(b)
	await get_tree().process_frame
	b.hud._clear_overlay()
	b.begin([&"pod_shooter"] as Array[StringName])
	b.sun = 9999
	b.selected = 0
	b.objectives.planted = 20
	check(not b.evaluate(Vector2i(1, 1))["ok"], "21st planting denied")
	b.level = DB.level(&"lawn_14")
	b.objectives.losses = 5
	b.objectives.tick(0)
	check(b.objectives.failure == "", "five losses legal")
	b.objectives.losses = 6
	b.objectives.tick(0)
	check(b.objectives.failure != "", "sixth loss fails")
	b.objectives.failure = ""
	b.level = DB.level(&"lawn_22")
	b.objectives.collected = 3999
	check(not b.objectives.fulfilled(), "3999 sun insufficient")
	b.objectives.collected = 4000
	check(b.objectives.fulfilled(), "4000 collected sufficient")
	b.level = DB.level(&"lawn_09")
	b.sun = 3999
	check(not b.objectives.fulfilled(), "bank checks current sun, not total")
	b.sun = 4000
	check(b.objectives.fulfilled(), "4000 banked sufficient")
	b.level = DB.level(&"lawn_15")
	b.objectives.grafts = 1
	check(not b.objectives.fulfilled(), "two grafts required")
	b.objectives.grafts = 2
	check(b.objectives.fulfilled(), "two grafts counted")
	b.phase = Battle.Phase.LOST
	b.queue_free()
	await get_tree().process_frame

func _enemies() -> void:
	GameState.level_id = &"lawn_01"
	var b := Battle.new()
	add_child(b)
	await get_tree().process_frame
	b.hud._clear_overlay()
	b.begin([&"pod_shooter"] as Array[StringName])
	b.director.active = false
	for id: StringName in DB.ZOMBIE_ORDER:
		var z := b.spawn_zombie(id, 2)
		check(z != null, "instantiate zombie %s" % id)
		z.position.x = 1050
		z.hp = z.max_hp * 0.45
		z.freeze(0.1)
		z.take_damage(1)
	for r: int in 5:
		b._make_plant(DB.plant(&"bark_wall"), r, 5)
	var t := 0.0
	while t < 16.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	check(b.alive_zombie_count() > 46, "summoners, giants and split offspring spawn")
	for lane: Array in b.lanes:
		for z: Zombie in lane.duplicate(): z.take_damage(999999, &"mower")
	check(b.alive_zombie_count() == 0, "all enemy deaths remove lane references")
	b.phase = Battle.Phase.LOST
	b.queue_free()
	await get_tree().process_frame

func _crafting() -> void:
	SaveManager.data = SaveManager._default_data()
	check(not CraftingSystem.craft("sun_flask"), "insufficient materials reject craft")
	SaveManager.add_material("compost", 10)
	SaveManager.add_material("scrap", 10)
	check(CraftingSystem.craft("sun_flask"), "valid craft succeeds")
	check(SaveManager.material("compost") == 7 and SaveManager.material("scrap") == 9, "exact costs")
	check(SaveManager.tool_count("sun_flask") == 1, "tool inventory increases")
	check(not CraftingSystem.craft("frost_bottle"), "later-world craft locked")
	SaveManager.save_game()
	SaveManager.load_game()
	check(SaveManager.tool_count("sun_flask") == 1, "craft inventory persists")

## v0.6 regression coverage: audit fixes, upgrades, new tools, soft-lock guard.
func _v06() -> void:
	check(Board.neighbor_row(4) == 3 and Board.neighbor_row(0) == 1 and Board.neighbor_row(2) == 3, "split lane never wraps")
	SaveManager.data = SaveManager._default_data()
	SaveManager.data["star_levels"] = []
	for map: MapData in DB.maps:
		for node: MapNodeData in map.nodes: SaveManager.award_star(node.level_id)
	SaveManager.add_material("compost", 500)
	SaveManager.add_material("scrap", 500)
	SaveManager.add_material("crystal", 50)
	check(not CraftingSystem.craft("sprinkler_2"), "upgrade tier 2 needs tier 1")
	check(CraftingSystem.craft("sprinkler_1"), "upgrade tier 1 crafts")
	check(not CraftingSystem.craft("sprinkler_1"), "installed tier cannot be re-bought")
	check(CraftingSystem.craft("sprinkler_2"), "upgrade tier 2 after tier 1")
	check(is_equal_approx(SaveManager.recharge_mult(), 0.9), "sprinkler reduces recharge")
	var seed := SeedState.new(DB.plant(&"pod_shooter"))
	seed.trigger()
	check(is_equal_approx(seed.cooldown, DB.plant(&"pod_shooter").recharge * 0.9), "seed uses upgraded recharge")
	check(CraftingSystem.craft("sun_magnet") and CraftingSystem.craft("glue_trap") and CraftingSystem.craft("sun_flask"), "new tools craft")
	SaveManager.save_game()
	check(not FileAccess.file_exists("user://save.json.tmp"), "atomic save leaves no temp file")
	SaveManager.load_game()
	check(SaveManager.upgrade_level("sprinkler") == 2, "upgrades persist")
	GameState.level_id = &"lawn_22"
	var b := Battle.new()
	add_child(b)
	await get_tree().process_frame
	b.hud._clear_overlay()
	b.begin([&"pod_shooter"] as Array[StringName])
	b.director.active = false
	var before := b.objectives.collected
	check(CraftingSystem.use_tool(b, "sun_flask"), "sun flask usable")
	check(b.objectives.collected == before, "bought sun does not count as collected")
	var z := b.spawn_zombie(&"shambler", 1)
	check(CraftingSystem.use_tool(b, "glue_trap") and z.slow_t > 0.0, "glue trap slows the field")
	b.spawn_sun(Vector2(900, 500), 25, false)
	check(CraftingSystem.use_tool(b, "sun_magnet"), "sun magnet collects tokens")
	z.take_damage(999999, &"mower")
	# Soft-lock guard: cleared field, unmet collect goal, no income -> clean failure.
	for child: Node in b.sun_layer.get_children(): child.queue_free()
	await get_tree().process_frame
	b.director.finished = true
	b.level.sky_sun = false
	b.objectives.collected = 0
	for i: int in 70: b.objectives.tick(1.0)
	check(b.objectives.failure != "", "stalled economy objective fails instead of soft-locking")
	b.phase = Battle.Phase.LOST
	b.queue_free()
	await get_tree().process_frame
	DB.level(&"lawn_22").sky_sun = true
	# Crowd hold is bounded per wave.
	GameState.level_id = &"lawn_11"
	var c := Battle.new()
	add_child(c)
	await get_tree().process_frame
	c.hud._clear_overlay()
	c.begin([&"pod_shooter"] as Array[StringName])
	for i: int in 14:
		var crowd := c.spawn_zombie(&"shambler", i % 5)
		crowd.position.x = Board.SPAWN_X
		crowd.stun(999.0)
	c.director._timer = 0.0
	var start_wave := c.director.wave
	for i: int in 20 * 60: c.director._physics_process(1.0 / 60.0)
	check(c.director.wave > start_wave, "crowded lawn delays the next wave by at most 15 s")
	c.phase = Battle.Phase.LOST
	c.queue_free()
	await get_tree().process_frame
	SaveManager.data = SaveManager._default_data()

func _progression() -> void:
	SaveManager.data = SaveManager._default_data()
	for map: MapData in DB.maps:
		check(CampaignProgress.world_unlocked(map.id), "world opens after previous fully cleared")
		for node: MapNodeData in map.nodes:
			check(CampaignProgress.level_unlocked(node.level_id), "next level opens sequentially")
			SaveManager.award_star(node.level_id)
			SaveManager.complete_node(node.id)
		check(CampaignProgress.world_cleared(map.id), "world marked complete")
	check(CampaignProgress.finished(), "200 clears complete campaign")
	var migrated := SaveManager._migrate({"save_version":2,"star_levels":["lawn_01","lawn_bonus_1"],"completed_nodes":["n_01"]})
	check("lawn_01" in migrated["completed_nodes"], "legacy level migrated")
	check(not "lawn_bonus_1" in migrated["completed_nodes"], "bonus cannot bypass campaign")

func _screens() -> void:
	var main := load("res://ui/main.gd").new() as Node
	add_child(main)
	for screen: StringName in [&"hub", &"workshop", &"map", &"almanac", &"settings", &"menu"]:
		GameState.goto(screen, {"back": &"hub"})
		await get_tree().process_frame
		await get_tree().process_frame
		check(main.get("current") != null, "screen opens " + String(screen))
	main.queue_free()
	await get_tree().process_frame
