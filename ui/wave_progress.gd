class_name WaveProgress
extends Control
## Level progress: green fill right-to-left, flags for huge waves and a
## zombie head riding the front.

var director: WaveDirector
var _head: Texture2D = preload("res://assets/ui/zombie_head.png")
var _flag: Texture2D = preload("res://assets/ui/flag.png")
var _bg: StyleBox = UITheme.kit("bar_bg")
var _fill: StyleBox = UITheme.kit("bar_fill")

func _init() -> void:
	custom_minimum_size = Vector2(360, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if director == null:
		return
	var r := Rect2(Vector2(8, 14), Vector2(size.x - 16, 20))
	draw_style_box(_bg, r.grow(4))
	var p := clampf(director.progress(), 0.0, 1.0)
	if p > 0.0:
		var w := r.size.x * p
		var fill := Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y))
		if fill.size.x < r.size.y:
			fill = Rect2(Vector2(r.end.x - r.size.y, r.position.y), Vector2(r.size.y, r.size.y))
		draw_style_box(_fill, fill.grow(1))
	var total := director.total_waves()
	for n: int in range(1, total + 1):
		if director.is_flag_wave(n):
			var x := r.end.x - r.size.x * float(n) / float(total)
			var raised := n <= director.wave
			draw_texture_rect(_flag, Rect2(Vector2(x - 6, -2 if raised else 6), Vector2(27, 36)), false, Color.WHITE if raised else Color(0.75, 0.7, 0.65))
	var head_x := r.end.x - r.size.x * p
	draw_texture_rect(_head, Rect2(Vector2(head_x - 20, 4), Vector2(40, 40)), false)
