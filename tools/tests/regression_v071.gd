extends Node
## Contract checks for the v0.7.1 audit fixes. Prints REG lines and a summary;
## exits 1 on any failure. Use an isolated HOME (it replaces the in-memory save).
## Run: godot --headless --path . --fixed-fps 60 res://tools/tests/regression_v071.tscn

var _checks: int = 0
var _fails: int = 0

func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("REG FAIL: ", what)

func _ready() -> void:
	Engine.max_fps = 0
	_layout()
	_save_sanitize()
	_daily()
	await _battle_checks()
	print("REG RESULT: checks=%d failures=%d" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)

func _layout() -> void:
	var lv := LevelData.new()
	_ok(lv.tile(2, 4) == "." and not lv.is_blocked(2, 4), "empty layout reads as lawn")
	lv.water = PackedStringArray(["..#", "~"])
	_ok(lv.is_blocked(0, 2), "blocked tile found")
	_ok(lv.tile(1, 0) == "~" and lv.tile(1, 7) == "." and lv.tile(4, 0) == ".", "short rows and missing rows are lawn")

func _save_sanitize() -> void:
	var sm := SaveManager
	var d := sm._default_data()
	_ok(sm._sanitized("coins", "lots", 0) == 0, "string coins fall back to 0")
	_ok(sm._sanitized("coins", -50.0, 0) == 0, "negative coins clamp to 0")
	_ok(sm._sanitized("unlocked_plants", "sunbud", d["unlocked_plants"]) == d["unlocked_plants"], "non-list unlocks fall back")
	_ok(sm._sanitized("unlocked_plants", ["a", "a", null, 3], []) == ["a", "3"], "lists dedupe and drop nulls")
	var mats: Dictionary = sm._sanitized("materials", {"compost": 4.0, "scrap": "x"}, d["materials"])
	_ok(int(mats["compost"]) == 4 and int(mats["scrap"]) == 0 and mats.has("crystal"), "counters keep numbers and default keys")
	_ok(sm._sanitized("materials", [1, 2], d["materials"]) is Dictionary, "non-dict materials fall back")

func _daily() -> void:
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER: SaveManager.unlock_plant(id)
	var bans: Array = []
	for i: int in 3:
		GameState.start_daily()
		var b := GameState.custom_level.banned_plants.duplicate()
		bans.append(b)
		_ok(b.size() == 3, "daily bans three plants")
		var uniq := {}
		for id: StringName in b: uniq[id] = true
		_ok(uniq.size() == b.size(), "daily bans are distinct")
		_ok(not b.has(&"sunbud") and not b.has(&"pod_shooter") and not b.has(&"lily_raft"), "starters/raft never banned")
	_ok(bans[0] == bans[1] and bans[1] == bans[2], "daily bans identical across attempts")
	GameState.custom_level = null
	GameState.custom_kind = &""

func _new_battle(level: StringName, seeds: Array[StringName]) -> Battle:
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER: SaveManager.unlock_plant(id)
	SaveManager.unlock_feature(&"graft")
	GameState.level_id = level
	GameState.node_id = level
	GameState.difficulty_id = &"standard"
	var b := Battle.new()
	add_child(b)
	await get_tree().process_frame
	b.hud._clear_overlay()
	b.begin(seeds)
	return b

