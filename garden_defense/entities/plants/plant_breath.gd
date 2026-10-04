class_name PlantBreath
extends Plant
## Sky Dragon Fruit (legendary, flying): breathes a fire cone down its lane,
## burning every zombie in range - including balloon and boxed ones.

var _cd: float = 1.0
var _breath: float = 0.0

func tick(delta: float) -> void:
	_breath = maxf(0.0, _breath - delta)
	_cd -= delta * tempo()
	if _cd > 0.0:
		return
	var reach := data.attack_range * Board.CELL.x
	var any := false
	for z: Zombie in battle.zombies_in_row(row):
		if z.is_targetable() and z.position.x > position.x - 30.0 and z.position.x - position.x < reach:
			any = true
			break
	if not any:
		_cd = 0.2
		return
	_cd = data.attack_interval
	trigger_action(&"action_heavy", _breathe)

func _breathe() -> void:
	if dead:
		return
	_breath = 0.6
	var reach := data.attack_range * Board.CELL.x
	for z: Zombie in battle.zombies_in_row(row).duplicate():
		if z.is_targetable() and z.position.x > position.x - 30.0 and z.position.x - position.x < reach:
			z.take_damage(dmg(data.damage), &"burn")
			if data.burn_dps > 0.0:
				z.burn(data.burn_dps * stat_mult(), data.burn_time)
	Sfx.play(&"explode", -8.0)
	var steps := int(data.attack_range * 2.0)
	for i: int in steps:
		battle.fx_hit(position + Vector2(60 + i * Board.CELL.x * 0.5, -hover_height() * (1.0 - float(i) / steps) - 20.0), Color(1.0, 0.55 - i * 0.03, 0.1))

func draw_rig_extras(world: Dictionary) -> void:
	if _breath <= 0.0:
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var a := _breath / 0.6
	var start := Vector2(48, -hover_height() - 60)
	var len := data.attack_range * Board.CELL.x * (1.0 - a * 0.3)
	var pts := PackedVector2Array([start, start + Vector2(len, hover_height() + 20.0), start + Vector2(len, hover_height() + 70.0)])
	draw_colored_polygon(pts, Color(1.0, 0.5, 0.1, 0.35 * a))
	pts = PackedVector2Array([start, start + Vector2(len * 0.7, hover_height() + 30.0), start + Vector2(len * 0.7, hover_height() + 55.0)])
	draw_colored_polygon(pts, Color(1.0, 0.9, 0.3, 0.45 * a))
