class_name Battle
extends Node2D
## Battle controller: owns the board, lanes, sun economy, seeds, waves and FX.

enum Phase { SEED_SELECT, PLAYING, WON, LOST }

var objectives: ObjectiveTracker
var field_rules: FieldRules
var mission_actions: MissionActions
var mission_panel: MissionPanel
var level: LevelData
var diff: DifficultyData
var phase: Phase = Phase.SEED_SELECT
var sun: int = 50
var seeds: Array[SeedState] = []
const RAFT_ID := &"lily_raft"
var selected: int = -1
var shovel: bool = false
## Glove: pick a plant up and move it (or fuse it into another plant).
var glove: bool = false
var glove_plant: Plant
var glove_cd: float = 0.0
## Cooldown the current glove_cd started from (puzzle missions halve it).
var glove_cd_max: float = 6.0
const GLOVE_COOLDOWN := 6.0
var lost_mower: bool = false
var base_integrity: int = 3
var max_base_integrity: int = 3

var world: Node2D
var frame: BattleFrame
var board: Board
var art: WorldArtConfig
var entities: Node2D
var fx_layer: Node2D
var sun_layer: Node2D
var ghost: Node2D
var director: WaveDirector
var hud: BattleHUD

var lanes: Array = []            # Array per row of Array[Zombie]
var mowers: Array[Mower] = []
var _proj_pool: Array[Projectile] = []
var _ghost_plant: Plant
var _ghost_id: StringName = &""
var _preview_zombies: Array[Zombie] = []
var _sky_t: float = 7.0
var _buff_t: float = 0.0
var _shake: float = 0.0
var _dragging: bool = false
var _hover_cell: Vector2i = Vector2i(-1, -1)
## Long-press plant info (Settings > Controls): press position and held time.
const LONG_PRESS_TIME := 0.45
var _press_pos: Vector2 = Vector2.ZERO
var _press_t: float = -1.0

func _ready() -> void:
	level = GameState.level()
	if level == null:
		level = DB.level(&"lawn_01")
	diff = GameState.difficulty()
	objectives = ObjectiveTracker.new()
	objectives.setup(self)
	_build_world()
	sun = level.start_sun + SaveManager.bonus_start_sun()
	director = WaveDirector.new()
	director.setup(self, level, diff)
	director.wave_started.connect(_on_wave_started)
	director.wave_warning.connect(_on_wave_warning)
	director.all_spawned.connect(_check_win)
	add_child(director)
	hud = BattleHUD.new()
	hud.battle = self
	add_child(hud)
	frame.bind_hud(hud)
	field_rules = FieldRules.new()
	field_rules.setup(self)
	world.add_child(field_rules)
	mission_actions = MissionActions.new()
	mission_actions.setup(self)
	add_child(mission_actions)
	mission_panel = MissionPanel.new()
	mission_panel.battle = self
	hud.root.add_child(mission_panel)
	hud.root.move_child(mission_panel, hud._overlay_layer.get_index())
	if level.mode in [&"artillery", &"holdout"]:
		begin([] as Array[StringName])
	else:
		_spawn_preview_zombies()
		hud.open_seed_select()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false

func _build_world() -> void:
	world = Node2D.new()
	frame = BattleFrame.new()
	add_child(frame)
	frame.add_child(world)
	board = Board.new()
	board.set_layout(level.water)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	art = BattleArt.build(world, board, entities, level)
	fx_layer = Node2D.new()
	world.add_child(fx_layer)
	sun_layer = Node2D.new()
	world.add_child(sun_layer)
	ghost = Node2D.new()
	ghost.modulate = Color(1, 1, 1, 0.5)
	ghost.visible = false
	world.add_child(ghost)
	lanes.clear()
	for r: int in Board.ROWS:
		lanes.append([])
	var skin := Color(0.85, 0.2, 0.2)
	var item := DB.shop_item(SaveManager.equipped_skin())
	if item:
		skin = item.skin_color
	if level.mowers:
		for r: int in Board.ROWS:
			var m := Mower.new()
			m.setup(self, r, skin)
			entities.add_child(m)
			mowers.append(m)

func _world_key() -> String:
	return String(WorldArtLoader.world_key(level))

func _spawn_preview_zombies() -> void:
	var ids: Array[StringName] = []
	for id: StringName in level.zombie_pool:
		ids.append(id)
	if level.waves >= level.flag_every and not ids.has(&"flagbearer"):
		ids.append(&"flagbearer")
	for i: int in ids.size():
		var d := DB.zombie(ids[i])
		if d == null:
			continue
		var z := d.behavior.new() as Zombie
		z.setup_preview(d)
		z.preview_clip = &"idle"
		z.position = Vector2(1550 + (i % 3) * 110, 310 + (i / 3) * 140)
		z.scale = Vector2(0.7, 0.7)
		entities.add_child(z)
		_preview_zombies.append(z)
		SaveManager.mark_zombie_seen(ids[i])

## Called by the seed selection screen.
func begin(ids: Array[StringName]) -> void:
	seeds.clear()
	ids = ids.duplicate()
	# Pool levels always bring the Lily Raft as a free extra slot.
	if level.mode == &"defense" and board.has_water() and not ids.has(RAFT_ID) and DB.plant(RAFT_ID):
		ids.push_front(RAFT_ID)
	for id: StringName in ids:
		var d := DB.plant(id)
		if d:
			seeds.append(SeedState.new(d))
	GameState.last_seeds = ids.duplicate()
	for z: Zombie in _preview_zombies:
		z.queue_free()
	_preview_zombies.clear()
	phase = Phase.PLAYING
	_spawn_preplants()
	director.start()
	hud.on_battle_started()
	Sfx.play_music(&"battle_night" if _world_key() in ["night", "moon", "frost"] else &"battle")
	# Opening humor is shown in MissionPanel, not as an obstructive giant banner.