func _battle_checks() -> void:
	# Endless on the lawn has no layout: planting must work without script errors.
	SaveManager.data = SaveManager._default_data()
	GameState.start_endless(&"lawn")
	var e := Battle.new()
	add_child(e)
	await get_tree().process_frame
	e.hud._clear_overlay()
	e.begin([&"sunbud", &"pod_shooter"] as Array[StringName])
	e.sun = 500
	e.select_seed(0, false)
	var ev := e.evaluate(Vector2i(3, 2))
	_ok(ev["ok"] and ev["error"] == "", "endless lawn planting evaluates cleanly")
	_ok(e.objectives.planting_error(Vector2i(8, 4)) == "", "endless planting_error on empty layout")
	e.queue_free()
	GameState.custom_level = null
	GameState.custom_kind = &""
	await get_tree().process_frame

	var b := await _new_battle(&"lawn_05", [&"sunbud", &"needle_volley", &"pod_shooter"] as Array[StringName])
	# Tools that would do nothing are kept.
	SaveManager.add_tool("frost_bottle", 1)
	SaveManager.add_tool("seed_clock", 1)
	SaveManager.add_tool("repair_kit", 1)
	for s: SeedState in b.seeds: s.cooldown = 0.0
	_ok(not CraftingSystem.use_tool(b, "frost_bottle") and SaveManager.tool_count("frost_bottle") == 1, "frost bottle kept with no zombies")
	_ok(not CraftingSystem.use_tool(b, "seed_clock") and SaveManager.tool_count("seed_clock") == 1, "seed clock kept with nothing recharging")
	_ok(not CraftingSystem.use_tool(b, "repair_kit") and SaveManager.tool_count("repair_kit") == 1, "repair kit kept at full integrity")
	b.seeds[0].cooldown = 3.0
	_ok(CraftingSystem.use_tool(b, "seed_clock") and SaveManager.tool_count("seed_clock") == 0, "seed clock used when a seed recharges")
	# A piercing shot keeps going after killing the first zombie (lane array mutation).
	var z1 := b.spawn_zombie(&"shambler", 2)
	var z2 := b.spawn_zombie(&"shambler", 2)
	var z3 := b.spawn_zombie(&"shambler", 2)
	for i: int in 3:
		var z: Zombie = [z1, z2, z3][i]
		z.position.x = 900.0 + i * 4.0
		z.hp = 1.0
		z.armor = 0.0
		z.set_physics_process(false)
	var src := DB.plant(&"needle_volley")
	b.spawn_projectile(2, Vector2(840, z1.position.y - 60), 50.0, src)
	for i: int in 30: await get_tree().physics_frame
	_ok(not z1.is_alive() and not z2.is_alive() and not z3.is_alive(), "pierce kills every zombie it passes")
	# One-shot lane attacks hit every zombie even when earlier ones die mid-loop.
	var fern := b._make_plant(DB.plant(&"gale_fern"), 3, 1)
	var hit: Array[Zombie] = []
	for i: int in 3:
		var z := b.spawn_zombie(&"shambler", 3)
		z.position.x = fern.position.x + 120.0 + i * 30.0
		z.hp = 1.0
		z.armor = 0.0
		z.set_physics_process(false)
		hit.append(z)
	fern._cd = 0.0
	fern.tick(0.016)
	_ok(hit.all(func(z: Zombie) -> bool: return not z.is_alive()), "gust hits every zombie in range")
	# Puzzle glove cooldown drives the HUD sweep from its own maximum.
	b.glove_cd = 3.0
	b.glove_cd_max = 3.0
	await get_tree().process_frame  # emitted before _process callbacks: wait one more frame
	await get_tree().process_frame
	_ok(absf(b.hud.glove_btn.cooldown - 1.0) < 0.05, "glove sweep normalised by its own cooldown (%.2f, phase %d)" % [b.hud.glove_btn.cooldown, b.phase])
	# A zombie reaching an idle mower is cut by it and does not also breach the gate.
	var gate := b.base_integrity
	var mower := b.mowers[1]
	var walker := b.spawn_zombie(&"shambler", 1)
	walker.position.x = mower.position.x + Mower.TRIGGER_REACH + 6.0
	for i: int in 240:
		await get_tree().physics_frame
		if mower.state == Mower.MowerState.USED: break
	_ok(mower.state != Mower.MowerState.IDLE, "zombie at the mower triggers it")
	_ok(not is_instance_valid(walker) or not walker.is_alive(), "mower kills the zombie that triggered it")
	_ok(b.base_integrity == gate and b.objectives.breaches == 0, "mower run costs no gate integrity")
	# With the mower used, the next zombie in that lane breaches.
	var late := b.spawn_zombie(&"shambler", 1)
	late.position.x = Board.HOUSE_X - 1.0
	for i: int in 30: await get_tree().physics_frame
	_ok(b.base_integrity < gate, "empty mower slot lets a zombie breach")
	# Hit-stop never leaves the game slowed after the battle ends.
	b._win()
	b.hit_stop(0.05)
	_ok(is_equal_approx(Engine.time_scale, 1.0), "no hit-stop after the battle ended")
	b.queue_free()
	await get_tree().process_frame
