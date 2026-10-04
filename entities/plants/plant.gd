class_name Plant
extends Node2D
## Base plant. Behaviour subclasses override tick() and draw_body().
##
## Animation: every plant owns an AnimationPlayer playing clips from the shared
## res://anim/plant_anims.tres library (built by tools/build_anims.gd). Clips key
## the pose_* properties below; _draw() turns them into a body transform, so all
## procedural drawings squash, lean, bob and wilt the same way. A damped spring
## adds hit wobble on top of whatever clip is playing.

const FLASH_SHADER: Shader = preload("res://shaders/entity_fx.gdshader")
const ANIMS: AnimationLibrary = preload("res://anim/plant_anims.tres")
const AURA_TEX := "res://assets/fx/legend_aura.png"

var battle: Battle
var data: PlantData
var row: int = 0
var col: int = 0
var hp: float = 1.0
var age: float = 0.0
## Damage/speed multiplier from support plants (Lantern Bloom etc.).
var buff: float = 1.0
## Attack / production speed multiplier from speed auras (Turbo Bean, Bean Patriarch).
var speed_buff: float = 1.0
## Placed by the level layout (not grafted by the player): does not use the hybrid cap.
var preplanted: bool = false
## Lifted by the glove (drawn raised, ignores the board until dropped).
var lifted: bool = false
var dead: bool = false
var counts_as_loss: bool = false
var silent_removal: bool = false
var preview: bool = false
## Generic action animation (1 -> 0), e.g. recoil after shooting.
var anim_t: float = 0.0
var rebirths_left: int = 0
var since_bitten: float = 99.0
var _phase: float = randf() * TAU
var _flash: float = 0.0
var _mat: ShaderMaterial
var _pop: float = 0.0

# --- pose (keyed by AnimationPlayer clips) ---------------------------------------
var anim: AnimationPlayer
var pose_squash: float = 0.0
var pose_lean: float = 0.0
var pose_bob: float = 0.0
var pose_kick: float = 0.0
var pose_glow: float = 0.0
var pose_grow: float = 1.0
var pose_alpha: float = 1.0
var _wob: float = 0.0
var _wob_v: float = 0.0
## Painted cut-out rig (assets/sprites/plants/<id>), null = procedural fallback.
var rig: Rig
## Standing on a Lily Raft (pool cells). The raft comes back when this plant dies.
var on_raft: bool = false
var keep_raft: bool = true
var raft_hp: float = 300.0
var _blink_t: float = randf_range(1.5, 5.0)
var _blink: float = 0.0
## Gameplay callback waiting for the clip's _on_action_frame() event.
var _pending: Callable = Callable()
var _pending_t: float = 0.0

func setup(b: Battle, d: PlantData, r: int, c: int) -> void:
	battle = b
	data = d
	row = r
	col = c
	hp = d.max_hp
	rebirths_left = d.rebirths
	place_at(r, c)

## Moves the plant node to a cell (glove), keeping the layer's sort offset.
func place_at(r: int, c: int) -> void:
	row = r
	col = c
	position = Board.cell_feet(r, c) + Vector2(0, layer_sort_offset())

## Small y offset so layers in one cell y-sort correctly: under < main < shell < air.
func layer_sort_offset() -> float:
	match data.layer:
		&"under":
			return -2.0
		&"shell":
			return 1.5
		&"air":
			return 5.0
	return 0.0

func is_air() -> bool:
	return data != null and data.layer == &"air"

## Visual hover height of flying plants.
func hover_height() -> float:
	if not is_air():
		return 0.0
	return (34.0 if preview else 96.0) + sin(age * 2.0 + _phase) * 6.0

func max_hp_now() -> float:
	return float(data.max_hp)

## Plants never upgrade in place; kept as a hook for subclasses' damage maths.
func stat_mult() -> float:
	return 1.0

## True for player-made hybrids that occupy a slot of the level's hybrid cap.
func counts_as_hybrid() -> bool:
	return data != null and data.is_hybrid and not preplanted

func setup_preview(d: PlantData) -> void:
	data = d
	preview = true
	hp = d.max_hp

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	_mat.set_shader_parameter("seed", randf() * 10.0)
	if is_legendary():
		_mat.set_shader_parameter("shimmer", 1.0)
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rig = Rig.plant(data.id)
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	anim.add_animation_library(&"", ANIMS)
	anim.playback_default_blend_time = 0.1
	add_child(anim)
	if preview:
		anim.play(idle_clip())
		anim.seek(randf() * anim.current_animation_length, true)
	else:
		anim.play(&"spawn")
		anim.queue(idle_clip())
	on_ready()

func on_ready() -> void:
	pass

