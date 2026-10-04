class_name PlantDualWall
extends PlantWall
var _sun_timer: float = 10.0
func tick(delta: float) -> void:
	super.tick(delta)
	_sun_timer -= delta
	if _sun_timer <= 0.0:
		_sun_timer = data.sun_interval
		battle.spawn_sun(position + Vector2(0, -70), data.sun_amount, false)