## Prepared gardens (holdout levels). Invalid entries are skipped with a warning
## instead of crashing; main-layer plants on water get a Lily Raft underneath.
func _spawn_preplants() -> void:
	for entry: Dictionary in level.preplants:
		var d := DB.plant(StringName(entry.get("id", "")))
		var r := int(entry.get("row", -1))
		var c := int(entry.get("col", -1))
		if d == null or not board.in_bounds(r, c):
			push_warning("Skipping invalid preplant %s" % [entry])
			continue
		if board.get_layer(r, c, d.layer) != null:
			push_warning("Skipping preplant on an occupied layer %s" % [entry])
			continue
		var rafted := false
		if d.layer == &"main" and board.is_water(r, c) and not d.allowed_surfaces.has(&"water"):
			var raft := DB.plant(RAFT_ID)
			if raft == null:
				push_warning("Skipping preplant on water without a raft %s" % [entry])
				continue
			rafted = true
		var p := _make_plant(d, r, c)
		p.age = 10.0
		p.preplanted = true
		_invalidate_hybrid_count()
		if rafted:
			p.on_raft = true
			p.raft_hp = float(DB.plant(RAFT_ID).max_hp)

# --- frame ---------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	objectives.tick(delta)
	if objectives.failure != "":
		_lose()
		return
	_check_win()
	if glove_cd > 0.0:
		glove_cd = maxf(0.0, glove_cd - delta)
	for s: SeedState in seeds:
		if s.cooldown > 0.0:
			s.cooldown = max(0.0, s.cooldown - delta)
	if level.sky_sun:
		_sky_t -= delta
		if _sky_t <= 0.0:
			_sky_t = level.sky_sun_interval * randf_range(0.85, 1.25)
			var x := randf_range(Board.ORIGIN.x + 60, Board.ORIGIN.x + Board.CELL.x * Board.COLS - 60)
			var y := Board.row_feet_y(randi() % Board.ROWS) - 40.0
			var t := SunToken.new()
			t.setup_sky(self, x, y, level.sky_sun_value + SaveManager.sky_sun_bonus())
			sun_layer.add_child(t)
	_buff_t -= delta
	if _buff_t <= 0.0:
		_buff_t = 0.5
		_recompute_buffs()

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = max(0.0, _shake - delta * 40.0)
		world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	elif world.position != Vector2.ZERO:
		world.position = Vector2.ZERO
	if phase == Phase.PLAYING:
		_update_hover(world.get_local_mouse_position())
		_update_long_press(delta)

func _update_long_press(delta: float) -> void:
	if _press_t < 0.0:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or world.get_local_mouse_position().distance_to(_press_pos) > 28.0:
		_press_t = -1.0
		return
	# Real time: a held finger should not wait longer at x2 or during hit-stop.
	_press_t += delta / maxf(0.01, Engine.time_scale)
	if _press_t >= LONG_PRESS_TIME:
		_press_t = -1.0
		var top := top_plant(Board.pos_to_cell(_press_pos))
		if top:
			hud.show_plant_info(top)
			Settings.haptic(15)

func _recompute_buffs() -> void:
	var all := board.all_plants()
	for p: Plant in all:
		p.buff = 1.0
		p.speed_buff = 1.0
	for p: Plant in all:
		if p.data.speed_aura > 1.0 and p.is_fusion_ready():
			var rad := maxi(1, p.data.aura_radius)
			for q: Plant in all:
				var inside := absi(q.row - p.row) <= rad and absi(q.col - p.col) <= rad
				if rad >= 9:
					inside = q.row == p.row or q.col == p.col
				if inside and q != p:
					q.speed_buff = maxf(q.speed_buff, p.data.speed_aura)
		if p.data.buff_mult <= 1.0:
			continue
		for dr: int in [-1, 0, 1]:
			for dc: int in [-1, 0, 1]:
				if dr == 0 and dc == 0:
					continue
				var q := board.get_plant(p.row + dr, p.col + dc)
				if q:
					q.buff = max(q.buff, p.data.buff_mult)

# --- input -------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if phase != Phase.PLAYING:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _dragging:
		_dragging = false
		var cell := Board.pos_to_cell(world.get_local_mouse_position())
		if cell.x >= 0 and (selected >= 0 or shovel or glove):
			_act_on_cell(cell)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.PLAYING:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		var pos := world.get_local_mouse_position()
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			deselect()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if bool(Settings.get_value(&"long_press_info")):
			_press_pos = pos
			_press_t = 0.0
		if _try_collect_sun(pos):
			return
		var cell := Board.pos_to_cell(pos)
		if cell.x >= 0 and level.mode == &"artillery":
			mission_actions.fire(cell)
		elif cell.x >= 0 and level.mode == &"holdout" and not shovel:
			mission_actions.repair(cell)
		elif cell.x >= 0 and (selected >= 0 or shovel or glove):
			_act_on_cell(cell)
		elif cell.x >= 0:
			var top := top_plant(cell)
			if top:
				hud.show_plant_info(top)
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode >= KEY_1 and key.keycode <= KEY_9:
			select_seed(key.keycode - KEY_1, false)
		elif key.keycode == KEY_0:
			select_seed(9, false)
		elif key.keycode == KEY_Q or key.keycode == KEY_S:
			toggle_shovel()
		elif key.keycode == KEY_G or key.keycode == KEY_W:
			toggle_glove()
		elif key.keycode == KEY_ESCAPE:
			deselect()
		elif OS.is_debug_build():
			match key.keycode:
				KEY_F2:
					add_sun(500, false)
				KEY_F3:
					director.skip_to_next_wave()
				KEY_F4:
					hud.toast(tr("MSG_CAMPAIGN_VICTORY_RULE"))

