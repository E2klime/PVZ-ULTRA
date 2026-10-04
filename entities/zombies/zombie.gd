class_name Zombie
extends Node2D
## Base zombie. FSM: SPAWN -> WALK -> EAT -> ABILITY -> DIE.
## Statuses: STUNNED, SLOWED, BURNING, FROZEN (Rime Lettuce: fully stopped, ice block).
##
## Animation: an AnimationPlayer plays clips from res://anim/zombie_anims.tres
## (walk / eat / spawn / die / idle). Clips key pose_* properties; draw_humanoid()
## reads them, so every humanoid shares one rig and one clip library.
## Walk speed_scale follows real ground speed (no foot sliding); eat speed follows
## eat_interval. Freeze and stun pause the player, slow scales it down.

enum State { SPAWN, WALK, EAT, ABILITY, DIE }

const FLASH_SHADER: Shader = preload("res://shaders/entity_fx.gdshader")
const ANIMS: AnimationLibrary = preload("res://anim/zombie_anims.tres")
const ICE_TEX := "res://assets/fx/ice_block.png"
## Ground covered by one walk cycle (two steps), in px at body_scale 1.
const STRIDE := 56.0
## Drawn slightly "in front" of plants of the same row (y-sorted layer).
const Y_OFFSET := 3.0

var battle: Battle
var data: ZombieData
var diff: DifficultyData
var row: int = 0
var hp: float = 1.0
var max_hp: float = 1.0
var armor: float = 0.0
var max_armor: float = 0.0
var state: State = State.SPAWN
var state_t: float = 0.0
## -1 = walking towards the house.
var dir: float = -1.0
var target: Plant
var underground: bool = false
var preview: bool = false
## Current profile (&"ground", &"low", &"air"); boxed/balloon zombies drop to ground when their cover breaks.
var profile: StringName = &"ground"
## Formation leader this zombie tucks in behind (follow_leader zombies only).
var leader: Zombie
var _garlic_cd: float = 0.0

var slow_t: float = 0.0
var slow_factor: float = 1.0
var stun_t: float = 0.0
var burn_t: float = 0.0
var burn_dps: float = 0.0
var _push_left: float = 0.0
var _bite_t: float = 0.0
var _flash: float = 0.0
var _mat: ShaderMaterial
var walk_phase: float = randf() * TAU
var lost_arm: bool = false
var hop: float = 0.0
var _y_target: float = 0.0
var freeze_t: float = 0.0
## Clip used by setup_preview() entities (almanac: walk in place, street: idle).
var preview_clip: StringName = &"walk"

# --- pose (keyed by AnimationPlayer clips) ---------------------------------------
var anim: AnimationPlayer
var pose_cycle: float = 0.0
var pose_bob: float = 0.0
var pose_lean: float = 0.0
var pose_head: float = 0.0
var pose_arm: float = 0.0
var pose_jaw: float = 0.0
var pose_squash: float = 0.0
var pose_rise: float = 0.0
var pose_fall: float = 0.0
var pose_head_off: float = 0.0
var pose_alpha: float = 1.0
var _kick: float = 0.0
var _kick_v: float = 0.0
## Painted cut-out parts (assets/sprites/zombies/<id>); null = procedural fallback.
var rig: Rig
## 0..1 how deep the zombie is in a water cell (pool levels).
var submerge: float = 0.0
const BACK_TINT := Color(0.74, 0.74, 0.8)
var _seed: float = randf() * 10.0

func setup(b: Battle, d: ZombieData, r: int, x: float) -> void:
	battle = b
	data = d
	diff = b.diff
	row = r
	hp = d.hp
	max_hp = d.hp
	armor = d.armor_hp
	max_armor = d.armor_hp
	position = Vector2(x, Board.row_feet_y(r) + Y_OFFSET)
	_y_target = position.y
	profile = d.profile
	on_setup()

func setup_preview(d: ZombieData) -> void:
	data = d
	preview = true
	hp = d.hp
	max_hp = d.hp
	armor = d.armor_hp
	max_armor = d.armor_hp
	diff = DifficultyData.new()
	profile = d.profile

func on_setup() -> void:
	pass

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	_mat.set_shader_parameter("seed", _seed)
	material = _mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rig = Rig.zombie(data.id)
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	anim.add_animation_library(&"", ANIMS)
	anim.playback_default_blend_time = 0.15
	add_child(anim)
	if preview:
		anim.play(preview_clip)
		anim.seek(randf() * anim.current_animation_length, true)
		anim.speed_scale = 0.6
	else:
		anim.play(&"spawn")
		anim.queue(&"walk")
		if battle and not underground:
			battle.fx_dust(position)

## Picks the clip for the current FSM state.
func _sync_anim() -> void:
	if anim == null or state == State.DIE:
		return
	var want: StringName = &"eat" if state == State.EAT else &"walk"
	if anim.current_animation == &"spawn":
		anim.clear_queue()
		anim.queue(want)
	elif anim.current_animation != want:
		pose_rise = 0.0
		anim.play(want)

