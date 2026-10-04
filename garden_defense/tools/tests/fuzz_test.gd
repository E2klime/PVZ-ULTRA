extends Node
## Randomised input fuzzer: drives real battle entry points (seeds, glove, shovel,
## workshop tools, pause, speed) on campaign, Endless and Daily levels and reports
## anything that reaches the error log. It does not judge balance.
## Run: godot --headless --path . --fixed-fps 60 res://tools/tests/fuzz_test.tscn -- [seconds] [level...]
## Use an isolated HOME: it replaces the in-memory save.

var _battle: Battle
var _rng := RandomNumberGenerator.new()
var _secs: float = 60.0
var _levels: Array[String] = []
var _actions: int = 0

func _ready() -> void:
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_float():
		_secs = float(args[0])
		args = args.slice(1)
	_levels.assign(args)
	if _levels.is_empty():
		_levels.assign(["lawn_03", "pool_04", "night_10", "desert_16", "roof_12", "frost_21", "factory_07", "moon_25", "endless:lawn", "endless:pool", "endless:roof", "daily"])
	_rng.seed = 7
	for lv: String in _levels:
		await _run(lv)
	print("FUZZ: done levels=%d actions=%d" % [_levels.size(), _actions])
	get_tree().quit(0)

func _run(lv: String) -> void:
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER: SaveManager.unlock_plant(id)
	for id: StringName in DB.ZOMBIE_ORDER: SaveManager.mark_zombie_seen(id)
	SaveManager.unlock_feature(&"graft")
	for id: String in ["sun_flask", "sun_magnet", "glue_trap", "frost_bottle"]: SaveManager.add_tool(id, 3)
	SaveManager.add_purchase(&"mower_kit", 2)
	GameState.custom_level = null
	GameState.custom_kind = &""
	if lv.begins_with("endless:"):
		GameState.start_endless(StringName(lv.get_slice(":", 1)))
	elif lv == "daily":
		GameState.start_daily()
	else:
		GameState.level_id = StringName(lv)
		GameState.node_id = StringName(lv)
	GameState.difficulty_id = DB.difficulties[_rng.randi() % DB.difficulties.size()].id
	_battle = Battle.new()
	add_child(_battle)
	await get_tree().process_frame
	if _battle.phase == Battle.Phase.SEED_SELECT:
		_battle.hud._clear_overlay()
		var pool: Array[StringName] = []
		for id: StringName in DB.PLANT_ORDER:
			var d := DB.plant(id)
			if d and not d.is_hybrid and id != &"lily_raft" and not _battle.level.banned_plants.has(id): pool.append(id)
		var ids: Array[StringName] = [&"sunbud", &"pod_shooter"]
		while ids.size() < 10 and not pool.is_empty():
			var pick: StringName = pool[_rng.randi() % pool.size()]
			if not ids.has(pick): ids.append(pick)
		if not _battle.level.fixed_seeds.is_empty(): ids = _battle.level.fixed_seeds.duplicate()
		_battle.begin(ids)
	print("FUZZ: start ", lv, " mode=", _battle.level.mode)
	var t := 0.0
	while t < _secs and _battle.phase == Battle.Phase.PLAYING:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if get_tree().paused:
			_battle.hud.toggle_pause()
		if _rng.randf() < 0.25:
			_step()
	print("FUZZ: end ", lv, " phase=", _battle.phase, " t=%.0f wave=%d" % [t, _battle.director.wave])
	_battle.queue_free()
	_battle = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	await get_tree().process_frame
	await get_tree().process_frame

func _cell() -> Vector2i:
	return Vector2i(_rng.randi() % Board.COLS, _rng.randi() % Board.ROWS)

func _step() -> void:
	_actions += 1
	var b := _battle
	if _rng.randf() < 0.3: b.sun += 75
	var roll := _rng.randf()
	if roll < 0.55 and not b.seeds.is_empty():
		b.select_seed(_rng.randi() % b.seeds.size(), _rng.randf() < 0.5)
		b._act_on_cell(_cell())
	elif roll < 0.68:
		if not b.glove: b.toggle_glove()
		if b.glove:
			b._act_on_cell(_cell())
			if b.glove: b._act_on_cell(_cell())
	elif roll < 0.73:
		b.toggle_shovel()
		if b.shovel: b._act_on_cell(_cell())
	elif roll < 0.78:
		CraftingSystem.use_tool(b, ["sun_flask", "sun_magnet", "glue_trap", "frost_bottle"][_rng.randi() % 4])
	elif roll < 0.82:
		b.mission_actions.fire(_cell())
		b.mission_actions.repair(_cell())
	elif roll < 0.84:
		b.hud.toggle_speed()
	elif roll < 0.85:
		b.hud.toggle_pause()
	elif roll < 0.86:
		b.restore_mower()
	elif roll < 0.88:
		var top := b.top_plant(_cell())
		if top: b.hud.show_plant_info(top)
	elif roll < 0.9:
		b.director.skip_to_next_wave()
	else:
		b._update_hover(Board.cell_center(_cell().y, _cell().x))
	b._try_collect_sun(Board.cell_center(_cell().y, _cell().x))
