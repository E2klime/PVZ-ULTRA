class_name PlantAura
extends Plant
## Turbo Bean (flying): speeds up plants around it (speed_aura, applied by
## Battle._recompute_buffs). Bean Patriarch also drops sun now and then.

var _t: float = 6.0

func tick(delta: float) -> void:
	if data.sun_amount <= 0:
		return
	_t -= delta * stat_mult()
	if _t <= 0.0:
		_t = data.sun_interval
		trigger_action(&"produce", func() -> void:
			if not dead:
				battle.spawn_sun(position + Vector2(0, -90 - hover_height()), data.sun_amount, false))

func draw_rig_extras(_world: Dictionary) -> void:
	if preview or data.speed_aura <= 1.0:
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var t := fmod(age * 0.8 + _phase * 0.1, 1.0)
	var c := Color(1.0, 0.85, 0.25, 0.35 * (1.0 - t))
	var y := -hover_height() * 0.0 + 2.0
	if data.aura_radius >= 9:
		draw_line(Vector2(-60 - t * 200.0, y), Vector2(60 + t * 200.0, y), c, 4.0)
	else:
		var hw := Board.CELL.x * (0.5 + t)
		var hh := Board.CELL.y * (0.25 + t * 0.5) * 0.5
		draw_colored_polygon(DrawUtil.ellipse_points(Vector2(0, y), hw, hh), Color(c.r, c.g, c.b, c.a * 0.25))
		draw_arc(Vector2(0, y), hw, 0, TAU, 32, c, 2.0)