func is_frozen() -> bool:
	return freeze_t > 0.0

# --- queries -----------------------------------------------------------------
func is_alive() -> bool:
	return state != State.DIE

func is_targetable() -> bool:
	return state != State.DIE and not underground

## Which attacks can reach this zombie right now.
## Boxed (&"low") zombies are hidden from straight shots; balloons (&"air") fly over most plants.
func hittable_by(kind: StringName) -> bool:
	if not is_targetable():
		return false
	match profile:
		&"low":
			return kind != &"straight" and kind != &"anti_air"
		&"air":
			return kind in [&"anti_air", &"air", &"wind", &"chain", &"explosion", &"bee", &"freeze", &"burn", &"thorns"]
	return true

func is_flying() -> bool:
	return profile == &"air"

func hit_center_x() -> float:
	return position.x - 6.0 * data.body_scale

func can_be_devoured() -> bool:
	return is_targetable() and not data.immune_to.has(&"devour")

func base_speed() -> float:
	return data.speed

func speed_mult() -> float:
	var m := diff.zombie_speed_mult
	if slow_t > 0.0:
		m *= slow_factor
	return m

# --- update ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if preview or state == State.DIE:
		return
	_tick_status(delta)
	if state == State.DIE:
		return
	if absf(_push_left) > 0.5:
		var step: float = signf(_push_left) * min(absf(_push_left), 520.0 * delta)
		position.x = min(position.x + step, Board.SPAWN_X + 60.0)
		_push_left -= step
	if absf(position.y - _y_target) > 0.5:
		position.y = move_toward(position.y, _y_target, 300.0 * delta)
	if battle and battle.board:
		var wet := 1.0 if (not underground and battle.board.water_at(row, position.x)) else 0.0
		submerge = move_toward(submerge, wet, delta * 2.2)
	if freeze_t > 0.0:
		freeze_t -= delta
		if freeze_t <= 0.0:
			_thaw()
		return
	if stun_t > 0.0:
		stun_t -= delta
		return
	state_t += delta
	match state:
		State.SPAWN:
			if state_t > 0.35:
				_set_state(State.WALK)
		State.WALK:
			_walk(delta)
		State.EAT:
			_eat(delta)
		State.ABILITY:
			_ability(delta)
	_check_bounds()

func _set_state(s: State) -> void:
	state = s
	state_t = 0.0
	_sync_anim()

func _tick_status(delta: float) -> void:
	if _garlic_cd > 0.0:
		_garlic_cd -= delta
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_factor = 1.0
			_mat.set_shader_parameter("tint", Color.WHITE)
	if burn_t > 0.0:
		burn_t -= delta
		take_damage(burn_dps * delta, &"burn")
		if burn_t <= 0.0:
			_mat.set_shader_parameter("burn", 0.0)
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 7.0)
		_mat.set_shader_parameter("flash", _flash)

func _walk(delta: float) -> void:
	var p := battle.board.blocking_plant(row, position.x, dir)
	if p and _on_plant_blocking(p):
		return
	var sp := base_speed() * Board.CELL.x * speed_mult()
	if data.follow_leader:
		sp = _follow_speed(sp)
	position.x += dir * sp * delta
	walk_phase += delta * 5.0 * speed_mult() * (base_speed() / 0.21)

## Formation: stay ~48 px behind the closest zombie ahead in the lane, at its pace.
func _follow_speed(own: float) -> float:
	if leader == null or not is_instance_valid(leader) or not leader.is_alive() or leader.row != row:
		leader = _find_leader()
	if leader == null:
		return own
	var gap := (position.x - leader.position.x) * -dir
	var lead_v := leader.base_speed() * Board.CELL.x * leader.speed_mult()
	if leader.state == State.EAT or leader.is_frozen() or leader.stun_t > 0.0:
		lead_v = 0.0
	if gap > 120.0:
		return maxf(own * 1.6, lead_v * 1.3)
	if gap < 40.0:
		return lead_v * 0.6
	return lead_v

func _find_leader() -> Zombie:
	var best: Zombie
	for z: Zombie in battle.zombies_in_row(row):
		if z == self or not z.is_alive() or z.data.follow_leader or z.underground:
			continue
		var ahead := (position.x - z.position.x) * -dir
		if ahead > 0.0 and ahead < Board.CELL.x * 3.0 and (best == null or z.position.x > best.position.x):
			best = z
	return best

## Garlic: the zombie gags and shuffles into a neighbouring lane (2 s cooldown).
func garlic() -> void:
	if _garlic_cd > 0.0 or data.immune_to.has(&"pull") or is_flying() or state == State.DIE:
		return
	_garlic_cd = 3.0
	var options: Array[int] = []
	for r: int in [row - 1, row + 1]:
		if r >= 0 and r < Board.ROWS:
			options.append(r)
	if not options.is_empty():
		move_to_row(options[randi() % options.size()])

