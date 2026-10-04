class_name PoolCopingLayer
extends Node2D
## Modular pool coping: straight edges wherever a water cell meets land (the
## board border counts as land), outer corners where two edges meet and inner
## (concave) corners where only the diagonal neighbour is land.
var board: Board
var _edge_h: Texture2D = load(Board.POOL_DIR + "coping_edge.png")
var _edge_v: Texture2D = load(Board.POOL_DIR + "coping_edge_v.png")
var _corner_out: Texture2D = load(Board.POOL_DIR + "coping_corner_outer.png")
var _corner_in: Texture2D = load(Board.POOL_DIR + "coping_corner_inner.png")
func _land(r: int, c: int) -> bool:
	return not board.is_water(r, c)
func _piece(tex: Texture2D, cell_pos: Vector2, corner: Vector2, angle: float) -> void:
	draw_set_transform(cell_pos + corner, angle, Vector2(0.5, 0.5))
	draw_texture(tex, Vector2.ZERO)
func _draw() -> void:
	var W := Board.CELL.x
	var H := Board.CELL.y
	var tl := Vector2.ZERO
	var tr := Vector2(W, 0)
	var brc := Vector2(W, H)
	var bl := Vector2(0, H)
	var cells: Array[Vector2i] = []
	for r: int in Board.ROWS:
		for c: int in Board.COLS:
			if board.is_water(r, c):
				cells.append(Vector2i(c, r))
	# pass 1: straight edges (with their baked shadow on the water)
	for cell: Vector2i in cells:
		var p := Board.ORIGIN + Board.CELL * Vector2(cell)
		var r := cell.y
		var c := cell.x
		if _land(r - 1, c):
			_piece(_edge_h, p, tl, 0.0)
		if _land(r + 1, c):
			_piece(_edge_h, p, brc, PI)
		if _land(r, c - 1):
			_piece(_edge_v, p, bl, -PI * 0.5)
		if _land(r, c + 1):
			_piece(_edge_v, p, tr, PI * 0.5)
	# pass 2: corners
	for cell: Vector2i in cells:
		var p := Board.ORIGIN + Board.CELL * Vector2(cell)
		var r := cell.y
		var c := cell.x
		var n := _land(r - 1, c)
		var s := _land(r + 1, c)
		var w := _land(r, c - 1)
		var e := _land(r, c + 1)
		if n and w:
			_piece(_corner_out, p, tl, 0.0)
		elif not n and not w and _land(r - 1, c - 1):
			_piece(_corner_in, p, tl, 0.0)
		if n and e:
			_piece(_corner_out, p, tr, PI * 0.5)
		elif not n and not e and _land(r - 1, c + 1):
			_piece(_corner_in, p, tr, PI * 0.5)
		if s and e:
			_piece(_corner_out, p, brc, PI)
		elif not s and not e and _land(r + 1, c + 1):
			_piece(_corner_in, p, brc, PI)
		if s and w:
			_piece(_corner_out, p, bl, -PI * 0.5)
		elif not s and not w and _land(r + 1, c - 1):
			_piece(_corner_in, p, bl, -PI * 0.5)
	draw_set_transform_matrix(Transform2D.IDENTITY)
