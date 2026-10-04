extends "res://tools/autotest.gd"
## No sun/HP cheats or crafted tools. Unlocks all seeds only to isolate combat balance.
var _limit: int = 0
## "standard" = v0.5 baseline strategy; "strong" adds evolutions, cheap mines and legendaries
## (still no cheats). Strong is the v0.6 balance reference for worlds 3–8.
var _strategy: StringName = &"standard"

func _ready() -> void:
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	_level = StringName(args[0]) if not args.is_empty() else &"lawn_01"
	_diff = StringName(args[1]) if args.size() > 1 else &"standard"
	_strategy = StringName(args[2]) if args.size() > 2 else &"standard"
	SaveManager.data = SaveManager._default_data()
	for id: StringName in DB.PLANT_ORDER: SaveManager.unlock_plant(id)
	SaveManager.unlock_feature(&"graft")
	GameState.level_id = _level
	GameState.node_id = _level
	GameState.difficulty_id = _diff
	GameState.map_id = DB.level(_level).world_id
	_battle = Battle.new()
	add_child(_battle)
	await get_tree().process_frame
	for o: Dictionary in _battle.level.objectives:
		if o["type"] == "plant_limit": _limit = int(o["target"])
	if _battle.level.mode == &"defense":
		_battle.hud._clear_overlay()
		var ids: Array[StringName] = [&"sunbud", &"pod_shooter", &"bark_wall", &"frost_mint", &"ember_berry", &"pepper_stinger", &"thorn_mine", &"rime_lettuce", &"lantern_bloom", &"twin_pod"]
		if _strategy == &"strong":
			ids = [&"sunbud", &"pod_shooter", &"bark_wall", &"frost_mint", &"ember_berry", &"pepper_stinger", &"thorn_mine", &"storm_thistle", &"phoenix_lily", &"snapper_trap"]
		# v0.7: Twin Pod is a graft-only hybrid now (Pod Shooter + Pod Shooter), never a seed.
		# Its slot and Lantern Bloom's go to counters for the new zombie profiles when the
		# level can spawn them: boxed (low) zombies ignore straight shots, balloons fly.
		ids.erase(&"twin_pod")
		var zpool := _battle.level.zombie_pool
		if zpool.has(&"box_zombie"): ids.append(&"pea_bedding")
		if zpool.has(&"balloon_zombie") or zpool.has(&"slingshot_zombie"):
			ids.erase(&"lantern_bloom")
			ids.append(&"spine_cactus")
		if not _battle.level.fixed_seeds.is_empty(): ids = _battle.level.fixed_seeds.duplicate()
		_battle.begin(ids)
	print("BOT: started ", _level)