func _on_plant_blocking(p: Plant) -> bool:
	target = p
	_bite_t = data.eat_interval * 0.5
	_set_state(State.EAT)
	return true

func _eat(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		target = null
		_set_state(State.WALK)
		return
	if battle.board.blocking_plant(row, position.x, dir) != target:
		target = null
		_set_state(State.WALK)
		return
	var m := slow_factor if slow_t > 0.0 else 1.0
	walk_phase += delta * 9.0 * m
	_bite_t -= delta * m
	if _bite_t <= 0.0:
		_bite_t += data.eat_interval
		_bite(target)

func _bite(p: Plant) -> void:
	Sfx.play(&"chomp", -8.0, 0.1, 160)
	p.take_damage(data.damage * data.eat_interval * diff.zombie_dps_mult, self)

func _ability(_delta: float) -> void:
	_set_state(State.WALK)

func _check_bounds() -> void:
	if dir < 0.0 and (position.x < Board.HOUSE_X or battle.mower_reached(row, position.x)):
		battle.on_zombie_at_house(self)
	elif dir > 0.0 and position.x > Board.SPAWN_X + 80.0:
		despawn()

# --- damage & statuses -------------------------------------------------------
func take_damage(amount: float, kind: StringName = &"projectile") -> void:
	if state == State.DIE or amount <= 0.0:
		return
	amount *= diff.zombie_damage_taken_mult
	Sfx.play(&"hit", -14.0, 0.15, 70)
	amount = absorb(amount, kind)
	hp -= amount
	if kind != &"burn":
		_flash = 0.6
		_kick_v = min(_kick_v + 70.0, 160.0)
	if not lost_arm and hp < max_hp * 0.5:
		lost_arm = true
		if battle:
			battle.fx_limb(position + Vector2(-30, -95) * data.body_scale, data.color_skin)
	if hp <= 0.0:
		die(kind)

## Armour soaks damage first. Returns the remaining damage for the body.
func absorb(amount: float, _kind: StringName) -> float:
	if armor <= 0.0:
		return amount
	var a: float = min(armor, amount)
	armor -= a
	if armor <= 0.0 and battle:
		battle.fx_armor_break(position + Vector2(-4, -150) * data.body_scale, armor_color())
		on_armor_broken()
	return amount - a

## Box torn / balloon popped: the zombie becomes an ordinary ground walker.
func on_armor_broken() -> void:
	Sfx.play(&"pop_balloon" if data.armor_kind == &"balloon" else &"armor", -4.0)
	if data.armor_kind == &"box" or data.armor_kind == &"balloon":
		profile = &"ground"

func armor_color() -> Color:
	match data.armor_kind:
		&"cone":
			return Color(0.95, 0.55, 0.15)
		&"bucket":
			return Color(0.65, 0.67, 0.7)
		&"shield":
			return Color(0.55, 0.5, 0.45)
		&"box":
			return Color(0.72, 0.55, 0.34)
		&"balloon":
			return Color(0.9, 0.2, 0.2)
	return Color.WHITE

func apply_slow(factor: float, duration: float) -> void:
	if data.immune_to.has(&"slow") or state == State.DIE:
		return
	slow_factor = min(slow_factor, factor) if slow_t > 0.0 else factor
	slow_t = max(slow_t, duration)
	_mat.set_shader_parameter("tint", Color(0.6, 0.8, 1.15))

func push(distance: float) -> void:
	if data.immune_to.has(&"push") or underground:
		return
	_push_left += distance

func stun(t: float) -> void:
	if data.immune_to.has(&"push"):
		return
	stun_t = max(stun_t, t)

func burn(dps: float, t: float) -> void:
	burn_dps = max(burn_dps if burn_t > 0.0 else 0.0, dps)
	burn_t = max(burn_t, t)
	_mat.set_shader_parameter("burn", 1.0)

## Frozen solid in an ice block: no walking, no biting. Giants thaw twice as fast.
func freeze(t: float) -> void:
	if state == State.DIE or underground or t <= 0.0:
		return
	var dur := t * (0.5 if data.immune_to.has(&"push") else 1.0)
	if freeze_t <= 0.0 and battle:
		battle.fx_freeze(position + Vector2(0, -95) * data.body_scale)
	freeze_t = max(freeze_t, dur)
	_mat.set_shader_parameter("frozen", 1.0)

func _thaw() -> void:
	freeze_t = 0.0
	_mat.set_shader_parameter("frozen", 0.0)
	if battle:
		battle.fx_shatter(position + Vector2(0, -95) * data.body_scale)
	apply_slow(0.5, 4.0)

func move_to_row(r: int) -> void:
	if r == row or data.immune_to.has(&"pull"):
		return
	battle.change_zombie_row(self, r)
	row = r
	_y_target = Board.row_feet_y(r) + Y_OFFSET
	target = null
	if state == State.EAT:
		_set_state(State.WALK)

func die(kind: StringName = &"normal") -> void:
	if state == State.DIE:
		return
	_set_state(State.DIE)
	battle.on_zombie_died(self, true)
	var tw := create_tween()
	if kind == &"mower":
		tw.tween_property(self, "position", position + Vector2(260, -120), 0.45)
		tw.parallel().tween_property(self, "rotation", 6.0, 0.45)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
	elif kind == &"explosion":
		modulate = Color(0.25, 0.22, 0.2)
		tw.tween_interval(0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		if battle:
			battle.fx_ash(position + Vector2(0, -80) * data.body_scale)
		return
	else:
		# Clip-driven fall: head pops off, body hits the ground, fades.
		tw.kill()
		freeze_t = 0.0
		_mat.set_shader_parameter("frozen", 0.0)
		anim.clear_queue()
		anim.speed_scale = 1.0
		anim.play(&"die", 0.08)
		get_tree().create_timer(2.0, false).timeout.connect(queue_free)
		return
	tw.tween_callback(queue_free)

## Swallowed by a trap: vanishes instantly.
func devour() -> void:
	if state == State.DIE:
		return
	_set_state(State.DIE)
	battle.on_zombie_died(self, true)
	queue_free()

## Blown off the lawn by wind (Gale Fern vs balloons). Counts as a kill.
func blow_away() -> void:
	if state == State.DIE:
		return
	_set_state(State.DIE)
	battle.on_zombie_died(self, true)
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector2(900, -420), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation", -1.2, 1.1)
	tw.tween_callback(queue_free)

func despawn() -> void:
	if state == State.DIE:
		return
	_set_state(State.DIE)
	battle.on_zombie_died(self, false)
	queue_free()

# --- animation events ----------------------------------------------------------
func _on_footstep() -> void:
	if preview or battle == null:
		return
	if state == State.DIE:
		battle.fx_dust(position + Vector2(40, 0) * data.body_scale)
	elif data.body_scale > 1.2:
		battle.shake(2.5)
		battle.fx_dust(position)
	elif randf() < 0.15 and not underground:
		battle.fx_dust(position)

func _on_bite_frame() -> void:
	if preview or battle == null or target == null or not is_instance_valid(target):
		return
	battle.fx_crumbs(target.position + Vector2(18, -50), target.data.color_main)

func _on_die_finished() -> void:
	queue_free()
# --- drawing -----------------------------------------------------------------
func _process(delta: float) -> void:
	if preview:
		walk_phase += delta * 4.0
	scale.x = absf(scale.x) * (1.0 if dir < 0.0 else -1.0)
	# hit recoil spring (px, positive = pushed back)
	var rem := minf(delta, 0.25)
	while rem > 0.0:
		var h := minf(rem, 1.0 / 120.0)
		_kick_v += (-260.0 * _kick - 16.0 * _kick_v) * h
		_kick += _kick_v * h
		rem -= h
	_kick = clampf(_kick, -30.0, 30.0)
	if anim and not preview and state != State.DIE:
		anim.speed_scale = _anim_speed()
	if anim and anim.current_animation == &"die":
		modulate.a = pose_alpha
	queue_redraw()

func _anim_speed() -> float:
	if freeze_t > 0.0 or stun_t > 0.0:
		return 0.0
	if anim.current_animation == &"spawn":
		return 1.0
	var slow := slow_factor if slow_t > 0.0 else 1.0
	if state == State.EAT:
		return clampf(slow / maxf(0.2, data.eat_interval), 0.2, 2.5)
	var v := base_speed() * Board.CELL.x * speed_mult()
	return clampf(v / (STRIDE * data.body_scale), 0.12, 2.2)

func _draw() -> void:
	if data == null:
		return
	var s := data.body_scale
	var shadow := 1.0 - pose_fall * 0.2
	if submerge < 0.5:
		draw_colored_polygon(DrawUtil.ellipse_points(Vector2(0, 4), 36 * s * shadow, 10 * s), Color(0, 0, 0, 0.22 * (1.0 - submerge * 2.0)))
	if submerge > 0.02:
		_draw_ripple(s, false)
	if underground:
		_draw_mound()
		return
	var body := _body_xf()
	draw_set_transform_matrix(body)
	draw_humanoid()
	if submerge > 0.02:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_draw_ripple(s, true)
	if freeze_t > 0.0:
		draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, Vector2(0, -hop)))
		var tex := FxSheet.tex(ICE_TEX)
		var a := clampf(freeze_t * 3.0, 0.0, 1.0) * 0.88
		draw_texture_rect(tex, Rect2(Vector2(-78, -212), Vector2(150, 216)), false, Color(1, 1, 1, a))
	if burn_t > 0.0 and state != State.DIE:
		draw_set_transform_matrix(body)
		var f := int((Time.get_ticks_msec() * 0.001 + _seed) * 12.0)
		var sheet := FxSheet.sheet(&"flame")
		draw_texture_rect_region(sheet, Rect2(Vector2(-26, -150), Vector2(44, 66)), FxSheet.frame_rect(&"flame", f), Color(1, 1, 1, 0.9))
		draw_texture_rect_region(sheet, Rect2(Vector2(-6, -98), Vector2(38, 57)), FxSheet.frame_rect(&"flame", f + 3), Color(1, 1, 1, 0.85))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	_draw_health_bar()
	_draw_status_glyphs()

