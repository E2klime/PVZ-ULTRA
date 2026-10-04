class_name PlantInstant
extends Plant
## Ember Berry: swells for a moment, then explodes in a 3x3 area.

const FUSE := 0.9

func idle_clip() -> StringName:
	return &"idle_legend" if is_legendary() else &"idle_ground"

func blocks_zombies() -> bool:
	return false

func tick(_delta: float) -> void:
	if age >= FUSE:
		var center := position + Vector2(0, -40)
		battle.damage_area(row, position.x, data.aoe_radius, dmg(data.damage), &"explosion")
		battle.fx_explosion(center, data.aoe_radius * Board.CELL.x, Color(1.0, 0.45, 0.1))
		battle.shake(18.0)
		battle.hit_stop(0.07)
		die(true)

func rig_local(n: StringName) -> Transform2D:
	if n == &"body":
		var k := 0.0 if preview else clampf(age / FUSE, 0.0, 1.0)
		var s := 1.0 + k * 0.42 + sin(age * 40.0) * 0.03 * k
		return Transform2D(sin(_phase * 3.0) * 0.03, Vector2(s, s), 0.0, Vector2.ZERO)
	return super.rig_local(n)

func rig_modulate(_n: StringName) -> Color:
	var k := 0.0 if preview else clampf(age / FUSE, 0.0, 1.0)
	return Color(1.0 + k * 0.6, 1.0 - k * 0.2, 1.0 - k * 0.3)