func _try_collect_sun(pos: Vector2) -> bool:
	var kids := sun_layer.get_children()
	for i: int in range(kids.size() - 1, -1, -1):
		var t := kids[i] as SunToken
		if t and t.hit(pos):
			t.collect()
			return true
	return false

func select_seed(i: int, drag: bool) -> void:
	if phase != Phase.PLAYING or i < 0 or i >= seeds.size():
		return
	shovel = false
	_drop_glove()
	if selected == i and not drag:
		deselect()
		return
	selected = i
	_dragging = drag
	hud.refresh_selection()

func toggle_shovel(drag: bool = false) -> void:
	if phase != Phase.PLAYING:
		return
	selected = -1
	_drop_glove()
	shovel = not shovel or drag
	_dragging = drag and shovel
	hud.refresh_selection()

func toggle_glove() -> void:
	if phase != Phase.PLAYING:
		return
	if glove_cd > 0.0 and not glove:
		hud.toast(tr("MSG_GLOVE_COOLDOWN").format({"s": int(ceil(glove_cd))}))
		return
	selected = -1
	shovel = false
	var was := glove
	_drop_glove()
	glove = not was
	hud.refresh_selection()

func _drop_glove() -> void:
	if glove_plant and is_instance_valid(glove_plant):
		glove_plant.lifted = false
		glove_plant.queue_redraw()
	glove_plant = null
	glove = false

func deselect() -> void:
	selected = -1
	shovel = false
	_drop_glove()
	_dragging = false
	hud.refresh_selection()

## Topmost plant of a cell: air > shell > main > under.
func top_plant(cell: Vector2i) -> Plant:
	for l: StringName in [&"air", &"shell", &"main", &"under"]:
		var p := board.get_layer(cell.y, cell.x, l)
		if p and not p.dead:
			return p
	return null

## Surface rule for a plant entering a cell (rafts make water plantable).
func _surface_error(d: PlantData, cell: Vector2i) -> String:
	var surf := board.surface(cell.y, cell.x)
	var main := board.get_plant(cell.y, cell.x)
	if d.layer == &"air":
		return ""
	if board.is_water(cell.y, cell.x) and main and main.data.id == RAFT_ID and d.id != RAFT_ID:
		surf = &"grass"
	if board.is_water(cell.y, cell.x) and d.layer != &"main" and main and main.on_raft:
		surf = &"grass"
	if not d.allowed_surfaces.has(surf):
		return "MSG_NEEDS_RAFT" if board.is_water(cell.y, cell.x) else "MSG_BAD_SURFACE"
	return ""

## Best fusion plan for dropping `d` on the cell: same layer first, then the others.
func _best_plan(cell: Vector2i, d: PlantData, from_glove: bool, exclude: Plant = null) -> FusionSystem.Plan:
	var cands: Array[Plant] = []
	var same := board.get_layer(cell.y, cell.x, d.layer)
	# Seeds go into their own empty layer; cross-layer hybrids need the Glove.
	if not from_glove and (same == null or same.data.id == RAFT_ID):
		return null
	if same and same != exclude:
		cands.append(same)
	for q: Plant in board.cell_plants(cell.y, cell.x):
		if q != exclude and not cands.has(q) and q.data.id != RAFT_ID:
			cands.append(q)
	var first: FusionSystem.Plan = null
	for q: Plant in cands:
		var pl := FusionSystem.plan(self, q, d, from_glove)
		if pl.kind != FusionSystem.Kind.NONE and pl.error_key == "":
			return pl
		if first == null and (q == same or pl.kind != FusionSystem.Kind.NONE):
			first = pl
	return first

func selected_seed() -> SeedState:
	if selected >= 0 and selected < seeds.size():
		return seeds[selected]
	return null

## Evaluates what a click on a cell would do. Keys: ok, kind, cost, result, error, plan.
func evaluate(cell: Vector2i) -> Dictionary:
	var out := {"ok": false, "kind": &"none", "cost": 0, "result": null, "error": "", "plan": null}
	if not board.in_bounds(cell.y, cell.x):
		return out
	if shovel:
		out["ok"] = top_plant(cell) != null
		out["kind"] = &"shovel"
		return out
	if glove:
		return _evaluate_glove(cell, out)
	out["error"] = objectives.planting_error(cell)
	if out["error"] != "": return out
	var s := selected_seed()
	if s == null:
		return out
	var d := s.data
	var slot := board.get_layer(cell.y, cell.x, d.layer)
	var plan := _best_plan(cell, d, false)
	if plan and plan.kind != FusionSystem.Kind.NONE and (plan.error_key == "" or slot != null):
		out["plan"] = plan
		out["kind"] = &"graft"
		out["cost"] = plan.cost
		out["result"] = plan.result
		out["error"] = plan.error_key
	elif slot == null or (slot.data.id == RAFT_ID and d.id != RAFT_ID and d.layer == &"main"):
		out["kind"] = &"raft" if slot != null else &"plant"
		out["cost"] = d.cost
		out["result"] = d
		out["error"] = _surface_error(d, cell)
		if out["error"] == "" and d.max_on_board > 0 and count_on_board(d.id) >= d.max_on_board:
			out["error"] = "MSG_LEGENDARY_LIMIT"
	else:
		out["error"] = plan.error_key if plan else "MSG_CELL_OCCUPIED"
		if out["error"] == "MSG_NO_RECIPE" and slot.data.id != d.id:
			out["error"] = "MSG_CELL_OCCUPIED" if d.layer == &"main" else "MSG_LAYER_OCCUPIED"
	if out["error"] == "" and not s.is_ready():
		out["error"] = "MSG_RECHARGING"
	if out["error"] == "" and sun < int(out["cost"]):
		out["error"] = "MSG_NOT_ENOUGH_SUN"
	out["ok"] = out["error"] == ""
	return out

