class_name PlantChrono
extends Plant
## Chrono Clover (legendary): every pulse slows every zombie on the lawn and
## shaves seconds off all seed recharges.

var _cd: float = 6.0
var _ring: float = 0.0

func tick(delta: float) -> void:
	_ring = maxf(0.0, _ring - delta)
	_cd -= delta * tempo()
	if _cd > 0.0:
		return
	_cd = data.attack_interval
	trigger_action(&"action_heavy", _pulse)

func _pulse() -> void:
	if dead:
		return
	_ring = 1.0
	for r: int in Board.ROWS:
		for z: Zombie in battle.zombies_in_row(r).duplicate():
			if z.is_targetable():
				z.apply_slow(data.slow_factor, data.slow_duration * stat_mult())
				if data.damage > 0:
					z.take_damage(dmg(data.damage), &"freeze")
	for s: SeedState in battle.seeds:
		s.cooldown = maxf(0.0, s.cooldown - data.stun_time * stat_mult())
	battle.fx_sparkles(position + Vector2(0, -90), 8)
	Sfx.play(&"freeze", -4.0)

func draw_rig_extras(_world: Dictionary) -> void:
	if _ring <= 0.0:
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var r := (1.0 - _ring) * 420.0 + 40.0
	draw_arc(Vector2(0, -60), r, 0, TAU, 64, Color(0.55, 1.0, 0.75, _ring * 0.7), 8.0 * _ring + 1.0)
	draw_arc(Vector2(0, -60), r * 0.7, 0, TAU, 48, Color(0.9, 1.0, 0.6, _ring * 0.4), 4.0)