func is_legendary() -> bool:
	return data != null and data.rarity == &"legendary"

## Idle loop for this body type (override per plant family).
func idle_clip() -> StringName:
	return &"idle_legend" if is_legendary() else &"idle_stem"

## Plays a one-shot clip, then returns to idle. Gameplay can hook the clip's
## _on_action_frame() event.
func trigger_action(clip: StringName = &"action", on_frame: Callable = Callable()) -> void:
	anim_t = 1.0
	if _pending.is_valid():
		_pending.call()
	_pending = on_frame
	_pending_t = 0.0
	if anim == null or dead:
		_flush_pending()
		return
	# Clips only key what they animate: restore poses an interrupted clip
	# (spawn/produce) may have left mid-way.
	pose_grow = 1.0
	pose_alpha = 1.0
	pose_bob = 0.0
	pose_glow = 0.0
	anim.clear_queue()
	anim.play(clip, 0.0)
	anim.seek(0.0, true)
	anim.queue(idle_clip())

## Animation event (method track). Override to sync gameplay with the key frame.
func _on_action_frame() -> void:
	_flush_pending()

func _flush_pending() -> void:
	if _pending.is_valid():
		var cb := _pending
		_pending = Callable()
		cb.call()

func _on_die_finished() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	if preview or dead:
		return
	age += delta
	since_bitten += delta
	if _pending.is_valid():
		_pending_t += delta
		if _pending_t > 0.5:
			_flush_pending()
	if data.regen_per_sec > 0.0 and since_bitten > 4.0 and hp < max_hp_now():
		hp = min(max_hp_now(), hp + data.regen_per_sec * delta)
	if lifted:
		return
	tick(delta)

func _process(delta: float) -> void:
	_phase += delta * 2.2
	anim_t = max(0.0, anim_t - delta * 3.0)
	_pop = max(0.0, _pop - delta * 4.0)
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 6.0)
		_mat.set_shader_parameter("flash", _flash)
	# hit wobble: damped spring
	# substepped so long frames (slow machines, captures) can't destabilise it
	var rem := minf(delta, 0.25)
	while rem > 0.0:
		var h := minf(rem, 1.0 / 120.0)
		_wob_v += (-180.0 * _wob - 9.0 * _wob_v) * h
		_wob += _wob_v * h
		rem -= h
	_wob = clampf(_wob, -0.6, 0.6)
	_wob_v = clampf(_wob_v, -6.0, 6.0)
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.13
		_blink_t = randf_range(2.5, 6.5)
	_blink = maxf(0.0, _blink - delta)
	# Cross-fades between clips can leave a value keyed only by the previous
	# clip half-way (e.g. spawn's pose_grow). Only spawn/die may change these.
	if anim and anim.current_animation != &"spawn" and anim.current_animation != &"die":
		pose_grow = 1.0
		pose_alpha = 1.0
	modulate.a = pose_alpha
	queue_redraw()

func sway_amount() -> float:
	return 1.0

func tick(_delta: float) -> void:
	pass

func is_fusion_ready() -> bool:
	return age >= data.fusion_ready_time

func blocks_zombies() -> bool:
	return not dead and not lifted and data.layer != &"air"

func damage_stage() -> int:
	var r := hp / max_hp_now()
	if r > 0.66:
		return 0
	if r > 0.33:
		return 1
	return 2

func dmg(base: float) -> float:
	return base * buff * stat_mult()

## Combined attack/production tempo (support buff + speed aura).
func tempo() -> float:
	return (1.0 + (buff - 1.0) * 0.5) * speed_buff

func take_damage(amount: float, source: Zombie = null) -> void:
	if dead:
		return
	counts_as_loss = true
	hp -= amount
	since_bitten = 0.0
	_flash = 0.55
	_wob_v += 2.4 if _wob_v >= 0.0 else -2.4
	if source and data.thorns_damage > 0 and is_instance_valid(source):
		source.take_damage(dmg(data.thorns_damage), &"thorns")
	on_bitten(source)
	if hp <= 0.0:
		if rebirths_left > 0:
			_rebirth()
		else:
			die()

func _rebirth() -> void:
	rebirths_left -= 1
	hp = max_hp_now() * 0.6
	if battle:
		battle.fx_rebirth(position + Vector2(0, -60))
	anim.clear_queue()
	anim.play(&"spawn")
	anim.queue(idle_clip())

func on_bitten(_source: Zombie) -> void:
	pass

func die(silent: bool = false) -> void:
	if dead:
		return
	dead = true
	silent_removal = silent
	if battle:
		battle.on_plant_removed(self)
	if silent:
		queue_free()
		return
	if battle:
		battle.fx_leaves(position + Vector2(0, -50), data.color_main)
	anim.clear_queue()
	anim.play(&"die", 0.05)
	# Safety net in case the clip is interrupted.
	get_tree().create_timer(1.0, false).timeout.connect(queue_free)