func _evaluate_glove(cell: Vector2i, out: Dictionary) -> Dictionary:
	out["kind"] = &"glove"
	if glove_plant == null or not is_instance_valid(glove_plant) or glove_plant.dead:
		var top := top_plant(cell)
		out["ok"] = top != null and top.data.id != RAFT_ID
		if top == null:
			out["error"] = "MSG_GLOVE_PICK"
		return out
	var g := glove_plant
	if cell == Vector2i(g.col, g.row):
		out["ok"] = true
		out["kind"] = &"glove_cancel"
		return out
	out["error"] = objectives.planting_error(cell)
	if out["error"] != "": return out
	var plan := _best_plan(cell, g.data, true, g)
	if plan and plan.kind != FusionSystem.Kind.NONE and plan.error_key == "":
		out["kind"] = &"glove_fuse"
		out["plan"] = plan
		out["cost"] = plan.cost
		out["result"] = plan.result
	elif board.get_layer(cell.y, cell.x, g.data.layer) == null:
		out["kind"] = &"glove_move"
		out["result"] = g.data
		out["error"] = _surface_error(g.data, cell)
		if out["error"] == "" and board.is_water(cell.y, cell.x) and g.data.layer == &"main" and g.data.id != RAFT_ID:
			out["error"] = "MSG_NEEDS_RAFT"
	else:
		var occupant := board.get_layer(cell.y, cell.x, g.data.layer)
		if occupant and occupant.data.id == RAFT_ID and g.data.layer == &"main":
			out["kind"] = &"glove_raft"
			out["result"] = g.data
			out["error"] = _surface_error(g.data, cell)
		else:
			out["error"] = plan.error_key if plan and plan.kind != FusionSystem.Kind.NONE else "MSG_CELL_OCCUPIED"
	if out["error"] == "" and sun < int(out["cost"]):
		out["error"] = "MSG_NOT_ENOUGH_SUN"
	out["ok"] = out["error"] == ""
	return out

func _act_on_cell(cell: Vector2i) -> void:
	var ev := evaluate(cell)
	if shovel:
		var p := top_plant(cell)
		if p:
			fx_puff(p.position + Vector2(0, -30 - p.hover_height()), 50.0)
			Sfx.play(&"shovel")
			# Shoveling a damaged plant still counts (no dodging loss limits),
			# but relocating a healthy plant is not a loss.
			p.counts_as_loss = p.hp < p.max_hp_now() - 0.5
			p.die()
		if not Settings.get_value(&"sticky_tools", false):
			deselect()
		return
	if glove:
		_act_glove(cell, ev)
		return
	if not ev["ok"]:
		if ev["error"] != "":
			hud.toast(tr(ev["error"]))
			Sfx.play(&"error")
		return
	var s := selected_seed()
	sun -= int(ev["cost"])
	s.trigger()
	objectives.planted += 1
	match ev["kind"]:
		&"plant":
			_make_plant(s.data, cell.y, cell.x)
			Sfx.play(&"plant")
			SaveManager.add_stat(&"planted")
			EventBus.plant_planted.emit(s.data.id)
		&"raft":
			var raft := board.get_plant(cell.y, cell.x)
			raft.keep_raft = false
			raft.die(true)
			var raft_hp := raft.hp
			var np := _make_plant(s.data, cell.y, cell.x)
			np.on_raft = true
			np.raft_hp = raft_hp
			Sfx.play(&"plant")
			SaveManager.add_stat(&"planted")
			EventBus.plant_planted.emit(s.data.id)
		&"graft":
			_transform(ev["plan"] as FusionSystem.Plan, null)
	hud.update_sun()
	deselect()

func _act_glove(cell: Vector2i, ev: Dictionary) -> void:
	if not ev["ok"]:
		if ev["error"] != "":
			hud.toast(tr(ev["error"]))
			Sfx.play(&"error")
		return
	match ev["kind"]:
		&"glove":
			glove_plant = top_plant(cell)
			glove_plant.lifted = true
			glove_plant.queue_redraw()
			Sfx.play(&"pick")
			hud.refresh_selection()
			return
		&"glove_cancel":
			deselect()
			return
		&"glove_move", &"glove_raft":
			var g := glove_plant
			var from := Vector2i(g.col, g.row)
			var leave_raft := g.on_raft and g.data.layer == &"main"
			board.clear_plant(g)
			if ev["kind"] == &"glove_raft":
				var raft := board.get_plant(cell.y, cell.x)
				raft.keep_raft = false
				raft.silent_removal = true
				raft.die(true)
				g.on_raft = true
				g.raft_hp = raft.hp
			else:
				g.on_raft = false
			board.set_plant(cell.y, cell.x, g)
			g.place_at(cell.y, cell.x)
			if leave_raft and DB.plant(RAFT_ID) and board.get_plant(from.y, from.x) == null:
				_make_plant(DB.plant(RAFT_ID), from.y, from.x)
			fx_dust(g.position)
		&"glove_fuse":
			sun -= int(ev["cost"])
			_transform(ev["plan"] as FusionSystem.Plan, glove_plant)
	Sfx.play(&"plant")
	SaveManager.add_stat(&"glove_moves")
	glove_cd = GLOVE_COOLDOWN * (0.5 if level.mode == &"puzzle" else 1.0)
	glove_cd_max = glove_cd
	hud.update_sun()
	deselect()

