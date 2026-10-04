class_name FxRing
extends Node2D
## Expanding ring + flash used for explosions and grafts.

var radius: float = 100.0
var color: Color = Color(1, 0.6, 0.2)
var duration: float = 0.45
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := _t / duration
	var r := radius * (0.3 + 0.7 * k)
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.35 * (1.0 - k)))
	draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(color.r, color.g, color.b, 1.0 - k), 8.0 * (1.0 - k) + 2.0)