## Colour-blind hints (Settings > Accessibility): shapes for statuses that are
## otherwise shown only by tint: slowed (down chevrons), burning (flame), frozen (snowflake).
func _draw_status_glyphs() -> void:
	if preview or state == State.DIE or not bool(Settings.get_value(&"colorblind_hints")):
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var at := Vector2(-40.0 * data.body_scale, -200.0 * data.body_scale - hop)
	var ink := Color(1, 1, 1, 0.95)
	var outline := Color(0, 0, 0, 0.8)
	if freeze_t > 0.0:
		for i: int in 3:
			var d := Vector2.RIGHT.rotated(PI / 3.0 * i) * 11.0
			draw_line(at - d, at + d, outline, 6.0)
			draw_line(at - d, at + d, ink, 3.0)
		at.x += 30.0
	elif slow_t > 0.0:
		for k: int in 2:
			var y := at.y - 6.0 + k * 9.0
			var pts := PackedVector2Array([Vector2(at.x - 9, y), Vector2(at.x, y + 7), Vector2(at.x + 9, y)])
			draw_polyline(pts, outline, 6.0)
			draw_polyline(pts, ink, 3.0)
		at.x += 30.0
	if burn_t > 0.0:
		var flame := PackedVector2Array([at + Vector2(0, -12), at + Vector2(8, 4), at + Vector2(0, 10), at + Vector2(-8, 4), at + Vector2(0, -12)])
		draw_polyline(flame, outline, 6.0)
		draw_polyline(flame, Color(1, 0.85, 0.3), 3.0)

