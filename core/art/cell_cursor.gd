class_name CellCursor
extends Node2D
## Placement cursor: painted ground glow at the plant's feet plus corner marks
## (assets/ui/kit/cell_cursor.png, tools/art/assemble/cell_cursor.py), tinted by validity.

const TEX: Texture2D = preload("res://assets/ui/kit/cell_cursor.png")
const OK_TINT := Color(1.0, 0.95, 0.72, 0.85)
const BAD_TINT := Color(1.0, 0.3, 0.22, 0.9)
var board: Board

func _draw() -> void:
	var hc_cell := board.hover_cell
	if hc_cell.x < 0:
		return
	var hr := Rect2(Board.ORIGIN + Board.CELL * Vector2(hc_cell), Board.CELL)
	draw_texture_rect(TEX, hr, false, OK_TINT if board.hover_ok else BAD_TINT)
	# Colour-blind hint: a cross on cells where the action is not possible.
	if not board.hover_ok and bool(Settings.get_value(&"colorblind_hints")):
		var c := hr.get_center()
		var k := minf(hr.size.x, hr.size.y) * 0.22
		for d: Vector2 in [Vector2(k, k), Vector2(k, -k)]:
			draw_line(c - d, c + d, Color(0, 0, 0, 0.7), 10.0)
			draw_line(c - d, c + d, Color(1, 1, 1, 0.9), 5.0)
