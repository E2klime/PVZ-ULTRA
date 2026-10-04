class_name PlantSupport
extends Plant

func idle_clip() -> StringName:
	return &"idle_legend" if is_legendary() else &"idle_float"
## Lantern Bloom: buffs the 8 neighbouring plants (computed by Battle).

func rig_local(n: StringName) -> Transform2D:
	if n == &"head":
		# the lantern hangs from the stem tip and swings like a pendulum
		return Transform2D(sin(_phase * 1.1) * 0.12, Vector2.ZERO)
	return super.rig_local(n)

func draw_rig_extras(world: Dictionary) -> void:
	if not world.has(&"head"):
		return
	var glow := 0.5 + 0.5 * sin(_phase * 1.3)
	draw_set_transform_matrix(world[&"head"])
	draw_circle(Vector2(0, 29), 54 + 6 * glow, Color(1.0, 0.85, 0.35, 0.10 + 0.05 * glow))
