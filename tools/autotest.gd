extends Node
## Headless smoke test + bot playthrough.
## Run: godot --headless --path . --fixed-fps 60 res://tools/autotest.tscn -- [level_id] [difficulty]

var _battle: Battle
var _t: float = 0.0
var _bot_t: float = 0.0
var _level: StringName = &"lawn_13"
var _diff: StringName = &"hard_plus"
var _layout: Array = []
var _log_t: float = 0.0
var _grafts: int = 0
var _mech_mode: bool = false

func _ready() -> void:
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_level = StringName(args[0])
	if args.size() > 1:
		_diff = StringName(args[1])
	_check_scripts()
	if _level == &"mech":
		_mech_mode = true
		await _mech()
		return
	await _check_screens()
	# Unlock everything for the bot.
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER:
		SaveManager.unlock_plant(id)
	SaveManager.unlock_feature(&"graft")
	GameState.level_id = _level
	GameState.node_id = &"test"
	GameState.difficulty_id = _diff
	_battle = Battle.new()
	add_child(_battle)
	await get_tree().process_frame
	var lvl := _battle.level
	var ids: Array[StringName] = [&"sunbud", &"pod_shooter", &"bark_wall", &"frost_mint", &"snapper_trap", &"thorn_mine", &"ember_berry", &"lantern_bloom", &"pepper_stinger", &"twin_pod"]
	if not lvl.fixed_seeds.is_empty():
		ids = lvl.fixed_seeds.duplicate()
	_battle.begin(ids)
	print("TEST: battle started level=%s diff=%s waves=%d" % [_level, _diff, lvl.waves])
	# Plan: col0-1 sunbud, col2-4 shooters, col5 frost, col7 walls
	for r: int in 5:
		_layout.append([[0, &"sunbud"], [2, &"pod_shooter"], [1, &"sunbud"], [3, &"pod_shooter"], [7, &"bark_wall"], [4, &"frost_mint"], [5, &"pepper_stinger"], [6, &"lantern_bloom"]])