func _make_plant(d: PlantData, r: int, c: int) -> Plant:
	_invalidate_hybrid_count()
	var p := d.behavior.new() as Plant
	p.setup(self, d, r, c)
	entities.add_child(p)
	board.set_plant(r, c, p)
	fx_dust(p.position)
	return p

func _transform(plan: FusionSystem.Plan, catalyst: Plant) -> void:
	var base := plan.base
	var twin := plan.recipe != null and plan.recipe.base_id == plan.recipe.catalyst_id
	var ratio := clampf(base.hp / base.max_hp_now(), 0.05, 1.0)
	var r := base.row
	var c := base.col
	var rafted := base.on_raft or (catalyst != null and catalyst.on_raft and board.is_water(r, c))
	var raft_hp := base.raft_hp
	base.keep_raft = false
	base.silent_removal = true
	base.die(true)
	if catalyst:
		catalyst.keep_raft = catalyst.on_raft and not (catalyst.row == r and catalyst.col == c)
		catalyst.silent_removal = true
		catalyst.die(true)
	# Remove a same-id seed occupant in the result layer (e.g. dropped shell).
	var other := board.get_layer(r, c, plan.result.layer)
	if other and other != base:
		other.silent_removal = true
		other.die(true)
	var np := _make_plant(plan.result, r, c)
	np.on_raft = rafted and plan.result.layer == &"main"
	np.raft_hp = raft_hp
	np.hp = maxf(1.0, np.max_hp_now() * ratio)
	np.pop()
	fx_fuse(np.position + Vector2(0, -50 - np.hover_height()))
	Sfx.play(&"fuse")
	objectives.grafts += 1
	SaveManager.add_stat(&"grafts")
	if twin:
		SaveManager.add_stat(&"twin_grafts")
	EventBus.plant_fused.emit(plan.result.id)
	if SaveManager.discover_recipe(plan.recipe.recipe_id()):
		hud.banner(tr("MSG_RECIPE_DISCOVERED").format({"name": tr(plan.result.name_key)}), 3.0)

func count_on_board(id: StringName) -> int:
	var n := 0
	for p: Plant in board.all_plants():
		if p.data.id == id and not p.dead:
			n += 1
	return n

## Cached per frame: every plant asks for a fusion plan while a seed is selected,
## and each plan needs this count (it was O(plants^2) per frame on full boards).
var _hybrid_frame: int = -1
var _hybrid_cache: int = 0

func hybrid_count() -> int:
	var frame := Engine.get_process_frames()
	if frame == _hybrid_frame:
		return _hybrid_cache
	var n := 0
	for p: Plant in board.all_plants():
		if p.counts_as_hybrid() and not p.dead:
			n += 1
	_hybrid_frame = frame
	_hybrid_cache = n
	return n

## Call after the board changes within a frame (graft, plant, removal).
func _invalidate_hybrid_count() -> void:
	_hybrid_frame = -1

## Result shown in a bubble above a plant the selected seed/glove could fuse with.
func fusion_hint_for(p: Plant) -> PlantData:
	if p.dead or phase != Phase.PLAYING:
		return null
	var d: PlantData = null
	var from_glove := false
	if glove and glove_plant and is_instance_valid(glove_plant) and glove_plant != p:
		d = glove_plant.data
		from_glove = true
	elif selected_seed():
		d = selected_seed().data
		var slot := board.get_layer(p.row, p.col, d.layer)
		if slot == null or slot.data.id == RAFT_ID:
			return null
	if d == null:
		return null
	var pl := FusionSystem.plan(self, p, d, from_glove)
	if pl.kind == FusionSystem.Kind.NONE or pl.error_key != "":
		return null
	return pl.result

func show_fusion_hint_for(p: Plant) -> bool:
	return fusion_hint_for(p) != null

func _update_hover(pos: Vector2) -> void:
	var cell := Board.pos_to_cell(pos)
	if selected < 0 and not shovel and not glove:
		cell = Vector2i(-1, -1)
	if cell.x < 0:
		board.set_hover(cell, true)
		ghost.visible = false
		hud.set_hover_info("", true, Vector2.ZERO)
		_hover_cell = cell
		return
	var ev := evaluate(cell)
	board.set_hover(cell, ev["ok"] or (ev["error"] == "MSG_RECHARGING" or ev["error"] == "MSG_NOT_ENOUGH_SUN"))
	var info := ""
	match ev["kind"]:
		&"graft":
			info = tr("HUD_GRAFT_INTO").format({"name": tr((ev["result"] as PlantData).name_key), "cost": ev["cost"]})
		&"glove_fuse":
			info = tr("HUD_GRAFT_INTO").format({"name": tr((ev["result"] as PlantData).name_key), "cost": ev["cost"]})
		&"glove":
			info = tr("HUD_GLOVE_PICK")
		&"glove_move", &"glove_raft":
			info = tr("HUD_GLOVE_MOVE")
	if ev["error"] != "":
		info = tr(ev["error"]) if info == "" else info + "\n" + tr(ev["error"])
	hud.set_hover_info(info, ev["ok"], pos)
	var res := ev["result"] as PlantData
	if res and ev["kind"] != &"shovel":
		if _ghost_id != res.id:
			if _ghost_plant:
				_ghost_plant.queue_free()
			_ghost_plant = res.behavior.new() as Plant
			_ghost_plant.setup_preview(res)
			ghost.add_child(_ghost_plant)
			_ghost_id = res.id
		ghost.position = Board.cell_feet(cell.y, cell.x) + Vector2(0, -_ghost_plant.hover_height())
		ghost.visible = true
	else:
		ghost.visible = false
	_hover_cell = cell

