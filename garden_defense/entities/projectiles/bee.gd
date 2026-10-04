class_name Bee
extends Node2D
## Homing bee from Hive Pod. Hits from above, so shields do not block it.

var battle: Battle
var damage: float = 30.0
var speed: float = 320.0
var life: float = 9.0
var done: bool = false
var _target: Zombie
var _vel: Vector2 = Vector2(0, -150)
var _wing: float = 0.0

func setup(b: Battle, pos: Vector2, dmg: float) -> void:
	battle = b
	position = pos
	damage = dmg

func _physics_process(delta: float) -> void:
	if done:
		return
	life -= delta
	_wing += delta * 40.0
	if life <= 0.0:
		_finish()
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_targetable():
		_target = battle.nearest_target(position)
	var goal := position + Vector2(60, -20)
	if _target:
		goal = _target.position + Vector2(0, -90 * _target.data.body_scale)
	var desired := (goal - position).normalized() * speed
	_vel = _vel.lerp(desired, clampf(delta * 4.0, 0.0, 1.0))
	position += _vel * delta
	if _target and position.distance_to(goal) < 26.0:
		_target.take_damage(damage, &"aerial")
		battle.fx_hit(position, Color(1, 0.85, 0.2))
		_finish()
	queue_redraw()

func _finish() -> void:
	done = true
	queue_free()

func _draw() -> void:
	var flap := absf(sin(_wing)) * 8.0
	draw_colored_polygon(DrawUtil.ellipse_points(Vector2(-2, -6), 7, 4 + flap * 0.4), Color(0.9, 0.95, 1.0, 0.8))
	DrawUtil.ellipse(self, Vector2.ZERO, 11, 8, Color(1.0, 0.82, 0.15), 2.5)
	draw_line(Vector2(-3, -7), Vector2(-3, 7), Color(0.15, 0.1, 0.05), 3)
	draw_line(Vector2(4, -7), Vector2(4, 7), Color(0.15, 0.1, 0.05), 3)
