class_name PoolWaterLayer
extends Node2D
## Animated pool water, drawn only on water cells (world-space UVs).
var board: Board
func _ready() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("water_tex", load(Board.POOL_DIR + "water.png"))
	m.set_shader_parameter("caustics_tex", load(Board.POOL_DIR + "caustics.png"))
	material = m
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
func _draw() -> void:
	for r: int in Board.ROWS:
		for c: int in Board.COLS:
			if board.is_water(r, c):
				draw_rect(Rect2(Board.ORIGIN + Board.CELL * Vector2(c, r), Board.CELL), Color.WHITE)