func _physics_process(delta: float) -> void:
	if _battle == null: return
	_t += delta
	if _battle.phase in [Battle.Phase.WON, Battle.Phase.LOST]:
		print("BOT: %s %s t=%.1f waves=%d/%d plants=%d losses=%d sun=%d collected=%d grafts=%d reason=%s" % [_level, "WIN" if _battle.phase == Battle.Phase.WON else "LOSE", _t, _battle.director.wave, _battle.level.waves, _battle.objectives.planted, _battle.objectives.losses, _battle.sun, _battle.objectives.collected, _battle.objectives.grafts, _battle.objectives.failure])
		_quit(0 if _battle.phase == Battle.Phase.WON else 2)
		return
	if _t > 1100:
		print("BOT: TIMEOUT ", _level)
		_quit(3)
		return
	_bot_t -= delta
	if _bot_t > 0: return
	_bot_t = 0.25
	for child: Node in _battle.sun_layer.get_children():
		var sun := child as SunToken
		if sun and not sun.collected: sun.collect()
	if _battle.level.mode == &"artillery":
		var z := _battle.nearest_target(Board.ORIGIN)
		if z:
			_battle.mission_actions.fire(Vector2i(clampi(Board.x_to_col(z.position.x), 0, 8), z.row))
		return
	if _battle.level.mode == &"holdout":
		var damaged: Plant
		for p: Plant in _battle.board.all_plants():
			if p.hp < p.data.max_hp and (damaged == null or p.hp / p.data.max_hp < damaged.hp / damaged.data.max_hp): damaged = p
		if damaged: _battle.mission_actions.repair(Vector2i(damaged.col, damaged.row))
		return
	if _strategy == &"strong" and _strong_emergency(): return
	if _profile_counters(): return
	# Establish a cheap economy while the opening wave is still far away.
	var producers := 0
	for r: int in 5: producers += _count(r, [&"sunbud", &"twin_sunbud", &"dawn_bloom"])
	var max_producers := 4 if _limit > 0 else 7
	if producers < max_producers and (_battle.alive_zombie_count() == 0 or _battle.sun >= 150 or _t < 20):
		for r: int in [2,1,3,0,4]:
			for c: int in [0,1]:
				if _battle.board.get_plant(r,c) == null and _try(&"sunbud",r,c): return
	var rows: Array[int] = [0,1,2,3,4]
	rows.sort_custom(func(a: int,b: int) -> bool: return _lane_threat(a)>_lane_threat(b))
	# Cover empty lanes first. Avoid raft overhead on action-limited missions.
	for r: int in rows:
		if _count(r, SHOOTERS) < (1 if _lane_threat(r) < 1.5 else 2):
			for c: int in [2,3,4,1,5,6,7,8]:
				if _battle.board.get_plant(r,c) != null or not _safe_cell(r,c): continue
				if _limit > 0 and _battle.board.is_water(r,c): continue
				var id: StringName = &"frost_mint" if _count(r,SHOOTERS)>0 and _count(r,[&"frost_mint",&"glacier_shooter"])==0 else &"pod_shooter"
				# Under a planting cap, buy the most power per action.
				if _limit > 0 and _try(&"twin_pod",r,c): return
				if _try(id,r,c) or _try(&"pod_shooter",r,c): return
	# Two grafts use two actual catalysts on grown bases.
	if _battle.level.ordinal == 15 and _battle.objectives.grafts < 2:
		for p: Plant in _battle.board.all_plants():
			if p.data.id == &"pod_shooter" and p.age > 3 and _try(&"frost_mint",p.row,p.col): return
	for r: int in rows:
		if _lane_threat(r) >= 2 and _count(r,[&"bark_wall",&"ironbark_wall"]) == 0:
			for c: int in [7,6,5,8]:
				if _battle.board.get_plant(r,c)==null and not _battle.board.is_water(r,c) and _try(&"bark_wall",r,c): return
	if _limit > 0 and _battle.objectives.planted >= _limit: return
	# Emergency explosions are actual seed actions and obey mission caps.
	for r: int in rows:
		for z: Zombie in _battle.zombies_in_row(r):
			if z.position.x < 850 and _lane_threat(r)>3:
				if _try(&"ember_berry",r,clampi(Board.x_to_col(z.position.x),0,8)): return
	if producers < max_producers:
		for r: int in [2,1,3,0,4]:
			for c: int in [0,1]:
				if _battle.board.get_plant(r,c)==null and _try(&"sunbud",r,c): return
	# Under a planting cap, surplus sun goes into Twin Pod evolutions (one action, double fire).
	if _limit > 0 and _battle.sun >= 300 and _battle.objectives.planted < _limit:
		for p: Plant in _battle.board.all_plants():
			if p.data.id == &"pod_shooter" and p.age > 3 and _try(&"pod_shooter",p.row,p.col): return
	if _battle.sun >= 100 and _limit == 0 and _battle.level.world_id != &"lawn":
		for p: Plant in _battle.board.all_plants():
			if p.data.id == &"pod_shooter" and p.age > 3 and _try(&"pod_shooter",p.row,p.col): return
	if _battle.sun > 175:
		for r: int in rows:
			if _count(r, SHOOTERS)<4:
				for c: int in [2,3,4,5,6,1,7]:
					if _battle.board.get_plant(r,c)==null and not _battle.board.is_water(r,c) and (_try(&"pepper_stinger",r,c) or _try(&"pod_shooter",r,c)): return
	if _strategy == &"strong": _strong_extras()

