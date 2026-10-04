class_name ScreenBg
extends Control
## Background: a generated static illustration (assets/art/bg) when one is set,
## otherwise a procedural sky gradient with layered hills. Clouds drift on top
## of both for a little life; `dim` darkens the art so UI stays readable.

var sky_top: Color = Color(0.45, 0.72, 0.92)
var sky_bottom: Color = Color(0.85, 0.93, 0.85)
var hill: Color = Color(0.36, 0.62, 0.26)
var _t: float = 0.0
var texture: Texture2D
var dim: float = 0.0

static func with_art(path: String, p_dim: float = 0.0) -> ScreenBg:
	var b := ScreenBg.new()
	b.texture = load(path) as Texture2D
	b.dim = p_dim
	return b

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.full(self)

func _process(d: float) -> void:
	_t += d
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if texture:
		_draw_art(w, h)
		return
	var steps := 12
	for i: int in steps:
		var c := sky_top.lerp(sky_bottom, float(i) / float(steps - 1))
		draw_rect(Rect2(0, h * i / steps, w, h / steps + 1), c)
	# clouds
	for i: int in 4:
		var x := fmod(_t * (12.0 + i * 4.0) + i * 520.0, w + 400.0) - 200.0
		var y := 110.0 + i * 70.0
		for k: int in 3:
			draw_circle(Vector2(x + k * 50.0, y - (k % 2) * 20.0), 42.0, Color(1, 1, 1, 0.7))
	for layer: int in 3:
		var pts := PackedVector2Array()
		var base_y := h * (0.62 + layer * 0.12)
		pts.append(Vector2(0, h))
		for i: int in 33:
			var x := w * i / 32.0
			pts.append(Vector2(x, base_y + sin(i * 0.6 + layer * 1.7) * 40.0))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, hill.darkened(0.12 * layer))

func _draw_art(w: float, h: float) -> void:
	# cover-fit the illustration
	var ts := texture.get_size()
	var k: float = max(w / ts.x, h / ts.y)
	var ds := ts * k
	draw_texture_rect(texture, Rect2((Vector2(w, h) - ds) * 0.5, ds), false)
	# slow drifting cloud shadows
	for i: int in 3:
		var x := fmod(_t * (10.0 + i * 3.0) + i * 700.0, w + 600.0) - 300.0
		var y := 180.0 + i * 260.0
		for j: int in 3:
			draw_circle(Vector2(x + j * 70.0, y + (j % 2) * 24.0), 70.0, Color(0.1, 0.2, 0.1, 0.06))
	if dim > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.1, 0.06, dim))
