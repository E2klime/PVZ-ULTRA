class_name MenuAmbience
extends Control
## Calm, lightweight menu animation: drifting leaves and warm pollen motes.

var _t: float = 0.0
var _leaves: Array[Dictionary] = []
var _motes: Array[Dictionary] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.full(self)
	for i: int in 13:
		_leaves.append({
			"x": randf_range(0.0, 1920.0),
			"y": randf_range(-100.0, 1080.0),
			"speed": randf_range(18.0, 42.0),
			"phase": randf() * TAU,
			"size": randf_range(7.0, 14.0),
		})
	for i: int in 22:
		_motes.append({
			"x": randf_range(0.0, 1920.0),
			"y": randf_range(200.0, 980.0),
			"phase": randf() * TAU,
			"size": randf_range(1.5, 3.5),
		})

func _process(delta: float) -> void:
	_t += delta
	for leaf: Dictionary in _leaves:
		leaf["y"] = float(leaf["y"]) + float(leaf["speed"]) * delta
		if float(leaf["y"]) > size.y + 40.0:
			leaf["y"] = -40.0
			leaf["x"] = randf_range(0.0, maxf(1.0, size.x))
	queue_redraw()

func _draw() -> void:
	for mote: Dictionary in _motes:
		var phase := float(mote["phase"])
		var p := Vector2(
			float(mote["x"]) + sin(_t * 0.45 + phase) * 24.0,
			float(mote["y"]) + sin(_t * 0.7 + phase) * 10.0
		)
		var alpha := 0.18 + 0.16 * (sin(_t * 1.3 + phase) * 0.5 + 0.5)
		draw_circle(p, float(mote["size"]), Color(1.0, 0.86, 0.42, alpha))
	for leaf: Dictionary in _leaves:
		var phase := float(leaf["phase"])
		var p := Vector2(
			float(leaf["x"]) + sin(_t * 0.8 + phase) * 34.0,
			float(leaf["y"])
		)
		var s := float(leaf["size"])
		var dir := Vector2.RIGHT.rotated(_t * 0.6 + phase)
		var side := dir.orthogonal() * s * 0.55
		draw_colored_polygon(
			PackedVector2Array([p + dir * s, p + side, p - dir * s, p - side]),
			Color(0.48, 0.7, 0.25, 0.42)
		)