# --- plants & zombies ----------------------------------------------------------
func on_plant_removed(p: Plant) -> void:
	board.clear_plant(p)
	_invalidate_hybrid_count()
	if phase == Phase.PLAYING and p.counts_as_loss and not p.silent_removal:
		objectives.losses += 1
	# A plant standing on a Lily Raft leaves the raft behind.
	if p.on_raft and p.keep_raft and phase == Phase.PLAYING:
		var d := DB.plant(RAFT_ID)
		if d and board.get_plant(p.row, p.col) == null and p.data.layer == &"main":
			var raft := _make_plant(d, p.row, p.col)
			raft.hp = maxf(1.0, p.raft_hp)

func spawn_zombie(id: StringName, row: int) -> Zombie:
	var d := DB.zombie(id)
	if d == null or phase != Phase.PLAYING:
		return null
	var z := d.behavior.new() as Zombie
	z.setup(self, d, row, Board.SPAWN_X + randf_range(0.0, 60.0))
	entities.add_child(z)
	(lanes[row] as Array).append(z)
	SaveManager.mark_zombie_seen(id)
	return z

func on_zombie_died(z: Zombie, killed: bool) -> void:
	(lanes[z.row] as Array).erase(z)
	if killed:
		objectives.kills += 1
		SaveManager.add_stat(StringName("kill_" + String(z.data.id)))
		SaveManager.add_stat(&"kills")
		EventBus.zombie_killed.emit(z.data.id)
	_check_win()

func change_zombie_row(z: Zombie, r: int) -> void:
	(lanes[z.row] as Array).erase(z)
	(lanes[r] as Array).append(z)

func zombies_in_row(r: int) -> Array:
	if r < 0 or r >= lanes.size():
		return []
	return lanes[r]

func alive_zombie_count() -> int:
	var n := 0
	for lane: Array in lanes:
		n += lane.size()
	return n

func _on_lawn(z: Zombie) -> bool:
	return z.position.x < Board.SPAWN_X - 45.0

func first_target_in_lane(row: int, min_x: float, max_x: float, kind: StringName = &"straight") -> Zombie:
	var best: Zombie
	for z: Zombie in zombies_in_row(row):
		if not z.hittable_by(kind) or not _on_lawn(z):
			continue
		var x := z.position.x
		if x > min_x and x <= max_x and (best == null or x < best.position.x):
			best = z
	return best

func zombie_touching(row: int, x: float, radius: float, include_underground: bool) -> Zombie:
	for z: Zombie in zombies_in_row(row):
		if not z.is_alive() or (z.underground and not include_underground) or z.is_flying():
			continue
		if absf(z.position.x - x) < radius:
			return z
	return null

func damage_area(row: int, x: float, radius_cells: float, amount: float, kind: StringName) -> void:
	var span := int(floor(radius_cells))
	for rr: int in range(row - span, row + span + 1):
		for z: Zombie in zombies_in_row(rr).duplicate():
			if not z.is_alive() or not _on_lawn(z):
				continue
			if absf(z.position.x - x) <= radius_cells * Board.CELL.x:
				z.take_damage(amount, kind)

func zombies_in_circle(center: Vector2, radius: float) -> Array[Zombie]:
	var out: Array[Zombie] = []
	for lane: Array in lanes:
		for z: Zombie in lane:
			if z.is_targetable() and _on_lawn(z) and (z.position + Vector2(0, -60)).distance_to(center) <= radius:
				out.append(z)
	return out

func nearest_target(pos: Vector2) -> Zombie:
	var best: Zombie
	var bd := INF
	for lane: Array in lanes:
		for z: Zombie in lane:
			if not z.is_targetable() or not _on_lawn(z):
				continue
			var d := z.position.distance_squared_to(pos)
			if d < bd:
				bd = d
				best = z
	return best

func pull_adjacent(row: int, x: float, range_cells: float) -> void:
	for rr: int in [row - 1, row + 1]:
		for z: Zombie in zombies_in_row(rr).duplicate():
			if z.is_targetable() and absf(z.position.x - x) <= range_cells * Board.CELL.x:
				z.move_to_row(row)

## True when a zombie at x in this row has reached a mower that is still waiting.
## The mower sits left of the board (Board.ORIGIN.x - 55) but well right of HOUSE_X, so
## it must be triggered here: triggering it only at HOUSE_X (v0.7) let the zombie walk
## past the mower's blade, survive and breach the gate as well.
func mower_reached(row: int, x: float) -> bool:
	if row < 0 or row >= mowers.size():
		return false
	var m := mowers[row]
	return m != null and m.state == Mower.MowerState.IDLE and x < m.position.x + Mower.TRIGGER_REACH

func on_zombie_at_house(z: Zombie) -> void:
	if phase != Phase.PLAYING:
		return
	var m: Mower = mowers[z.row] if z.row < mowers.size() else null
	if m and m.state == Mower.MowerState.IDLE:
		m.trigger()
		lost_mower = true
		hud.update_mower_button()
	elif m and m.state == Mower.MowerState.RUNNING:
		return
	elif z.position.x < Board.HOUSE_X:
		var breach_damage := 2 if z.data.threat_cost >= 5.0 else 1
		objectives.breaches += 1
		base_integrity = maxi(0, base_integrity - breach_damage)
		lost_mower = true
		hud.update_base_integrity()
		hud.banner(tr("HUD_BREACH").format({"n": base_integrity}), 1.4)
		shake(10.0)
		if base_integrity <= 0:
			_lose()
		z.despawn()

func restore_mower() -> bool:
	if SaveManager.purchased(&"mower_kit") <= 0:
		return false
	for m: Mower in mowers:
		if m.state == Mower.MowerState.USED:
			m.restore()
			SaveManager.add_purchase(&"mower_kit", -1)
			SaveManager.save_game()
			return true
	return false

