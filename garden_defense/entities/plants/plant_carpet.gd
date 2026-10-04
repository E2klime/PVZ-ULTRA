class_name PlantCarpet
extends Plant
## Under-layer ground plants: Thorn Carpet (spikes every zombie walking over it,
## including boxed ones; never eaten) and Thunder Root (legendary: a root bolt
## chains along the lane under every ground zombie it reaches).

var _cd: float = 0.5

func blocks_zombies() -> bool:
	return false

func sway_amount() -> float:
	return 0.15

func tick(delta: float) -> void:
	_cd -= delta * tempo()
	if _cd > 0.0:
		return
	_cd = data.attack_interval
	if data.chain_count > 0:
		_root_bolt()
		return
	var hit := false
	var cx := position.x
	for z: Zombie in battle.zombies_in_row(row).duplicate():
		if z.is_targetable() and not z.is_flying() and absf(z.hit_center_x() - cx) < Board.CELL.x * (0.55 + data.aoe_radius):
			z.take_damage(dmg(data.damage), &"thorns")
			if data.slow_duration > 0.0:
				z.apply_slow(data.slow_factor, data.slow_duration)
			hit = true
	if hit:
		anim_t = 1.0
		battle.fx_crumbs(position + Vector2(0, -6), data.color_accent)

func _root_bolt() -> void:
	var reach := data.attack_range * Board.CELL.x if data.attack_range > 0.0 else 2000.0
	var targets: Array[Zombie] = []
	for z: Zombie in battle.zombies_in_row(row):
		if z.is_targetable() and not z.is_flying() and z.position.x > position.x - 40.0 and z.position.x - position.x < reach:
			targets.append(z)
	if targets.is_empty():
		_cd = 0.25
		return
	targets.sort_custom(func(a: Zombie, b: Zombie) -> bool: return a.position.x < b.position.x)
	var from := position + Vector2(0, -10)
	var n := 0
	for z: Zombie in targets:
		if n > data.chain_count:
			break
		z.take_damage(dmg(data.damage), &"chain")
		if data.stun_time > 0.0:
			z.stun(data.stun_time)
		battle.fx_bolt(from, z.position + Vector2(0, -40))
		from = z.position + Vector2(0, -40)
		n += 1
	anim_t = 1.0
	Sfx.play(&"zap")