func _check_scripts() -> void:
	var bad := 0
	for dir: String in ["res://core", "res://core/data", "res://entities/plants", "res://entities/zombies", "res://entities/projectiles", "res://entities/effects", "res://ui", "res://autoload"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s := load(dir.path_join(f)) as GDScript
				if s == null or not s.can_instantiate():
					print("TEST: script failed: ", f)
					bad += 1
	print("TEST: scripts checked, failures=", bad)

func _check_screens() -> void:
	var main: Node = load("res://ui/main.gd").new()
	add_child(main)
	for s: StringName in [&"loading", &"menu", &"help", &"stats", &"hub", &"map", &"almanac", &"quests", &"shop", &"settings", &"workshop", &"menu"]:
		GameState.goto(s, {"back": &"menu"})
		for i: int in 3:
			await get_tree().process_frame
		print("TEST: screen ok ", s)
	main.queue_free()
	await get_tree().process_frame

func _physics_process(delta: float) -> void:
	if _mech_mode or _battle == null or _battle.phase == Battle.Phase.SEED_SELECT:
		return
	_t += delta
	_log_t += delta
	for m: Mower in _battle.mowers:
		if m.state == Mower.MowerState.RUNNING and not m.has_meta("logged"):
			m.set_meta("logged", true)
			print("TEST: mower row %d triggered t=%.0f" % [m.row, _t])
	if _log_t > 30.0:
		_log_t = 0.0
		print("TEST: t=%.0f wave=%d/%d sun=%d zombies=%d plants=%d hybrids=%d" % [_t, _battle.director.wave, _battle.level.waves, _battle.sun, _battle.alive_zombie_count(), _battle.board.all_plants().size(), _battle.hybrid_count()])
	if _battle.phase == Battle.Phase.WON or _battle.phase == Battle.Phase.LOST:
		print("TEST: RESULT %s at t=%.0f lost_mower=%s grafts=%d kills=%d" % ["WIN" if _battle.phase == Battle.Phase.WON else "LOSE", _t, _battle.lost_mower, _grafts, SaveManager.stat(&"kills")])
		print("TEST: result dict ", GameState.last_result)
		for r: int in 5:
			var names: Array[String] = []
			for c: int in 9:
				var p := _battle.board.get_plant(r, c)
				names.append(String(p.data.id).substr(0, 6) if p else "-")
			var zs: Array[String] = []
			for z: Zombie in _battle.zombies_in_row(r):
				zs.append("%s@%d hp%d st%d" % [z.data.id, z.position.x, z.hp + z.armor, z.state])
			print("ROW %d: %s | %s | mower=%d" % [r, " ".join(names), ", ".join(zs), _battle.mowers[r].state])
		get_tree().paused = false
		set_physics_process(false)
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()
		return
	if _t > 1500.0:
		print("TEST: TIMEOUT")
		get_tree().quit()
		return
	_bot_t -= delta
	if _bot_t > 0.0:
		return
	_bot_t = 0.4
	for t: Node in _battle.sun_layer.get_children():
		var st := t as SunToken
		if st and not st.collected:
			st.collect()
	_bot_step()

func _lane_threat(r: int) -> float:
	var t := 0.0
	for z: Zombie in _battle.zombies_in_row(r):
		if z.position.x < Board.SPAWN_X:
			t += (z.hp + z.armor) / 270.0
	return t

func _count(r: int, ids: Array) -> int:
	var n := 0
	for c: int in 9:
		# All layers: v0.7 under/shell/air plants share cells with the main plant.
		for p: Plant in _battle.board.cell_plants(r, c):
			if ids.has(p.data.id) and not p.dead:
				n += 1
	return n

func _free_col(r: int, cols: Array) -> int:
	# Prefer lawn cells; water cells cost an extra raft.
	for wet: bool in [false, true]:
		for c: int in cols:
			if _battle.board.is_water(r, c) != wet:
				continue
			var p := _battle.board.get_plant(r, c)
			if p == null or p.data.id == &"lily_raft":
				return c
	return -1

const SHOOTERS := [&"pod_shooter", &"twin_pod", &"frost_mint", &"pepper_stinger", &"glacier_shooter", &"needle_volley"]

func _bot_step() -> void:
	# 1) emergency: a zombie deep in a lane
	for r: int in 5:
		for z: Zombie in _battle.zombies_in_row(r):
			if z.is_targetable() and z.position.x < Board.ORIGIN.x + Board.CELL.x * 2.5 and _lane_threat(r) >= 2.0:
				var c := clampi(Board.x_to_col(z.position.x), 0, 8)
				if _try(&"ember_berry", r, c) or _try(&"snapper_trap", r, clampi(c - 1, 0, 8)):
					return
	# 2) every threatened lane needs firepower proportional to threat
	var lanes: Array[int] = [0, 1, 2, 3, 4]
	lanes.sort_custom(func(a: int, b: int) -> bool: return _lane_threat(a) > _lane_threat(b))
	for r: int in lanes:
		var need := 1 + int(_lane_threat(r) / 2.5)
		if _count(r, SHOOTERS) < min(need, 4):
			var c := _free_col(r, [2, 3, 4, 1, 5])
			var id: StringName = &"frost_mint" if _count(r, [&"frost_mint", &"glacier_shooter"]) == 0 and _count(r, SHOOTERS) >= 1 else &"pod_shooter"
			if c >= 0 and (_try(id, r, c) or _try(&"pepper_stinger", r, c) or _try(&"twin_pod", r, c)):
				return
			if _lane_threat(r) > 0.0:
				return   # save sun for this lane
	# 2b) a cheap wall in front of lanes under pressure
	for r: int in lanes:
		if _lane_threat(r) >= 2.0 and _count(r, SHOOTERS) >= 1 and _count(r, [&"bark_wall", &"ironbark_wall"]) == 0:
			var wc := _free_col(r, [6, 7, 5])
			if wc >= 0 and _try(&"bark_wall", r, wc):
				return
	# 3) economy: up to 8 sunbuds
	var buds := 0
	for r: int in 5:
		buds += _count(r, [&"sunbud", &"twin_sunbud", &"dawn_bloom"])
	if buds < 8:
		for r: int in [2, 1, 3, 0, 4]:
			var c := _free_col(r, [0, 1])
			if c >= 0 and _try(&"sunbud", r, c):
				return
	# 4) baseline: one shooter per lane, walls on threatened lanes
	for r: int in 5:
		if _count(r, SHOOTERS) == 0:
			var c := _free_col(r, [2, 3])
			if c >= 0 and _try(&"pod_shooter", r, c):
				return
	for r: int in lanes:
		if _lane_threat(r) > 1.5 and _battle.board.get_plant(r, 7) == null and _try(&"bark_wall", r, 7):
			return
	if _battle.sun < 250:
		return
	# 5) surplus: graft / more shooters / lanterns
	for p: Plant in _battle.board.all_plants():
		if p.data.id == &"pod_shooter" and _try(&"frost_mint", p.row, p.col):
			_grafts += 1
			return
		if p.data.id == &"pod_shooter" and _try(&"pod_shooter", p.row, p.col):
			return
		if p.data.id == &"bark_wall" and p.hp < 2500 and _try(&"bark_wall", p.row, p.col):
			return
	for r: int in lanes:
		if _count(r, SHOOTERS) < 4:
			var c := _free_col(r, [2, 3, 4, 5])
			if c >= 0 and (_try(&"pepper_stinger", r, c) or _try(&"pod_shooter", r, c)):
				return
	for r: int in [1, 3]:
		if _battle.board.get_plant(r, 6) == null and _try(&"lantern_bloom", r, 6):
			return

func _try(id: StringName, r: int, c: int) -> bool:
	# Pool cells: float a Lily Raft first, then plant on it.
	if id != &"lily_raft" and _battle.board.is_water(r, c) and _battle.board.get_plant(r, c) == null:
		var ready := false
		for s: SeedState in _battle.seeds:
			if s.data.id == id and s.is_ready():
				ready = true
		if not ready or _battle.sun < 25 + DB.plant(id).cost or not _try(&"lily_raft", r, c):
			return false
	for i: int in _battle.seeds.size():
		if _battle.seeds[i].data.id == id:
			_battle.selected = i
			_battle.shovel = false
			var ev := _battle.evaluate(Vector2i(c, r))
			if ev["ok"]:
				if OS.get_environment("BOTLOG") != "":
					print("BOT t=%.0f %s r%d c%d sun=%d" % [_t, id, r, c, _battle.sun])
				_battle._act_on_cell(Vector2i(c, r))
				return true
			_battle.selected = -1
	return false

func _mech() -> void:
	SaveManager.data = SaveManager._default_data()
	GameState.level_id = &"lawn_01"
	GameState.difficulty_id = &"standard"
	_battle = Battle.new()
	add_child(_battle)
	await get_tree().process_frame
	_battle.begin([&"pod_shooter"] as Array[StringName])
	_battle.director.active = false
	var shooter := _battle._make_plant(DB.plant(&"pod_shooter"), 2, 2)
	var z := _battle.spawn_zombie(&"shambler", 2)
	var t := 0.0
	var first_hit := -1.0
	while is_instance_valid(z) and z.is_alive() and t < 120.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if first_hit < 0.0 and z.hp < z.max_hp:
			first_hit = t
	print("MECH: shambler died=%s t=%.1f first_hit=%.1f x=%.0f shooter_alive=%s" % [not (is_instance_valid(z) and z.is_alive()), t, first_hit, z.position.x if is_instance_valid(z) else -1.0, is_instance_valid(shooter) and not shooter.dead])
	var z2 := _battle.spawn_zombie(&"shambler", 0)
	var bud := _battle._make_plant(DB.plant(&"sunbud"), 0, 4)
	t = 0.0
	var eat_start := -1.0
	while is_instance_valid(bud) and not bud.dead and t < 120.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if eat_start < 0.0 and z2.state == Zombie.State.EAT:
			eat_start = t
	print("MECH: sunbud eaten after %.1fs (eat started %.1f) walk speed px/s=%.1f" % [t - eat_start, eat_start, (Board.SPAWN_X - z2.position.x) / max(0.1, eat_start)])
	await _mech_v03()
	await _mech_v04()
	await _mech_v07()
	await _mech_twins()
	get_tree().quit()

## v0.4: pool cells, Lily Raft stacking, swimming zombies.
func _mech_v04() -> void:
	await _clear_lanes()
	_battle.board.set_layout(PackedStringArray([".........", "..~~~~...", ".~~~~~~..", "..~~.~~..", "........."]))
	_battle.seeds.clear()
	_battle.seeds.append(SeedState.new(DB.plant(&"lily_raft")))
	_battle.seeds.append(SeedState.new(DB.plant(&"pod_shooter")))
	_battle.sun = 9999
	_battle.selected = 1
	var ev := _battle.evaluate(Vector2i(3, 2))
	print("MECH: shooter on bare water error=%s" % ev["error"])
	_battle.selected = 0
	_battle._act_on_cell(Vector2i(3, 2))
	var raft := _battle.board.get_plant(2, 3)
	_battle.selected = 1
	ev = _battle.evaluate(Vector2i(3, 2))
	print("MECH: raft placed=%s stack kind=%s ok=%s" % [raft != null and raft.data.id == &"lily_raft", ev["kind"], ev["ok"]])
	_battle._act_on_cell(Vector2i(3, 2))
	var top := _battle.board.get_plant(2, 3)
	print("MECH: stacked=%s on_raft=%s" % [top.data.id, top.on_raft])
	top.take_damage(99999.0)
	await _wait_s(0.2)
	var after := _battle.board.get_plant(2, 3)
	print("MECH: raft restored after plant died=%s" % [after != null and after.data.id == &"lily_raft"])
	_battle.selected = 0
	ev = _battle.evaluate(Vector2i(0, 0))
	print("MECH: raft on lawn error=%s" % ev["error"])
	_battle.selected = -1
	var z := _battle.spawn_zombie(&"shambler", 2)
	z.position.x = Board.cell_center(2, 6).x + 40.0
	await _wait_s(1.5)
	print("MECH: zombie swimming submerge=%.2f (water=%s)" % [z.submerge, _battle.board.water_at(2, z.position.x)])

func _wait_s(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().physics_frame
		t += 1.0 / 60.0

func _clear_lanes() -> void:
	for lane: Array in _battle.lanes:
		for z: Zombie in lane.duplicate():
			z.despawn()
	for p: Plant in _battle.board.all_plants():
		p.die(true)
	await get_tree().physics_frame

## v0.3: animation state, Rime Lettuce freeze, legendary rules.
func _mech_v03() -> void:
	await _clear_lanes()
	# --- animation players drive poses
	var z := _battle.spawn_zombie(&"shambler", 1)
	var oak := _battle._make_plant(DB.plant(&"elder_oak"), 4, 6)
	await _wait_s(1.5)
	var c0 := z.pose_cycle
	await _wait_s(0.5)
	print("MECH: anim zombie=%s cycle_moves=%s speed_scale=%.2f plant=%s" % [z.anim.current_animation, not is_equal_approx(c0, z.pose_cycle), z.anim.speed_scale, oak.anim.current_animation])
	# --- Rime Lettuce: freezes the first zombie, then single use
	var lettuce := _battle._make_plant(DB.plant(&"rime_lettuce"), 1, 7)
	var t := 0.0
	while not z.is_frozen() and t < 60.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	var x_frozen := z.position.x
	await _wait_s(5.0)
	print("MECH: rime frozen=%s lettuce_gone=%s moved_while_frozen=%.1f anim_speed=%.2f" % [z.is_frozen(), not is_instance_valid(lettuce) or lettuce.dead, absf(z.position.x - x_frozen), z.anim.speed_scale])
	await _wait_s(5.5)
	print("MECH: rime thawed=%s slowed_after=%s" % [not z.is_frozen(), z.slow_t > 0.0])
	var brute := _battle.spawn_zombie(&"brute", 2)
	brute.freeze(10.0)
	print("MECH: brute freeze time=%.1f (expect 5.0)" % brute.freeze_t)
	await _clear_lanes()
	# --- legendary: one per board
	_battle.seeds.clear()
	_battle.seeds.append(SeedState.new(DB.plant(&"elder_oak")))
	_battle.sun = 9999
	_battle._make_plant(DB.plant(&"elder_oak"), 0, 5)
	_battle.selected = 0
	var ev := _battle.evaluate(Vector2i(6, 3))
	print("MECH: legendary second copy error=%s" % ev["error"])
	_battle.selected = -1
	# --- Elder Oak regrows when left alone
	var o2: Plant = _battle.board.get_plant(0, 5)
	o2.take_damage(3000.0)
	var hp_hit := o2.hp
	await _wait_s(6.0)
	print("MECH: elder_oak regen %.0f -> %.0f" % [hp_hit, o2.hp])
	# --- Phoenix Lily rises once
	var ph := _battle._make_plant(DB.plant(&"phoenix_lily"), 2, 1)
	ph.take_damage(5000.0)
	var alive1 := not ph.dead
	ph.take_damage(5000.0)
	print("MECH: phoenix reborn=%s then_dead=%s" % [alive1, ph.dead])
	# --- Storm Thistle chains across lanes
	var st := _battle._make_plant(DB.plant(&"storm_thistle"), 3, 1)
	var zs: Array[Zombie] = []
	for r: int in [3, 3, 2, 4]:
		var zz := _battle.spawn_zombie(&"bucket_head", r)
		zz.position.x = 900.0 + zs.size() * 40.0
		zs.append(zz)
	st.age = 10.0
	await _wait_s(3.5)
	var hit := 0
	for zz: Zombie in zs:
		if is_instance_valid(zz) and zz.hp + zz.armor < zz.max_hp + zz.max_armor:
			hit += 1
	print("MECH: storm thistle zombies hit=%d of %d" % [hit, zs.size()])
	# --- death clip frees the zombie
	var zd := zs[0]
	zd.take_damage(99999.0)
	await _wait_s(0.2)
	var playing := zd.anim.current_animation if is_instance_valid(zd) else &"freed"
	await _wait_s(1.6)
	print("MECH: death clip=%s freed_after=%s" % [playing, not is_instance_valid(zd)])

## Hybrids only: same-plant pairs graft into twin hybrids, never star-ups.
func _mech_twins() -> void:
	await _clear_lanes()
	for p: Plant in _battle.board.all_plants():
		p.silent_removal = true
		p.die(true)
	await _wait_s(0.2)
	_battle.board.set_layout(PackedStringArray([".........", ".........", ".........", ".........", "........."]))
	SaveManager.unlock_feature(&"graft")
	_battle.level.allow_hybrids = true
	_battle.level.hybrid_cap = 9
	_battle.seeds.clear()
	for id: StringName in [&"pod_shooter", &"garlic_drone", &"rime_lettuce", &"sunbud"]:
		_battle.seeds.append(SeedState.new(DB.plant(id)))
	_battle.sun = 99999
	var cases := [[0, Vector2i(1, 0), &"twin_pod"], [1, Vector2i(1, 1), &""], [2, Vector2i(1, 2), &"glacier_shooter"], [3, Vector2i(1, 3), &"twin_sunbud"]]
	for c: Array in cases:
		var cell: Vector2i = c[1]
		var base_seed := 0 if c[0] == 2 else int(c[0])
		_battle.selected = base_seed
		_battle._act_on_cell(cell)
		for s2: SeedState in _battle.seeds: s2.cooldown = 0.0
	await _wait_s(4.0)
	for c: Array in cases:
		var cell: Vector2i = c[1]
		_battle.selected = int(c[0])
		var ev := _battle.evaluate(cell)
		_battle._act_on_cell(cell)
		for s2: SeedState in _battle.seeds: s2.cooldown = 0.0
		var top := _battle.board.get_plant(cell.y, cell.x)
		var got: StringName = top.data.id if top else &"none"
		var ok: bool = got == c[2] if c[2] != &"" else ev["error"] == "MSG_NO_RECIPE"
		print("TWIN: seed=%s kind=%s err=%s result=%s %s" % [_battle.seeds[int(c[0])].data.id, ev["kind"], ev["error"], got, "PASS" if ok else "FAIL"])
	print("TWIN: hybrids=%d twin_grafts_stat=%d" % [_battle.hybrid_count(), SaveManager.stat(&"twin_grafts")])

## v0.7: layers, twin grafts, glove moves / cross-layer grafts, box & balloon zombies.
func _mech_v07() -> void:
	await _clear_lanes()
	_battle.board.set_layout(PackedStringArray([".........", ".........", ".........", ".........", "........."]))
	_battle.seeds.clear()
	for id: StringName in [&"pea_bedding", &"pod_shooter", &"pumpkin_shell", &"garlic_drone", &"bramble_vine"]:
		_battle.seeds.append(SeedState.new(DB.plant(id)))
	_battle.sun = 99999
	var cell := Vector2i(2, 1)
	for i in 4:
		_battle.selected = i
		var ev := _battle.evaluate(cell)
		print("MECH7: layer seed=%s kind=%s ok=%s err=%s" % [_battle.seeds[i].data.id, ev["kind"], ev["ok"], ev["error"]])
		_battle._act_on_cell(cell)
		for s2: SeedState in _battle.seeds: s2.cooldown = 0.0
	print("MECH7: cell plants=%d top=%s" % [_battle.board.cell_plants(1, 2).size(), _battle.top_plant(cell).data.id])
	await _wait_s(4.0)
	_battle.selected = 1
	var ev2 := _battle.evaluate(cell)
	# Grafting is still locked here: the same seed must NOT upgrade the plant.
	print("MECH7: same seed on shooter (graft locked) kind=%s ok=%s err=%s" % [ev2["kind"], ev2["ok"], ev2["error"]])
	_battle._act_on_cell(cell)
	print("MECH7: shooter still=%s" % _battle.board.get_layer(1, 2, &"main").data.id)
	for s2: SeedState in _battle.seeds: s2.cooldown = 0.0
	# glove: move the shooter stack's pumpkin to a bramble -> thorn pumpkin
	_battle.selected = 4
	_battle._act_on_cell(Vector2i(4, 3))
	_battle.selected = -1
	SaveManager.unlock_feature(&"graft")
	_battle.level.allow_hybrids = true
	_battle.level.hybrid_cap = 9
	await _wait_s(4.0)
	_battle.glove_cd = 0.0
	_battle.top_plant(cell).die(true)
	await _wait_s(0.1)
	_battle.toggle_glove()
	_battle._act_on_cell(cell)
	print("MECH7: glove picked=%s" % [_battle.glove_plant.data.id if _battle.glove_plant else "none"])
	var dbg := FusionSystem.plan(_battle, _battle.board.get_plant(3, 4), _battle.glove_plant.data, true)
	print("MECH7: dbg plan kind=%d err=%s allow=%s cap=%d" % [dbg.kind, dbg.error_key, _battle.level.allow_hybrids, _battle.level.hybrid_cap])
	var gev := _battle.evaluate(Vector2i(4, 3))
	print("MECH7: glove onto bramble kind=%s ok=%s err=%s" % [gev["kind"], gev["ok"], gev["error"]])
	_battle._act_on_cell(Vector2i(4, 3))
	await _wait_s(0.2)
	var tp := _battle.top_plant(Vector2i(4, 3))
	print("MECH7: glove fuse result=%s" % [tp.data.id if tp else "none"])
	_battle.glove_cd = 0.0
	_battle.toggle_glove()
	_battle._act_on_cell(cell)
	_battle._act_on_cell(Vector2i(6, 0))
	await _wait_s(0.2)
	var moved := _battle.top_plant(Vector2i(6, 0))
	print("MECH7: glove move result=%s" % [moved.data.id if moved else "none"])
	# box zombie behind a shambler in front of a straight shooter
	await _clear_lanes()
	var sh := _battle._make_plant(DB.plant(&"pod_shooter"), 1, 1)
	var lead := _battle.spawn_zombie(&"shambler", 1)
	var box := _battle.spawn_zombie(&"box_zombie", 1)
	box.position.x = lead.position.x + 60.0
	await _wait_s(8.0)
	print("MECH7: box hittable straight=%s low=%s lob=%s; box hp %.0f/%.0f leader=%s" % [box.hittable_by(&"straight"), box.hittable_by(&"low"), box.hittable_by(&"lob"), box.hp, box.max_hp, box.leader == lead])
	await _clear_lanes()
	var drone := _battle._make_plant(DB.plant(&"garlic_drone"), 3, 2)
	var walker := _battle.spawn_zombie(&"shambler", 3)
	walker.position.x = Board.cell_center(3, 3).x
	await _wait_s(4.0)
	print("MECH7: shambler vs air drone eating=%s drone_hp=%.0f" % [walker.state == Zombie.State.EAT, drone.hp])
	await _clear_lanes()
	var drone2 := _battle._make_plant(DB.plant(&"garlic_drone"), 3, 2)
	var balloon := _battle.spawn_zombie(&"balloon_zombie", 3)
	balloon.position.x = Board.cell_center(3, 4).x
	await _wait_s(10.0)
	print("MECH7: balloon vs drone drone_alive=%s balloon_x=%.0f" % [is_instance_valid(drone2) and not drone2.dead, balloon.position.x if is_instance_valid(balloon) else -1.0])