func has_used_mower() -> bool:
	for m: Mower in mowers:
		if m.state == Mower.MowerState.USED:
			return true
	return false

# --- projectiles -------------------------------------------------------------
func spawn_projectile(row: int, pos: Vector2, amount: float, src: PlantData) -> void:
	var p: Projectile
	if _proj_pool.is_empty():
		p = Projectile.new()
		fx_layer.add_child(p)
	else:
		p = _proj_pool.pop_back()
	p.fire(self, row, pos, amount, src)

func recycle_projectile(p: Projectile) -> void:
	if not p in _proj_pool:
		_proj_pool.append(p)

func spawn_bee(pos: Vector2, amount: float) -> Bee:
	var b := Bee.new()
	b.setup(self, pos, amount)
	fx_layer.add_child(b)
	return b

func spawn_fire_puddle(row: int, col: int, dps: float, t: float) -> void:
	var f := FirePuddle.new()
	f.setup(self, row, col, dps, t)
	world.add_child(f)
	world.move_child(f, entities.get_index())

# --- sun ---------------------------------------------------------------------
func spawn_sun(pos: Vector2, amount: int, _from_sky: bool) -> void:
	var t := SunToken.new()
	sun_layer.add_child(t)
	t.setup_pop(self, pos, amount)

func add_sun(amount: int, collected: bool) -> void:
	sun += amount
	hud.update_sun()
	if collected:
		objectives.collected += amount
		SaveManager.add_stat(&"sun", amount)
		EventBus.sun_collected.emit(amount)

func sun_counter_world_pos() -> Vector2:
	return hud.sun_icon_screen_pos() - world.position

# --- waves / end -------------------------------------------------------------
func _on_wave_started(index: int, total: int, is_flag: bool) -> void:
	if index == total:
		hud.banner(tr("HUD_FINAL_WAVE"), 2.5)
		Sfx.play(&"huge_wave")
	elif is_flag:
		hud.banner(tr("HUD_HUGE_WAVE"), 2.5)
		Sfx.play(&"huge_wave")
	elif index == 1:
		Sfx.play(&"groan")

func _on_wave_warning(_index: int, _total: int, is_flag: bool, seconds: float) -> void:
	if is_flag:
		hud.banner(tr("HUD_WAVE_WARNING").format({"n": ceili(seconds)}), 1.8)

func _check_win() -> void:
	if phase == Phase.PLAYING and director.finished and alive_zombie_count() == 0 and objectives.fulfilled():
		_win()

func _win() -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.WON
	Engine.time_scale = 1.0
	deselect()
	ghost.visible = false
	for t: Node in sun_layer.get_children():
		var st := t as SunToken
		if st and not st.collected:
			st.collect()
	var result := GameState.finish_level(true, lost_mower, director.wave)
	get_tree().create_timer(1.2).timeout.connect(func() -> void: hud.show_result(result))

func _lose() -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.LOST
	Engine.time_scale = 1.0
	deselect()
	ghost.visible = false
	var result := GameState.finish_level(false, true, maxi(0, director.wave - 1))
	result["failure"] = objectives.failure
	shake(14.0)
	get_tree().create_timer(0.6).timeout.connect(_show_loss.bind(result))

func _show_loss(result: Dictionary) -> void:
	get_tree().paused = true
	hud.show_result(result)

# --- feedback / FX -----------------------------------------------------------
func shake(amount: float) -> void:
	if not bool(Settings.get_value(&"screen_shake")) or bool(Settings.get_value(&"reduce_motion")):
		return
	_shake = max(_shake, amount)

var _hit_stop_token: int = 0
func hit_stop(t: float) -> void:
	if phase != Phase.PLAYING or get_tree().paused or bool(Settings.get_value(&"reduce_motion")):
		return
	_hit_stop_token += 1
	var token := _hit_stop_token
	Engine.time_scale = 0.08
	get_tree().create_timer(t, true, false, true).timeout.connect(_end_hit_stop.bind(token))

## Restore the player's chosen battle speed (×2 used to be silently reset to ×1).
func _end_hit_stop(token: int) -> void:
	if token != _hit_stop_token or not is_inside_tree() or get_tree().paused:
		return
	# After the battle ends the result screen runs at normal speed.
	Engine.time_scale = hud._battle_speed if is_instance_valid(hud) and phase == Phase.PLAYING else 1.0

func _burst(pos: Vector2, color: Color, amount: int, speed: float, lifetime: float, size: float, gravity: Vector2 = Vector2(0, 500)) -> void:
	amount = int(amount * Settings.particle_mult())
	if amount <= 0:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	p.position = pos
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)

func fx_hit(pos: Vector2, color: Color) -> void:
	_burst(pos, color, 6, 160.0, 0.3, 7.0)

func fx_dust(pos: Vector2) -> void:
	_burst(pos + Vector2(0, -4), Color(0.55, 0.42, 0.28), 10, 140.0, 0.4, 8.0, Vector2(0, 300))

func fx_puff(pos: Vector2, radius: float) -> void:
	_burst(pos, Color(0.97, 0.97, 0.92, 0.9), 18, radius * 2.2, 0.55, 10.0, Vector2(0, -40))

func fx_explosion(pos: Vector2, radius: float, color: Color) -> void:
	Sfx.play(&"explode", -3.0)
	Settings.haptic(30)
	var ring := FxRing.new()
	ring.radius = max(radius, 60.0)
	ring.color = color
	ring.position = pos
	fx_layer.add_child(ring)
	_burst(pos, color, 36, radius * 2.5, 0.7, 14.0, Vector2(0, 250))
	_burst(pos, Color(0.3, 0.27, 0.25, 0.8), 14, radius * 1.4, 0.9, 16.0, Vector2(0, -60))