## Water rings around a swimming zombie (back half behind the body, front half over it).
func _draw_ripple(s: float, front: bool) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _seed
	var a := clampf(submerge, 0.0, 1.0)
	var y := -6.0 * s
	for i: int in 2:
		var k := fmod(t * 0.6 + i * 0.5, 1.0)
		var rx := (40.0 + k * 34.0) * s
		var ry := (11.0 + k * 8.0) * s
		var col := Color(0.85, 0.97, 1.0, a * (1.0 - k) * 0.7)
		if front:
			var pts := PackedVector2Array()
			for j: int in 17:
				var ang := lerpf(0.1, PI - 0.1, j / 16.0)
				pts.append(Vector2(cos(ang) * rx, y + sin(ang) * ry))
			draw_polyline(pts, col, 3.0, true)
		else:
			var pts := PackedVector2Array()
			for j: int in 17:
				var ang := lerpf(PI + 0.1, TAU - 0.1, j / 16.0)
				pts.append(Vector2(cos(ang) * rx, y + sin(ang) * ry))
			draw_polyline(pts, col, 2.5, true)
	if front:
		draw_colored_polygon(DrawUtil.ellipse_points(Vector2(0, y + 2.0), 34.0 * s, 8.0 * s), Color(0.3, 0.75, 0.9, 0.25 * a))

func _draw_mound() -> void:
	var w := sin(walk_phase * 2.0) * 3.0
	DrawUtil.ellipse(self, Vector2(0, -6), 40, 16 + w, Color(0.45, 0.32, 0.2))
	for i: int in 4:
		draw_circle(Vector2(-30 + i * 20, -16 - absf(sin(walk_phase + i)) * 10), 4, Color(0.35, 0.25, 0.15))

func walking() -> bool:
	return state == State.WALK or state == State.SPAWN or state == State.ABILITY

## Two-segment leg. swing = thigh angle, bend = knee flex (foot trails behind).
func _leg(hip: Vector2, swing: float, bend: float, c: Color, shoe: Color) -> void:
	var knee := hip + Vector2.DOWN.rotated(swing) * 27.0
	var foot := knee + Vector2.DOWN.rotated(swing - bend) * 27.0
	DrawUtil.line(self, hip, knee, c, 11)
	DrawUtil.line(self, knee, foot, c.darkened(0.08), 10)
	DrawUtil.ellipse(self, foot + Vector2(-6, 0), 11, 5, shoe, 2)

