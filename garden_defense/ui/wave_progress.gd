class_name WaveProgress
extends Control
## PvZ2-style level progress: green fill right-to-left, flags for huge waves and a
## zombie head riding the front.

var director: WaveDirector
var _head: Texture2D = preload("res://assets/ui/zombie_head.png")
var _flag: Texture2D = preload("res://assets/ui/flag.png")

func _init() -> void:
	custom_minimum_size = Vector2(360, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if director == null:
		return
	var r := Rect2(Vector2(8, 14), Vector2(size.x - 16, 20))
	DrawUtil.rrect(self, r.grow(3), Color(0.12, 0.08, 0.04), 12, 0)
	DrawUtil.rrect(self, r, Color(0.32, 0.26, 0.18), 10, 0)
	var p := clampf(director.progress(), 0.0, 1.0)
	if p > 0.0:
		var w := r.size.x * p
		var fill := Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y))
		DrawUtil.rrect(self, fill, Color(0.42, 0.78, 0.25), 10, 0)
		draw_rect(Rect2(fill.position + Vector2(4, 2), Vector2(maxf(0.0, fill.size.x - 8), 5)), Color(1, 1, 1, 0.25))
	var total := director.total_waves()
	for n: int in range(1, total + 1):
		if director.is_flag_wave(n):
			var x := r.end.x - r.size.x * float(n) / float(total)
			var raised := n <= director.wave
			draw_texture_rect(_flag, Rect2(Vector2(x - 6, -2 if raised else 6), Vector2(27, 36)), false, Color.WHITE if raised else Color(0.75, 0.7, 0.65))
	var head_x := r.end.x - r.size.x * p
	draw_texture_rect(_head, Rect2(Vector2(head_x - 20, 4), Vector2(40, 40)), false)
