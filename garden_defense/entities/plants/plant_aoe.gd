class_name PlantAoe
extends Plant
## Dandelion Puff: cheap short-range damage to every zombie around it.

var _cd: float = 1.0

func tick(delta: float) -> void:
	_cd -= delta
	if _cd > 0.0:
		return
	var center := position + Vector2(0, -40)
	var radius := data.aoe_radius * Board.CELL.x
	var hits := battle.zombies_in_circle(center, radius)
	if hits.is_empty():
		_cd = 0.15
		return
	_cd = data.attack_interval / tempo()
	trigger_action(&"action")
	for z: Zombie in hits:
		z.take_damage(dmg(data.damage), &"aoe")
		if z.is_alive() and data.burn_dps > 0.0: z.burn(data.burn_dps, data.burn_time)
		if z.is_alive() and data.slow_duration > 0.0: z.apply_slow(data.slow_factor, data.slow_duration)
	battle.fx_puff(center, radius)

func rig_local(n: StringName) -> Transform2D:
	if n == &"head":
		var s := 1.0 - anim_t * 0.22 + sin(_phase * 1.3) * 0.02
		return Transform2D(sin(_phase - 0.7) * 0.06, Vector2(s, s), 0.0, Vector2.ZERO)
	return super.rig_local(n)