func draw_humanoid() -> void:
	if rig != null:
		_draw_rig_humanoid()
		return
	var skin := data.color_skin
	var cloth := data.color_cloth
	var c := pose_cycle * TAU
	var stride := 0.45 if walking() else 0.0
	var swing := sin(c) * stride
	var bend1 := maxf(0.0, cos(c)) * 0.7 * (stride / 0.45)
	var bend2 := maxf(0.0, -cos(c)) * 0.7 * (stride / 0.45)
	var lean := 0.0
	if data.id == &"sprinter":
		lean = -10.0
	var hip := Vector2(4, -52)
	# legs (not affected by upper-body lean)
	_leg(hip, -swing, bend2, cloth.darkened(0.25), Color(0.25, 0.2, 0.16))
	_leg(hip, swing, bend1, cloth.darkened(0.15), Color(0.3, 0.25, 0.2))
	# upper body leans around the hip
	var lean_rot := pose_lean + _kick * 0.004 - (0.12 if data.id == &"sprinter" else 0.0)
	var upper := Transform2D(0.0, hip) * Transform2D(lean_rot, Vector2.ZERO) * Transform2D(0.0, -hip)
	_push(upper)
	var sh := Vector2(lean, 0)
	# back arm (two segments)
	var shoulder := Vector2(10, -104) + sh
	var elbow_b := shoulder + Vector2(-24, 14).rotated(-pose_arm * 0.7)
	var hand_back := elbow_b + Vector2(-22, 4).rotated(-pose_arm)
	draw_accessory_back(sh)
	DrawUtil.line(self, shoulder, elbow_b, skin.darkened(0.15), 9)
	DrawUtil.line(self, elbow_b, hand_back, skin.darkened(0.18), 8)
	# torso
	DrawUtil.rrect(self, Rect2(Vector2(-22, -116) + sh, Vector2(46, 66)), cloth, 12)
	DrawUtil.poly(self, PackedVector2Array([Vector2(-2, -112) + sh, Vector2(6, -112) + sh, Vector2(4, -74) + sh, Vector2(0, -74) + sh]), Color(0.55, 0.15, 0.15), 2)
	# head (tilts around the neck; pops off in the death clip)
	var neck := Vector2(-4, -114) + sh
	var head_xf := Transform2D(0.0, neck) * Transform2D(pose_head - _kick * 0.003 + pose_head_off * 2.6, Vector2.ZERO) \
		* Transform2D(0.0, -neck + Vector2(-60.0, 118.0) * pose_head_off)
	_push(upper * head_xf)
	var head := Vector2(-6, -138) + sh
	DrawUtil.circle(self, head, 26, skin)
	DrawUtil.eye(self, head + Vector2(-12, -6), 7.5, Vector2(-1, 0.2))
	DrawUtil.eye(self, head + Vector2(4, -5), 5.5, Vector2(-1, 0.3))
	var jaw := pose_jaw * 9.0
	DrawUtil.rrect(self, Rect2(head + Vector2(-20, 8), Vector2(18, 6 + jaw)), Color(0.25, 0.12, 0.12), 3, 2)
	draw_line(head + Vector2(-17, 9), head + Vector2(-17, 13), Color(0.95, 0.9, 0.8), 3)
	draw_line(head + Vector2(-10, 9), head + Vector2(-10, 13), Color(0.95, 0.9, 0.8), 3)
	draw_accessory_head(head)
	_push(upper)
	# front arm: classic zombie reach, extended further while eating
	var front_sh := Vector2(-14, -102) + sh
	if lost_arm:
		DrawUtil.line(self, front_sh, front_sh + Vector2(-10, 14), skin.darkened(0.05), 9)
	else:
		var elbow := front_sh + Vector2(-24, 10).rotated(pose_arm * 0.6)
		var hand := elbow + Vector2(-22, 4).rotated(pose_arm)
		DrawUtil.line(self, front_sh, elbow, skin, 9)
		DrawUtil.line(self, elbow, hand, skin.lightened(0.03), 8)
		DrawUtil.circle(self, hand, 6, skin, 2)
	draw_accessory_front(sh)
	_pop_xf()

# --- painted rig -------------------------------------------------------------
## Same kinematics as the procedural body, but each segment is a painted part
## whose pivot is placed at the joint and rotated along the bone.
func _bone(a: Vector2, b: Vector2) -> float:
	return (b - a).angle() - PI / 2.0

func _rp(n: StringName, xf: Transform2D, mod: Color = Color.WHITE) -> void:
	if rig.has(n):
		rig.draw(self, n, _body_xf() * xf, mod)

func _rig_leg(hip: Vector2, swing: float, bend: float, mod: Color) -> void:
	var knee := hip + Vector2.DOWN.rotated(swing) * 26.0
	_rp(&"thigh", Transform2D(swing, hip), mod)
	_rp(&"shin", Transform2D(swing - bend, knee), mod)

