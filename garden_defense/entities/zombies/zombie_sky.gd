class_name ZombieSky
extends Zombie
## Sky threats that hunt flying plants.
## Balloon Zombie: floats over every ground plant; only anti-air shots, flying
##   plants, wind and explosions reach it. Bumps into flying plants and gnaws them.
##   Popping the balloon drops it to the lawn as an ordinary walker.
## Slingshot Zombie: stops when a flying plant is in range and pelts it with stones.

const FLOAT_H := 78.0
var _shot_cd: float = 1.5
var _float: float = 0.0

func on_setup() -> void:
	if profile == &"air":
		_float = FLOAT_H
		hop = _float

func walking() -> bool:
	if profile == &"air":
		return false
	return super.walking()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if preview:
		return
	var want := FLOAT_H if profile == &"air" else 0.0
	if absf(_float - want) > 0.1:
		_float = move_toward(_float, want, 220.0 * delta)
		if _float <= 0.1 and battle:
			battle.fx_dust(position)
	hop = _float + (sin(walk_phase * 0.7) * 5.0 if profile == &"air" else 0.0)

func _walk(delta: float) -> void:
	if profile == &"air":
		var p := battle.board.air_blocking_plant(row, position.x, dir)
		if p:
			target = p
			_bite_t = data.eat_interval * 0.5
			_set_state(State.EAT)
			return
		position.x += dir * base_speed() * Board.CELL.x * speed_mult() * delta
		walk_phase += delta * 3.0
		return
	if data.targets_air:
		var t := _air_target()
		if t:
			walk_phase += delta * 0.5
			_shot_cd -= delta * (slow_factor if slow_t > 0.0 else 1.0)
			if _shot_cd <= 0.0:
				_shot_cd = data.ability_interval
				_sling(t)
			return
	super._walk(delta)

func _eat(delta: float) -> void:
	if profile != &"air":
		super._eat(delta)
		return
	if target == null or not is_instance_valid(target) or target.dead or battle.board.air_blocking_plant(row, position.x, dir) != target:
		target = null
		_set_state(State.WALK)
		return
	walk_phase += delta * 6.0
	_bite_t -= delta
	if _bite_t <= 0.0:
		_bite_t += data.eat_interval
		_bite(target)

## Closest flying plant ahead within range (cells = ability_power / 10).
func _air_target() -> Plant:
	var best: Plant
	var reach := data.ability_power / 10.0 * Board.CELL.x
	for p: Plant in battle.board.air_plants_in_row(row):
		var d := (position.x - p.position.x) * -dir
		if d > -20.0 and d < reach and (best == null or p.position.x > best.position.x):
			best = p
	return best

func _sling(p: Plant) -> void:
	pose_arm = 0.8
	var stone := Stone.new()
	stone.from = position + Vector2(-40, -120) * data.body_scale
	stone.target = p
	stone.damage = data.damage * diff.zombie_dps_mult
	stone.source = self
	battle.fx_layer.add_child(stone)

func rig_back_items(upper: Transform2D, sh: Vector2) -> void:
	super.rig_back_items(upper, sh)
	if data.armor_kind == &"balloon" and armor > 0.0 and rig.has(&"balloon"):
		var sway := sin(walk_phase * 0.9) * 0.06
		_rp(&"balloon", upper * Transform2D(sway, Vector2(18, -150) + sh))

func rig_front_items(upper: Transform2D, sh: Vector2) -> void:
	super.rig_front_items(upper, sh)
	if data.targets_air and rig.has(&"sling") and not lost_arm:
		_rp(&"sling", upper * Transform2D(-0.3 - pose_arm * 0.4, Vector2(-56, -98) + sh))

func _draw() -> void:
	# fallback balloon when no painted part exists
	if data and data.armor_kind == &"balloon" and armor > 0.0 and (rig == null or not rig.has(&"balloon")) and state != State.DIE:
		var s := data.body_scale
		var top := Vector2(10, -300 - hop) * s
		draw_line(Vector2(6, -150 - hop) * s, top + Vector2(0, 50), Color(0.3, 0.25, 0.2), 2.0)
		DrawUtil.circle(self, top, 46 * s, Color(0.92, 0.22, 0.2), 3)
		draw_circle(top + Vector2(-14, -16) * s, 10 * s, Color(1, 0.6, 0.55))
	super._draw()


## A pebble flying in an arc to a flying plant.
class Stone:
	extends Node2D
	var from: Vector2
	var target: Plant
	var damage: float = 50.0
	var source: Zombie
	var _t: float = 0.0
	var _to: Vector2
	func _ready() -> void:
		position = from
		_to = target.position + Vector2(0, -target.hover_height() - 50.0) if is_instance_valid(target) else from + Vector2(-300, 0)
	func _physics_process(delta: float) -> void:
		_t += delta * 2.2
		var t := minf(_t, 1.0)
		position = from.lerp(_to, t) + Vector2(0, -sin(t * PI) * 70.0)
		queue_redraw()
		if t >= 1.0:
			if is_instance_valid(target) and not target.dead:
				target.take_damage(damage, source if is_instance_valid(source) else null)
			queue_free()
	func _draw() -> void:
		DrawUtil.circle(self, Vector2.ZERO, 8, Color(0.55, 0.52, 0.48), 2)
