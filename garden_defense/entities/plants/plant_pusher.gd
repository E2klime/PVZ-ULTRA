class_name PlantPusher
extends Plant
## Gale Fern: periodically blows zombies in its lane back.

var _cd: float = 2.0

func sway_amount() -> float:
	return 2.5 + anim_t * 6.0

func tick(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var max_x := position.x + data.attack_range * Board.CELL.x
	if battle.first_target_in_lane(row, position.x - 10.0, max_x, &"wind") == null:
		_cd = 0.2
		return
	_cd = data.attack_interval / tempo()
	trigger_action(&"action_heavy")
	for z: Zombie in battle.zombies_in_row(row).duplicate():
		if z.is_targetable() and z.position.x > position.x - 10.0 and z.position.x < max_x:
			if z.is_flying():
				# a gust sends balloons drifting off the lawn for good
				z.blow_away()
				continue
			z.take_damage(dmg(data.damage), &"wind")
			z.push(data.push_distance)
			z.stun(0.35)
	battle.fx_gust(row, position.x, max_x)

func rig_local(n: StringName) -> Transform2D:
	if n == &"body":
		var sw := sin(_phase * 2.0) * (0.03 + anim_t * 0.12)
		return Transform2D(sw, Vector2(1.0 + anim_t * 0.08, 1.0 - anim_t * 0.05), 0.0, Vector2.ZERO)
	return super.rig_local(n)