func _rig_arm(upper: Transform2D, shoulder: Vector2, elbow: Vector2, hand: Vector2, mod: Color) -> void:
	_rp(&"arm_upper", upper * Transform2D(_bone(shoulder, elbow), shoulder), mod)
	_rp(&"arm_fore", upper * Transform2D(_bone(elbow, hand), elbow), mod)

func _draw_rig_humanoid() -> void:
	var c := pose_cycle * TAU
	var stride := 0.45 if walking() else 0.0
	var swing := sin(c) * stride
	var bend1 := maxf(0.0, cos(c)) * 0.7 * (stride / 0.45)
	var bend2 := maxf(0.0, -cos(c)) * 0.7 * (stride / 0.45)
	var hip := Vector2(4, -52)
	var lean_rot := pose_lean + _kick * 0.004 - (0.12 if data.id == &"sprinter" else 0.0)
	var upper := Transform2D(0.0, hip) * Transform2D(lean_rot, Vector2.ZERO) * Transform2D(0.0, -hip)
	var sh := Vector2(-10.0 if data.id == &"sprinter" else 0.0, 0.0)
	# back arm + back items behind everything
	var shoulder_b := Vector2(12, -106) + sh
	var elbow_b := shoulder_b + Vector2(-20, 18).rotated(-pose_arm * 0.7)
	var hand_b := elbow_b + Vector2(-18, 10).rotated(-pose_arm)
	rig_back_items(upper, sh)
	_rig_arm(upper, shoulder_b, elbow_b, hand_b, BACK_TINT)
	if submerge < 0.98:
		var la := clampf(1.0 - submerge * 1.6, 0.0, 1.0)
		_rig_leg(hip + Vector2(6, 0), -swing, bend2, Color(BACK_TINT, BACK_TINT.a * la))
		_rig_leg(hip + Vector2(-6, 0), swing, bend1, Color(1, 1, 1, la))
	_rp(&"torso", upper * Transform2D(0.0, hip))
	# head (tilts around the neck; pops off in the death clip)
	var neck := Vector2(-8, -114) + sh
	var head_xf := upper * Transform2D(0.0, neck) * Transform2D(pose_head - _kick * 0.003 + pose_head_off * 2.6, Vector2.ZERO) \
		* Transform2D(0.0, Vector2(-60.0, 118.0) * pose_head_off)
	_rp(&"head", head_xf)
	_rp(&"jaw", head_xf * Transform2D(pose_jaw * 0.32, Vector2(4, -13)))
	var hat := hat_part()
	if hat != &"":
		_rp(hat, head_xf)
	# front arm: classic zombie reach
	var front_sh := Vector2(-14, -104) + sh
	if lost_arm:
		_rp(&"arm_stub", upper * Transform2D(0.5, front_sh))
	else:
		var elbow := front_sh + Vector2(-24, 10).rotated(pose_arm * 0.6)
		var hand := elbow + Vector2(-22, 4).rotated(pose_arm)
		_rig_arm(upper, front_sh, elbow, hand, Color.WHITE)
	rig_front_items(upper, sh)
	if submerge > 0.0:
		_rp(&"tube", Transform2D(0.0, Vector2(-2, -46)))

## Part name of the current headgear (armour stage), or &"" for none.
func hat_part() -> StringName:
	if data.armor_kind == &"cone" or data.armor_kind == &"bucket":
		if armor <= 0.0:
			return &""
		var ratio := armor / maxf(1.0, max_armor)
		return &"hat_0" if ratio > 0.66 else (&"hat_1" if ratio > 0.33 else &"hat_2")
	return &"hat_0" if rig.has(&"hat_0") else &""

func rig_back_items(upper: Transform2D, sh: Vector2) -> void:
	if rig.has(&"flag"):
		var wave := sin(walk_phase * 1.5) * 0.05
		_rp(&"flag", upper * Transform2D(0.08 + wave, Vector2(24, -58) + sh))

func rig_front_items(upper: Transform2D, sh: Vector2) -> void:
	if data.armor_kind == &"box" and armor > 0.0 and rig.has(&"box"):
		var ratio := armor / maxf(1.0, max_armor)
		var part := &"box" if ratio > 0.5 or not rig.has(&"box_1") else &"box_1"
		_rp(part, upper * Transform2D(pose_lean * 0.2, Vector2(2, -64) + sh))
	if data.armor_kind == &"shield" and armor > 0.0:
		var ratio := armor / maxf(1.0, max_armor)
		var part := &"shield_0" if ratio > 0.5 else &"shield_1"
		_rp(part, upper * Transform2D(-0.04 + pose_arm * 0.05, Vector2(-54, -96) + sh))

## Applies body * extra as the current draw transform (body set by _draw()).
func _push(extra: Transform2D) -> void:
	draw_set_transform_matrix(_body_xf() * extra)

func _pop_xf() -> void:
	draw_set_transform_matrix(_body_xf())

