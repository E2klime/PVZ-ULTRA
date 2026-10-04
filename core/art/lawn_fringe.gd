class_name LawnFringe
extends Node2D
## Short grass blades rooted just in front of one lane's feet line. Lives in the
## y-sorted entity layer slightly below the feet, so that lane's plants and zombies
## stand IN the grass. Blades are drawn only where something stands (a plant's
## cell, a walking zombie's feet), so empty lawn never shows an extra line.

var config: WorldArtConfig
var board: Board
var entities: Node2D
var row: int

const SORT_BIAS := 3.0
const TUFT_W := 112.0

func _init(p_config: WorldArtConfig, p_board: Board, p_entities: Node2D, p_row: int) -> void:
	config = p_config
	board = p_board
	entities = p_entities
	row = p_row
	position = Vector2(0, Board.row_feet_y(row) + SORT_BIAS)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if config == null or row >= config.fringe.size() or config.fringe[row] == null:
		return
	var tex := config.fringe[row]
	var top := config.fringe_offset_y - SORT_BIAS
	var h := tex.get_size().y
	for c: int in Board.COLS:
		if not _grounded_plant(c):
			continue
		var x := Board.CELL.x * c
		draw_texture_rect_region(tex, Rect2(Board.ORIGIN.x + x, top, Board.CELL.x, h), Rect2(x, 0, Board.CELL.x, h))
	if config.tuft == null:
		return
	var br := Board.board_rect()
	for n: Node in entities.get_children():
		var z := n as Zombie
		if z == null or z.row != row or z.data == null or z.underground or z.submerge > 0.1:
			continue
		var zx := z.position.x
		if zx < br.position.x + 20.0 or zx > br.end.x - 20.0 or board.water_at(row, zx):
			continue
		var w := TUFT_W * z.data.body_scale
		draw_texture_rect(config.tuft, Rect2(zx - w * 0.5, top, w, h), false)

func _grounded_plant(c: int) -> bool:
	if board.is_water(row, c) or board.get_layer(row, c, &"under") != null:
		return false
	for l: StringName in [&"main", &"shell"]:
		var p := board.get_layer(row, c, l)
		if p and not p.dead and not p.on_raft:
			return true
	return false
