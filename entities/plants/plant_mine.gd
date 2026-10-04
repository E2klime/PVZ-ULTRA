class_name PlantMine
extends Plant
## Thorn Mine / Volcano Mine: arm, then explode on contact (also hits burrowing zombies).

var armed: bool = false

func idle_clip() -> StringName:
	return &"idle_legend" if is_legendary() else &"idle_ground"

## Armed mines let zombies step onto them (and go off).
func blocks_zombies() -> bool:
	return not dead and not armed

func sway_amount() -> float:
	return 0.3

func tick(_delta: float) -> void:
	if not armed:
		if age >= data.arm_time:
			armed = true
			pop()
		return
	var z := battle.zombie_touching(row, position.x, 48.0, true)
	if z:
		_explode()

func _explode() -> void:
	var center := position + Vector2(0, -30)
	battle.damage_area(row, position.x, data.aoe_radius, dmg(data.damage), &"explosion")
	battle.fx_explosion(center, data.aoe_radius * Board.CELL.x, data.color_accent)
	battle.shake(10.0)
	for z: Zombie in battle.zombies_in_circle(center, data.aoe_radius * Board.CELL.x):
		if data.slow_duration > 0.0: z.apply_slow(data.slow_factor, data.slow_duration)
	if data.sun_amount > 0: battle.spawn_sun(center, data.sun_amount, false)
	if data.burn_dps > 0.0:
		battle.spawn_fire_puddle(row, col, data.burn_dps, data.burn_time)
	die(true)

func rig_visible(n: StringName) -> bool:
	match n:
		&"buried":
			return not armed and not preview
		&"body", &"light":
			return armed or preview
		&"lids":
			return (armed or preview) and _blink > 0.0
	return super.rig_visible(n)

func rig_local(n: StringName) -> Transform2D:
	if n == &"buried":
		var prog := clampf(age / maxf(0.01, data.arm_time), 0.0, 1.0)
		var w := sin(_phase * 3.0) * 0.03 * prog
		return Transform2D(0.0, Vector2(1.0 + w, 1.0 - w + prog * 0.08), 0.0, Vector2.ZERO)
	return super.rig_local(n)

func rig_modulate(n: StringName) -> Color:
	if n == &"light":
		var blink := 1.0 if fmod(_phase, 1.6) < 0.8 else 0.35
		return Color(1, 1, 1, blink)
	return Color.WHITE