func _body_xf() -> Transform2D:
	var s := data.body_scale
	var sq := pose_squash - pose_rise * 0.55
	return Transform2D(pose_fall * 1.35, Vector2(s * (1.0 - sq * 0.4), s * (1.0 + sq)), 0.0,
		Vector2(_kick * 0.25, -hop - pose_bob * s * (1.0 - submerge * 0.7) + pose_rise * 30.0 * s + submerge * 46.0 * s))

func draw_accessory_back(sh: Vector2) -> void:
	if data.id == &"flagbearer":
		var pole_top := Vector2(26, -200) + sh
		DrawUtil.line(self, Vector2(22, -60) + sh, pole_top, Color(0.45, 0.32, 0.2), 4)
		var wave := sin(walk_phase * 1.5) * 6.0
		DrawUtil.poly(self, PackedVector2Array([pole_top, pole_top + Vector2(48, 6 + wave), pole_top + Vector2(42, 22), pole_top + Vector2(50, 40 + wave), pole_top + Vector2(0, 38)]), Color(0.32, 0.5, 0.3), 3)
		DrawUtil.circle(self, pole_top + Vector2(22, 19), 7, Color(0.85, 0.8, 0.65), 2)

func draw_accessory_head(head: Vector2) -> void:
	if armor <= 0.0:
		if data.id == &"sprinter":
			DrawUtil.rrect(self, Rect2(head + Vector2(-27, -16), Vector2(54, 9)), Color(0.9, 0.3, 0.25), 3, 2)
		return
	var ratio := armor / maxf(1.0, max_armor)
	match data.armor_kind:
		&"cone":
			var tilt := 0.0 if ratio > 0.66 else (0.15 if ratio > 0.33 else 0.3)
			var tip := head + Vector2(6, -78).rotated(tilt)
			var h := 1.0 if ratio > 0.33 else 0.75
			tip = head + (tip - head) * h
			DrawUtil.poly(self, PackedVector2Array([head + Vector2(-30, -14), tip, head + Vector2(28, -14)]), armor_color(), 3)
			draw_line(head + Vector2(-20, -32), head + Vector2(20, -32), Color(1, 0.9, 0.8), 4)
		&"bucket":
			DrawUtil.poly(self, PackedVector2Array([head + Vector2(-30, -6), head + Vector2(-24, -52), head + Vector2(24, -52), head + Vector2(30, -6)]), armor_color(), 3)
			if ratio < 0.66:
				draw_polyline(PackedVector2Array([head + Vector2(-10, -46), head + Vector2(-2, -32), head + Vector2(-12, -20)]), Color(0.3, 0.3, 0.32), 3)
			if ratio < 0.33:
				draw_circle(head + Vector2(10, -30), 6, Color(0.3, 0.3, 0.32))
		&"none":
			pass
	if data.id == &"burrower":
		DrawUtil.ellipse(self, head + Vector2(0, -16), 30, 16, Color(0.95, 0.75, 0.15), 3)
		draw_circle(head + Vector2(-24, -18), 6, Color(1, 1, 0.75))

func draw_accessory_front(sh: Vector2) -> void:
	if data.armor_kind == &"shield" and armor > 0.0:
		var ratio := armor / maxf(1.0, max_armor)
		var r := Rect2(Vector2(-66, -160) + sh, Vector2(26, 130))
		DrawUtil.rrect(self, r, armor_color(), 4)
		for i: int in 5:
			draw_line(r.position + Vector2(4, 12 + i * 24), r.position + Vector2(22, 24 + i * 24), Color(0.35, 0.32, 0.3), 2)
		if ratio < 0.5:
			draw_polyline(PackedVector2Array([r.position + Vector2(6, 30), r.position + Vector2(18, 50), r.position + Vector2(8, 70)]), Color(0.2, 0.18, 0.16), 3)

## Optional health bar (Settings > Gameplay > Health bars).
func _draw_health_bar() -> void:
	if preview or state == State.DIE:
		return
	var mode := int(Settings.get_value(&"health_bars"))
	var total := max_hp + max_armor
	var cur := hp + maxf(0.0, armor)
	if mode == 0 or (mode == 1 and cur >= total - 0.5):
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var w := 64.0 * data.body_scale
	var y := -190.0 * data.body_scale - hop
	var hc := bool(Settings.get_value(&"high_contrast_hp"))
	draw_rect(Rect2(-w * 0.5 - 2, y - 2, w + 4, 11), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-w * 0.5, y, w * clampf(hp / maxf(1.0, max_hp), 0, 1), 7), Color(1, 1, 0) if hc else Color(0.85, 0.2, 0.15))
	if max_armor > 0.0 and armor > 0.0:
		draw_rect(Rect2(-w * 0.5, y - 6, w * clampf(armor / max_armor, 0, 1), 4), Color(0, 1, 1) if hc else Color(0.75, 0.78, 0.85))