## Frees the battle (and its timers/tweens) before quitting, so the engine does not
## report leaked instances at exit and the sweep's error check stays meaningful.
func _quit(code: int) -> void:
	var b := _battle
	_battle = null
	get_tree().paused = false
	b.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)

## v0.7 profiles: Pea Bedding under a shooter for lanes with boxed zombies (it shares the
## cell), a Spine Cactus for lanes with balloons. Only bought for lanes that need them.
func _profile_counters() -> bool:
	if _limit > 0 and _battle.objectives.planted >= _limit: return false
	for r: int in 5:
		var boxed := false
		var flying := false
		for z: Zombie in _battle.zombies_in_row(r):
			if not z.is_alive(): continue
			boxed = boxed or z.profile == &"low"
			flying = flying or z.is_flying()
		if boxed and _count(r, [&"pea_bedding", &"clod_catapult", &"thorn_carpet"]) < clampi(_count(r, SHOOTERS), 1, 3):
			for p: Plant in _battle.board.all_plants():
				if p.row == r and p.data.id in SHOOTERS and _battle.board.get_layer(r, p.col, &"under") == null and _try(&"pea_bedding", r, p.col): return true
			for c: int in [1, 2, 3, 0]:
				if _battle.board.get_plant(r, c) == null and _try(&"pea_bedding", r, c): return true
		if flying and _count(r, [&"spine_cactus", &"garlic_drone"]) == 0:
			for c: int in [2, 3, 1, 4]:
				if _battle.board.get_plant(r, c) == null and _safe_cell(r, c) and _try(&"spine_cactus", r, c): return true
	return false

## A human does not drop a fresh plant right into a zombie's mouth.
func _safe_cell(r: int, c: int) -> bool:
	var x := Board.cell_center(r, c).x
	for z: Zombie in _battle.zombies_in_row(r):
		if z.is_alive() and not z.is_flying() and absf(z.position.x - x) < Board.CELL.x * 0.9: return false
	return true

## Cheap 25-sun mine two tiles ahead of a lane's lead zombie (before the expensive Ember Berry).
func _strong_emergency() -> bool:
	if _limit > 0 and _battle.objectives.planted >= _limit: return false
	for r: int in 5:
		if _lane_threat(r) < 1.5: continue
		var lead: Zombie
		for z: Zombie in _battle.zombies_in_row(r):
			if z.is_targetable() and z.position.x < 1250 and (lead == null or z.position.x < lead.position.x): lead = z
		if lead == null: continue
		var c := clampi(Board.x_to_col(lead.position.x) - 2, 1, 8)
		if _battle.board.get_plant(r, c) == null and not _battle.board.is_water(r, c) and _try(&"thorn_mine", r, c): return true
	return false

## Evolutions and legendaries once lanes are covered (skipped under planting caps).
func _strong_extras() -> void:
	if _limit > 0: return
	if _battle.sun >= 225:
		for p: Plant in _battle.board.all_plants():
			if p.data.id == &"bark_wall" and p.age > 3 and _try(&"bark_wall", p.row, p.col): return
	if _battle.sun >= 200 and _t < 200:
		for p: Plant in _battle.board.all_plants():
			if p.data.id == &"sunbud" and p.age > 3 and _try(&"sunbud", p.row, p.col): return
	if _battle.sun >= 375:
		var rows: Array[int] = [0, 1, 2, 3, 4]
		rows.sort_custom(func(a: int, b: int) -> bool: return _lane_threat(a) > _lane_threat(b))
		for id: StringName in [&"storm_thistle", &"phoenix_lily"]:
			for c: int in [3, 2, 4]:
				if _battle.board.get_plant(rows[0], c) == null and not _battle.board.is_water(rows[0], c) and _try(id, rows[0], c): return
