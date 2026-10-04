class_name PlantStorm
extends Plant
## Storm Thistle (legendary): calls a lightning bolt on the first zombie in its
## lane, which then arcs to up to chain_count more zombies in any lane within
## chain_range cells. Each jump deals 70% of the previous hit and stuns briefly.

var _cd: float = 1.5
var _arc_t: float = 0.0

func tick(delta: float) -> void:
	_cd -= delta
	_arc_t = max(0.0, _arc_t - delta)
	if _cd > 0.0:
		return
	if battle.first_target_in_lane(row, position.x - 20.0, Board.SPAWN_X - 45.0, &"chain") != null:
		_cd = data.attack_interval / tempo()
		trigger_action(&"action_heavy", _strike)
	else:
		_cd = 0.15

func _strike() -> void:
	if dead:
		return
	var first := battle.first_target_in_lane(row, position.x - 20.0, Board.SPAWN_X - 45.0, &"chain")
	if first == null:
		return
	_arc_t = 0.35
	var from := position + muzzle_point()
	var amount := dmg(data.damage)
	var hit: Array[Zombie] = []
	var z: Zombie = first
	while z != null and hit.size() <= data.chain_count:
		var to := z.position + Vector2(-6, -90) * z.data.body_scale
		battle.fx_bolt(from, to)
		z.take_damage(amount, &"lightning")
		z.stun(data.stun_time)
		hit.append(z)
		from = to
		amount *= 0.7
		z = _next_target(to, hit)
	battle.shake(4.0)

func _next_target(from: Vector2, hit: Array[Zombie]) -> Zombie:
	var best: Zombie
	var best_d := data.chain_range * Board.CELL.x
	for zz: Zombie in battle.zombies_in_circle(from, best_d):
		if zz in hit:
			continue
		var d := (zz.position + Vector2(0, -60)).distance_to(from)
		if d < best_d:
			best_d = d
			best = zz
	return best

func draw_rig_extras(world: Dictionary) -> void:
	if not world.has(&"head"):
		return
	var charge := 0.5 + 0.5 * sin(_phase * 3.0)
	var xf: Transform2D = world[&"head"]
	draw_set_transform_matrix(xf)
	var c := Vector2(0, -33)
	var a := 0.12 + 0.1 * charge + _arc_t * 1.2
	draw_circle(c, 46.0, Color(0.55, 0.85, 1.0, a * 0.5))
	if _arc_t > 0.0 or charge > 0.92:
		for i: int in 3:
			var ang := _phase * 5.0 + i * 2.1
			var p0 := c + Vector2.RIGHT.rotated(ang) * 26.0
			var p1 := c + Vector2.RIGHT.rotated(ang + 0.5) * 50.0
			draw_line(p0, p1.lerp(p0, 0.4) + Vector2(4, -6), Color(0.8, 0.95, 1.0, 0.9), 2.0)
			draw_line(p1.lerp(p0, 0.4) + Vector2(4, -6), p1, Color(0.8, 0.95, 1.0, 0.9), 2.0)

func muzzle_point() -> Vector2:
	return rig_point("muzzle", Vector2(8, -112))