func fx_fuse(pos: Vector2) -> void:
	var ring := FxRing.new()
	ring.radius = 90.0
	ring.color = Color(0.7, 1.0, 0.45)
	ring.position = pos
	fx_layer.add_child(ring)
	_burst(pos, Color(1.0, 0.95, 0.5), 28, 260.0, 0.7, 8.0, Vector2(0, -80))

func fx_gust(row: int, from_x: float, to_x: float) -> void:
	var y := Board.row_feet_y(row) - 70.0
	for i: int in 4:
		var l := Line2D.new()
		l.width = 4.0
		l.default_color = Color(1, 1, 1, 0.7)
		l.points = PackedVector2Array([Vector2(0, 0), Vector2(70, 0)])
		l.position = Vector2(from_x + 30.0, y + (i - 1.5) * 22.0)
		fx_layer.add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "position:x", to_x, 0.45 + i * 0.05)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5 + i * 0.05)
		tw.tween_callback(l.queue_free)

func _flying_piece(pos: Vector2, pts: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = color
	poly.position = pos
	fx_layer.add_child(poly)
	var tw := poly.create_tween()
	tw.tween_property(poly, "position", pos + Vector2(randf_range(20, 60), 70), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(poly, "rotation", randf_range(2.0, 4.0), 0.55)
	tw.tween_interval(0.5)
	tw.tween_property(poly, "modulate:a", 0.0, 0.4)
	tw.tween_callback(poly.queue_free)

## Textured particle burst (Inkscape-rendered sprites).
func _tex_burst(pos: Vector2, tex: Texture2D, amount: int, speed: float, lifetime: float, size: float, gravity: Vector2, color: Color = Color.WHITE, hframes: int = 1) -> void:
	amount = int(amount * Settings.particle_mult())
	if amount <= 0:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = lifetime
	p.texture = tex
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.gravity = gravity
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = color
	if hframes > 1:
		var m := CanvasItemMaterial.new()
		m.particles_animation = true
		m.particles_anim_h_frames = hframes
		m.particles_anim_v_frames = 1
		p.material = m
		p.anim_offset_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.position = pos
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)

func _sheet_fx(id: StringName, pos: Vector2, s: float, fps: float = 16.0) -> void:
	var f := FxSheet.make(id, fps)
	f.position = pos
	f.scale = Vector2(s, s)
	fx_layer.add_child(f)

func fx_leaves(pos: Vector2, _color: Color) -> void:
	_tex_burst(pos, FxSheet.sheet(&"leaf"), 9, 220.0, 0.9, 1.1, Vector2(0, 380), Color.WHITE, 4)

func fx_crumbs(pos: Vector2, color: Color) -> void:
	_burst(pos, color, 4, 120.0, 0.3, 5.0, Vector2(0, 420))

func fx_sparkles(pos: Vector2, n: int = 3) -> void:
	for i: int in n:
		_sheet_fx(&"sparkle", pos + Vector2(randf_range(-40, 40), randf_range(-30, 30)), randf_range(0.8, 1.3), 18.0)

func fx_freeze(pos: Vector2) -> void:
	Sfx.play(&"freeze", -6.0)
	_sheet_fx(&"frost_burst", pos, 1.6, 18.0)
	_tex_burst(pos, FxSheet.tex("res://assets/fx/snowflake.png"), 14, 260.0, 0.9, 1.1, Vector2(0, 120))

func fx_shatter(pos: Vector2) -> void:
	_tex_burst(pos, FxSheet.tex("res://assets/fx/snowflake.png"), 10, 300.0, 0.6, 0.9, Vector2(0, 600))
	_burst(pos, Color(0.78, 0.94, 1.0, 0.9), 16, 300.0, 0.5, 9.0, Vector2(0, 700))

func fx_ash(pos: Vector2) -> void:
	_burst(pos, Color(0.22, 0.2, 0.19, 0.9), 22, 160.0, 0.9, 10.0, Vector2(0, -90))

func fx_rebirth(pos: Vector2) -> void:
	var ring := FxRing.new()
	ring.radius = 110.0
	ring.color = Color(1.0, 0.55, 0.15)
	ring.position = pos
	fx_layer.add_child(ring)
	for i: int in 3:
		_sheet_fx(&"flame", pos + Vector2(-40 + i * 40, 10), 1.4, 14.0)
	fx_sparkles(pos, 4)
	shake(6.0)

## Lightning bolt between two points (Storm Thistle), sprite strip stretched to fit.
func fx_bolt(from: Vector2, to: Vector2) -> void:
	var f := FxSheet.make(&"lightning", 22.0)
	var d := to - from
	f.centered = false
	f.offset = Vector2(-32, 0)
	f.position = from
	f.rotation = d.angle() - PI / 2.0
	f.scale = Vector2(0.9, d.length() / 256.0)
	f.modulate = Color(1, 1, 1, 0.95)
	fx_layer.add_child(f)
	_burst(to, Color(0.75, 0.9, 1.0), 6, 200.0, 0.25, 6.0, Vector2.ZERO)

func fx_limb(pos: Vector2, color: Color) -> void:
	_flying_piece(pos, PackedVector2Array([Vector2(-18, -5), Vector2(18, -5), Vector2(18, 5), Vector2(-18, 5)]), color)

func fx_armor_break(pos: Vector2, color: Color) -> void:
	_flying_piece(pos, PackedVector2Array([Vector2(-20, 10), Vector2(0, -30), Vector2(20, 10)]), color)