func pop() -> void:
	_pop = 1.0

## Body transform from the animated pose. Origin = the plant's feet.
func pose_transform() -> Transform2D:
	var s := sin(_phase) * 0.012 * sway_amount()
	var pop_v := sin(_pop * PI) * 0.22
	var sq := pose_squash + pop_v * 0.6 + _wob * 0.25
	var g := pose_grow
	var sc := Vector2((1.0 + s - sq * 0.5 + pop_v) * g, (1.0 - s + sq + pop_v * 0.3) * g)
	return Transform2D(0.0, sc, -(pose_lean + _wob * 0.35), Vector2(0, -pose_bob))

func _draw() -> void:
	if data == null:
		return
	var float_y := -hover_height()
	if lifted:
		float_y -= 40.0
	if is_air():
		var sw := 34.0 * clampf(pose_grow, 0.2, 1.2) * (0.85 + 0.15 * sin(age * 2.0 + _phase))
		draw_colored_polygon(DrawUtil.ellipse_points(Vector2(0, 4), sw, 9), Color(0, 0, 0, 0.16))
	if on_raft or (battle and data.allowed_surfaces.has(&"water") and not data.allowed_surfaces.has(&"grass")):
		float_y += sin(age * 1.6 + _phase) * 2.0
	if on_raft:
		var rr := Rig.plant(&"lily_raft")
		if rr:
			rr.draw(self, &"body", Transform2D(sin(age * 1.2 + _phase) * 0.02, Vector2(1.3, 1.25), 0.0, Vector2(0, float_y + 12.0)), Color.WHITE)
			draw_set_transform_matrix(Transform2D.IDENTITY)
	elif not is_air() and data.layer != &"under":
		# soft ground shadow (not affected by the pose, only by growth)
		var shadow_w := 40.0 * clampf(pose_grow, 0.2, 1.2) * (1.0 - pose_bob * 0.01)
		draw_colored_polygon(DrawUtil.ellipse_points(Vector2(0, 4), shadow_w, 11), Color(0, 0, 0, 0.2))
	if is_legendary():
		_draw_aura()
	draw_set_transform_matrix(Transform2D(0.0, Vector2(0, float_y - (4.0 if on_raft else 0.0))) * pose_transform())
	draw_body()
	if is_legendary():
		_draw_sparkles()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if battle and not preview:
		var hint := battle.fusion_hint_for(self)
		if hint != null:
			var t := 0.5 + 0.5 * sin(_phase * 3.0)
			draw_arc(Vector2(0, float_y - 55), 62, 0, TAU, 32, Color(0.6, 1.0, 0.4, 0.5 + 0.4 * t), 4.0)
			_draw_result_bubble(hint, Vector2(44, float_y - 150))
		if lifted:
			draw_arc(Vector2(0, float_y - 55), 66, 0, TAU, 32, Color(1.0, 0.9, 0.4, 0.9), 5.0)
	_draw_health_bar()

## Small preview of the hybrid a graft would produce.
func _draw_result_bubble(d: PlantData, at: Vector2) -> void:
	draw_circle(at, 34, Color(1, 1, 1, 0.92))
	draw_arc(at, 34, 0, TAU, 28, Color(0.35, 0.65, 0.2), 3.0)
	var r := Rig.plant(d.id)
	if r:
		r.draw_static(self, Transform2D(0.0, Vector2(0.28, 0.28), 0.0, at + Vector2(0, 26)))
	else:
		DrawUtil.circle(self, at, 18, d.color_main)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_aura() -> void:
	var tex := FxSheet.tex(AURA_TEX)
	var a := 0.35 + 0.35 * pose_glow
	draw_set_transform(Vector2(0, -70 - pose_bob), _phase * 0.12, Vector2.ONE * (0.72 + 0.06 * sin(_phase * 0.8)))
	draw_texture(tex, -tex.get_size() * 0.5, Color(1, 0.95, 0.75, a))
	draw_set_transform(Vector2(0, -70 - pose_bob), -_phase * 0.08, Vector2.ONE * 0.5)
	draw_texture(tex, -tex.get_size() * 0.5, Color(1, 1, 1, a * 0.6))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Golden glints orbiting the plant (sprite-sheet frames drawn in place).
