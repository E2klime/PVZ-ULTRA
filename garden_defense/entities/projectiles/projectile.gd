class_name Projectile
extends Node2D
## Straight lane projectile (pooled by Battle). Supports pierce and slow.

var battle: Battle
var row: int = 0
var damage: float = 20.0
var speed: float = 560.0
var pierce_left: int = 0
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var color: Color = Color(0.5, 0.9, 0.3)
var needle: bool = false
var burn_dps: float = 0.0
var burn_time: float = 0.0
var is_fire: bool = false
var active: bool = false
## &"straight", &"low", &"air", &"anti_air" or &"lob" (see PlantData.attack_kind).
var kind: StringName = &"straight"
var splash: float = 0.0
var _hit: Array[Zombie] = []
var _lob_from: Vector2
var _lob_to: Vector2
var _lob_t: float = 0.0
var _lob_dur: float = 1.0
var _target_y: float = 0.0
var garlic: bool = false

func fire(b: Battle, r: int, pos: Vector2, dmg: float, src: PlantData) -> void:
	battle = b
	row = r
	position = pos
	rotation = 0.0
	damage = dmg
	speed = src.projectile_speed
	pierce_left = src.pierce
	slow_factor = src.slow_factor
	slow_duration = src.slow_duration
	color = src.color_accent if src.slow_factor >= 1.0 else Color(0.6, 0.92, 1.0)
	needle = src.pierce > 0
	burn_dps = src.burn_dps
	burn_time = src.burn_time
	is_fire = src.tags.has(&"fire") and src.burn_dps > 0.0
	if is_fire:
		color = Color(1.0, 0.55, 0.15)
	kind = src.attack_kind
	splash = src.aoe_radius
	garlic = src.tags.has(&"garlic")
	if kind == &"anti_air":
		color = Color(0.85, 0.95, 0.55)
		needle = true
	elif kind == &"low":
		color = src.color_accent
	elif kind == &"air":
		color = src.color_accent
	_target_y = Board.row_feet_y(r) - 60.0
	if kind == &"lob":
		var t := b.first_target_in_lane(r, pos.x - 20.0, Board.SPAWN_X - 45.0, &"lob")
		var tx := (t.hit_center_x() - t.base_speed() * Board.CELL.x * 0.9) if t else pos.x + Board.CELL.x * 3.0
		_lob_from = pos
		_lob_to = Vector2(maxf(tx, pos.x + 40.0), Board.row_feet_y(r) - 30.0)
		_lob_t = 0.0
		_lob_dur = clampf((_lob_to.x - pos.x) / 650.0, 0.55, 1.3)
	_hit.clear()
	active = true
	visible = true
	set_physics_process(true)
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)
	_hit.clear()
	if battle:
		battle.recycle_projectile(self)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if kind == &"lob":
		_lob_step(delta)
		return
	position.x += speed * delta
	if kind == &"air":
		position.y = move_toward(position.y, _target_y, 260.0 * delta)
	if position.x > Board.SPAWN_X + 120.0:
		deactivate()
		return
	# Copy: a kill removes the zombie from the lane and would skip the next one (pierce).
	for z: Zombie in battle.zombies_in_row(row).duplicate():
		if z in _hit or not z.hittable_by(kind):
			continue
		if absf(z.hit_center_x() - position.x) < 26.0:
			_hit.append(z)
			z.take_damage(damage, &"projectile" if kind == &"straight" else kind)
			if garlic:
				z.garlic()
			if slow_duration > 0.0:
				z.apply_slow(slow_factor, slow_duration)
			if burn_dps > 0.0:
				z.burn(burn_dps, burn_time)
			battle.fx_hit(position, color)
			if pierce_left <= 0:
				deactivate()
				return
			pierce_left -= 1

## Catapult arc: lands on the predicted spot, hurts the first ground/boxed zombie there + splash.
func _lob_step(delta: float) -> void:
	_lob_t += delta / _lob_dur
	var t := minf(_lob_t, 1.0)
	position = _lob_from.lerp(_lob_to, t) + Vector2(0, -sin(t * PI) * (160.0 + (_lob_to.x - _lob_from.x) * 0.12))
	rotation += delta * 8.0
	if t < 1.0:
		return
	rotation = 0.0
	var best: Zombie
	for z: Zombie in battle.zombies_in_row(row):
		if z.hittable_by(&"lob") and absf(z.hit_center_x() - _lob_to.x) < 70.0:
			if best == null or z.position.x < best.position.x:
				best = z
	if best:
		best.take_damage(damage, &"lob")
		if slow_duration > 0.0:
			best.apply_slow(slow_factor, slow_duration)
		if burn_dps > 0.0:
			best.burn(burn_dps, burn_time)
	if splash > 0.0:
		for z: Zombie in battle.zombies_in_row(row).duplicate():
			if z != best and z.hittable_by(&"lob") and absf(z.position.x - _lob_to.x) < splash * Board.CELL.x:
				z.take_damage(damage * 0.35, &"lob")
	battle.fx_hit(position, color)
	battle.fx_crumbs(position, color)
	deactivate()

func _process(_delta: float) -> void:
	if is_fire and active:
		queue_redraw()

func _draw() -> void:
	if is_fire:
		var f := int(Time.get_ticks_msec() / 70) % 6
		draw_texture_rect_region(FxSheet.sheet(&"flame"), Rect2(Vector2(-30, -20), Vector2(28, 40)), FxSheet.frame_rect(&"flame", f), Color(1, 1, 1, 0.8))
		DrawUtil.circle(self, Vector2.ZERO, 13, color, 3)
		draw_circle(Vector2(-3, -4), 6, Color(1.0, 0.9, 0.5))
		return
	if kind == &"lob":
		DrawUtil.circle(self, Vector2.ZERO, 17, color, 3)
		draw_circle(Vector2(-5, -5), 6, color.lightened(0.4))
		draw_line(Vector2(-6, 6), Vector2(6, 2), color.darkened(0.4), 3)
		return
	if garlic:
		DrawUtil.circle(self, Vector2.ZERO, 11, Color(0.97, 0.95, 0.86), 3)
		draw_line(Vector2(0, -11), Vector2(0, 11), Color(0.8, 0.75, 0.6), 2)
		return
	if kind == &"low":
		DrawUtil.ellipse(self, Vector2.ZERO, 13, 8, color, 3)
		draw_circle(Vector2(-4, -2), 3, color.lightened(0.5))
		return
	if needle:
		DrawUtil.poly(self, PackedVector2Array([Vector2(-16, -5), Vector2(14, 0), Vector2(-16, 5)]), color, 2.5)
	else:
		DrawUtil.circle(self, Vector2.ZERO, 12, color, 3)
		draw_circle(Vector2(-4, -4), 4, color.lightened(0.5))