func _draw_sparkles() -> void:
	var sheet := FxSheet.sheet(&"sparkle")
	for i: int in 4:
		var t := _phase * 0.9 + float(i) * 1.7
		var f := int(t * 3.0) % 8
		var p := Vector2(cos(t * 0.7 + i) * 52.0, -80.0 + sin(t * 0.9 + i * 2.0) * 46.0)
		draw_texture_rect_region(sheet, Rect2(p - Vector2(20, 20), Vector2(40, 40)), FxSheet.frame_rect(&"sparkle", f))

func draw_body() -> void:
	if rig == null:
		DrawUtil.circle(self, Vector2(0, -50), 30, data.color_main)
		return
	draw_rig(pose_transform())

# --- painted rig -------------------------------------------------------------
## Draws every visible part. World transform of a part =
## parent world * translate(pivot) * rig_local(part).
func draw_rig(base: Transform2D) -> void:
	var world: Dictionary = {}
	for n: StringName in rig.chain_order:
		var par := rig.parent(n)
		var pw: Transform2D = world[par] if par != &"" and world.has(par) else base
		world[n] = pw * Transform2D(0.0, rig.pos(n)) * rig_local(n)
	for n: StringName in rig.draw_order:
		if rig_visible(n):
			rig.draw(self, n, world[n], rig_modulate(n))
	draw_rig_extras(world)
	draw_set_transform_matrix(base)

## Per-part animation on top of the clip pose (override for special parts).
func rig_local(n: StringName) -> Transform2D:
	var sway := sway_amount()
	match n:
		&"stem":
			return Transform2D(sin(_phase) * 0.035 * sway + pose_lean * 0.25, Vector2.ZERO)
		&"head":
			var sq := pose_squash * 0.6 + _wob * 0.2
			return Transform2D(sin(_phase - 0.7) * 0.05 * sway + pose_lean * 0.35 + _wob * 0.25,
				Vector2(1.0 - sq * 0.4, 1.0 + sq), 0.0, Vector2(-pose_kick * 0.9, 0.0))
		&"back":
			return Transform2D(sin(_phase + 0.6) * 0.04, Vector2(1.0, 1.0 + pose_squash * 0.25), 0.0, Vector2.ZERO)
		&"front":
			return Transform2D(-sin(_phase + 1.1) * 0.04, Vector2(1.0, 1.0 + pose_squash * 0.25), 0.0, Vector2.ZERO)
		&"canopy":
			return Transform2D(sin(_phase * 0.7) * 0.03 + _wob * 0.15, Vector2.ZERO)
	return Transform2D.IDENTITY

func rig_visible(n: StringName) -> bool:
	match n:
		&"lids":
			return _blink > 0.0 and not dead
		&"buried", &"body_1", &"body_2":
			return false
	return true

func rig_modulate(_n: StringName) -> Color:
	return Color.WHITE

## Hook for glows/overlays drawn after the parts (world = part transforms).
func draw_rig_extras(_world: Dictionary) -> void:
	pass

## Rig anchor in plant-local space (e.g. the muzzle), scaled by the pose.
func rig_point(key: String, fallback: Vector2) -> Vector2:
	if rig == null:
		return fallback
	return rig.meta_vec(key, fallback)

# --- shared drawing pieces ---------------------------------------------------
func draw_stem_and_leaves(top: Vector2, c: Color) -> void:
	DrawUtil.stem(self, Vector2(0, 0), top, c.darkened(0.1), 7.0)
	var flap := sin(_phase) * 0.08 + pose_squash * 0.6
	DrawUtil.leaf(self, Vector2(-2, -4), 34, PI + 0.35 + flap, c)
	DrawUtil.leaf(self, Vector2(2, -4), 34, -0.35 - flap, c)

func draw_face(center: Vector2, r: float, look: Vector2 = Vector2(1, 0)) -> void:
	var blink := 1.0 if fmod(_phase, 9.0) < 0.15 else 0.0
	DrawUtil.eye(self, center + Vector2(-r * 0.35, -r * 0.15), r * 0.22, look, blink)
	DrawUtil.eye(self, center + Vector2(r * 0.35, -r * 0.15), r * 0.22, look, blink)
	draw_arc(center + Vector2(0, r * 0.2), r * 0.3, 0.3, PI - 0.3, 10, Color(0.15, 0.1, 0.08), 3.0)

func _draw_health_bar() -> void:
	if preview or dead or battle == null:
		return
	var mode := int(Settings.get_value(&"health_bars"))
	var r := hp / max_hp_now()
	if mode == 0 or (mode == 1 and r > 0.995):
		return
	var y := -hover_height() + 14.0
	var hc := bool(Settings.get_value(&"high_contrast_hp"))
	draw_rect(Rect2(-32, y - 1, 64, 8), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-31, y, 62 * clampf(r, 0, 1), 6), Color(0, 1, 0.3) if hc else Color(0.35, 0.85, 0.3))
