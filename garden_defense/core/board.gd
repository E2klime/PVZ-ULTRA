class_name Board
extends Node2D
## Lawn grid: geometry, plant occupancy and lane queries.

const ROWS := 5
const COLS := 9
const CELL := Vector2(130, 140)
const ORIGIN := Vector2(310, 200)
const HOUSE_X := 70.0
const SPAWN_X := 1560.0

var plants: Array = []   # ROWS*COLS, Plant or null (main layer)
## Extra cell layers: under (beneath the main plant), shell (worn on top), air (flying).
const LAYERS: Array[StringName] = [&"under", &"main", &"shell", &"air"]
var layer_plants: Dictionary = {}
## Region of the backdrop that holds its painted playfield (normalized), stretched over the grid.
var ground_src: Rect2 = Rect2(0.2, 0.21, 0.53, 0.76)
var surfaces: Array[StringName] = []
var hover_cell := Vector2i(-1, -1)
var hover_ok := true
var mower_skin := Color(0.85, 0.2, 0.2)
## Battle backdrop (house, hedges, street). The playfield itself is drawn
## on top of it from modular painted tiles, so any water layout works.
var backdrop: Texture2D
## true where the cell is pool water (row-major ROWS*COLS).
var water: PackedByteArray = PackedByteArray()

const LAWN_DIR := "res://assets/tiles/lawn/"
const POOL_DIR := "res://assets/tiles/pool/"
var _lawn_light: Array[Texture2D] = []
var _lawn_dark: Array[Texture2D] = []
var _edge_h: Texture2D
var _edge_v: Texture2D
var _corner_out: Texture2D
var _corner_in: Texture2D
var _water_layer: WaterLayer
var _edge_layer: EdgeLayer
var _hover_layer: HoverLayer

func _init() -> void:
	plants.resize(ROWS * COLS)
	for l: StringName in [&"under", &"shell", &"air"]:
		var a: Array = []
		a.resize(ROWS * COLS)
		layer_plants[l] = a
	surfaces.resize(ROWS * COLS)
	surfaces.fill(&"grass")
	water.resize(ROWS * COLS)
	water.fill(0)

func _ready() -> void:
	for i: int in 4:
		_lawn_light.append(load(LAWN_DIR + "cell_light_%d.png" % i) as Texture2D)
		_lawn_dark.append(load(LAWN_DIR + "cell_dark_%d.png" % i) as Texture2D)
	_edge_h = load(POOL_DIR + "coping_edge.png")
	_edge_v = load(POOL_DIR + "coping_edge_v.png")
	_corner_out = load(POOL_DIR + "coping_corner_outer.png")
	_corner_in = load(POOL_DIR + "coping_corner_inner.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_water_layer = WaterLayer.new()
	_water_layer.board = self
	add_child(_water_layer)
	_edge_layer = EdgeLayer.new()
	_edge_layer.board = self
	add_child(_edge_layer)
	_hover_layer = HoverLayer.new()
	_hover_layer.board = self
	add_child(_hover_layer)

## Water layout: ROWS strings of COLS chars, '~' (or 'w') = water, anything else = lawn.
## Shapes are free-form (kidney pools, islands, diagonal channels...).
func set_layout(rows: PackedStringArray) -> void:
	water.fill(0)
	surfaces.fill(&"grass")
	for r: int in mini(rows.size(), ROWS):
		var line := rows[r]
		for c: int in mini(line.length(), COLS):
			var ch := line[c]
			if ch == "~" or ch == "w":
				water[r * COLS + c] = 1
				surfaces[r * COLS + c] = &"water"
	queue_redraw()
	if _water_layer:
		_water_layer.queue_redraw()
		_edge_layer.queue_redraw()

func is_water(row: int, col: int) -> bool:
	if not in_bounds(row, col):
		return false
	return water[row * COLS + col] == 1

func has_water() -> bool:
	return water.has(1)

## Water at a world x in a lane (used by zombies to swim).
func water_at(row: int, x: float) -> bool:
	return is_water(row, x_to_col(x))

static func board_rect() -> Rect2:
	return Rect2(ORIGIN, CELL * Vector2(COLS, ROWS))

static func cell_center(row: int, col: int) -> Vector2:
	return ORIGIN + CELL * Vector2(col + 0.5, row + 0.5)

## Plants and zombies are drawn from their "feet".
static func cell_feet(row: int, col: int) -> Vector2:
	return cell_center(row, col) + Vector2(0, CELL.y * 0.32)

static func row_feet_y(row: int) -> float:
	return cell_feet(row, 0).y

static func pos_to_cell(p: Vector2) -> Vector2i:
	var local := p - ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var c := int(local.x / CELL.x)
	var r := int(local.y / CELL.y)
	if c >= COLS or r >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(c, r)

## Adjacent lane for splits/throws: below, or above from the bottom lane. Never wraps.
static func neighbor_row(r: int) -> int:
	return r + 1 if r + 1 < ROWS else r - 1

static func x_to_col(x: float) -> int:
	return int(floor((x - ORIGIN.x) / CELL.x))

func in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < ROWS and col >= 0 and col < COLS

func get_plant(row: int, col: int) -> Plant:
	return get_layer(row, col, &"main")

func get_layer(row: int, col: int, layer: StringName) -> Plant:
	if not in_bounds(row, col):
		return null
	var arr: Array = plants if layer == &"main" else layer_plants.get(layer, [])
	if arr.is_empty():
		return null
	var p: Variant = arr[row * COLS + col]
	if p == null or not is_instance_valid(p):
		return null
	return p as Plant

func set_plant(row: int, col: int, p: Plant) -> void:
	set_layer(row, col, p.data.layer if p and p.data else &"main", p)

func set_layer(row: int, col: int, layer: StringName, p: Plant) -> void:
	if not in_bounds(row, col):
		return
	var arr: Array = plants if layer == &"main" else layer_plants[layer]
	arr[row * COLS + col] = p

func clear_plant(p: Plant) -> void:
	for i: int in plants.size():
		if plants[i] == p:
			plants[i] = null
	for l: StringName in layer_plants:
		var arr: Array = layer_plants[l]
		for i: int in arr.size():
			if arr[i] == p:
				arr[i] = null

## Every living plant in a cell, bottom to top.
func cell_plants(row: int, col: int) -> Array[Plant]:
	var out: Array[Plant] = []
	for l: StringName in LAYERS:
		var p := get_layer(row, col, l)
		if p:
			out.append(p)
	return out

func cell_empty(row: int, col: int) -> bool:
	return cell_plants(row, col).is_empty()

func surface(row: int, col: int) -> StringName:
	return surfaces[row * COLS + col]

func all_plants() -> Array[Plant]:
	var out: Array[Plant] = []
	for p: Variant in plants:
		if p != null and is_instance_valid(p):
			out.append(p as Plant)
	for l: StringName in layer_plants:
		for p: Variant in layer_plants[l]:
			if p != null and is_instance_valid(p):
				out.append(p as Plant)
	return out

func air_plants_in_row(row: int) -> Array[Plant]:
	var out: Array[Plant] = []
	for c: int in COLS:
		var p := get_layer(row, c, &"air")
		if p and not p.dead:
			out.append(p)
	return out

## Plant that blocks a zombie at x moving in dir (-1 = towards the house).
func blocking_plant(row: int, x: float, dir: float) -> Plant:
	var probe := x + dir * 28.0
	var col := x_to_col(probe)
	var p: Plant = null
	for l: StringName in [&"shell", &"main", &"under"]:
		var q := get_layer(row, col, l)
		if q and q.blocks_zombies():
			p = q
			break
	if p == null:
		return null
	var cx := cell_center(row, col).x
	# Only start eating once actually touching the plant body.
	if absf(probe - cx) < CELL.x * 0.45:
		return p
	return null

## Flying plant in the way of a balloon zombie.
func air_blocking_plant(row: int, x: float, dir: float) -> Plant:
	var probe := x + dir * 28.0
	var col := x_to_col(probe)
	var p := get_layer(row, col, &"air")
	if p == null or p.dead:
		return null
	if absf(probe - cell_center(row, col).x) < CELL.x * 0.45:
		return p
	return null

func set_hover(cell: Vector2i, ok: bool) -> void:
	if cell != hover_cell or ok != hover_ok:
		hover_cell = cell
		hover_ok = ok
		if _hover_layer:
			_hover_layer.queue_redraw()

func _draw() -> void:
	if backdrop:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, Vector2(1920, 1080)), false)
	else:
		draw_rect(Rect2(Vector2(-200, -200), Vector2(2400, 1500)), Color(0.3, 0.42, 0.24))
	var br := board_rect()
	# soft contact shadow so the playfield sits in the backdrop
	for i: int in 8:
		var g := float(8 - i) * 3.0
		draw_rect(br.grow(g), Color(0.0, 0.0, 0.0, 0.07), true)
	if backdrop:
		# the backdrop's own painted ground, stretched over the grid
		var ts := backdrop.get_size()
		var src := Rect2(ground_src.position * ts, ground_src.size * ts)
		draw_texture_rect_region(backdrop, br, src)
	else:
		for r: int in ROWS:
			for c: int in COLS:
				var h := (r * 7 + c * 13 + (r * c) % 5) % 4
				var tex: Texture2D = _lawn_light[h] if (r + c) % 2 == 0 else _lawn_dark[h]
				draw_texture_rect(tex, Rect2(ORIGIN + CELL * Vector2(c, r), CELL), false)
	# PvZ-style checkerboard so every tile reads clearly
	for r: int in ROWS:
		for c: int in COLS:
			if is_water(r, c):
				continue
			var cell := Rect2(ORIGIN + CELL * Vector2(c, r), CELL)
			if (r + c) % 2 == 0:
				draw_rect(cell, Color(1, 1, 0.85, 0.09))
			else:
				draw_rect(cell, Color(0.0, 0.08, 0.0, 0.1))
	# inner vignette at the borders
	for i: int in 8:
		var a := 0.1 * (1.0 - i / 8.0)
		draw_rect(Rect2(br.position + Vector2(0, i * 3.0), Vector2(br.size.x, 3.0)), Color(0.02, 0.05, 0.0, a))
		draw_rect(Rect2(br.position + Vector2(0, br.size.y - (i + 1) * 3.0), Vector2(br.size.x, 3.0)), Color(0.02, 0.05, 0.0, a))
		draw_rect(Rect2(br.position + Vector2(i * 3.0, 0), Vector2(3.0, br.size.y)), Color(0.02, 0.05, 0.0, a))
		draw_rect(Rect2(br.position + Vector2(br.size.x - (i + 1) * 3.0, 0), Vector2(3.0, br.size.y)), Color(0.02, 0.05, 0.0, a))
	draw_rect(br.grow(2), Color(0.12, 0.09, 0.05, 0.55), false, 4.0)


## Animated pool water, drawn only on water cells (world-space UVs).
class WaterLayer:
	extends Node2D
	var board: Board
	func _ready() -> void:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/water.gdshader")
		m.set_shader_parameter("water_tex", load(POOL_DIR + "water.png"))
		m.set_shader_parameter("caustics_tex", load(POOL_DIR + "caustics.png"))
		material = m
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	func _draw() -> void:
		for r: int in ROWS:
			for c: int in COLS:
				if board.is_water(r, c):
					draw_rect(Rect2(ORIGIN + CELL * Vector2(c, r), CELL), Color.WHITE)


## Modular pool coping: straight edges wherever a water cell meets land (the
## board border counts as land), outer corners where two edges meet and inner
## (concave) corners where only the diagonal neighbour is land.
class EdgeLayer:
	extends Node2D
	var board: Board
	func _land(r: int, c: int) -> bool:
		return not board.is_water(r, c)
	func _piece(tex: Texture2D, cell_pos: Vector2, corner: Vector2, angle: float) -> void:
		draw_set_transform(cell_pos + corner, angle, Vector2(0.5, 0.5))
		draw_texture(tex, Vector2.ZERO)
	func _draw() -> void:
		var W := CELL.x
		var H := CELL.y
		var tl := Vector2.ZERO
		var tr := Vector2(W, 0)
		var brc := Vector2(W, H)
		var bl := Vector2(0, H)
		var cells: Array[Vector2i] = []
		for r: int in ROWS:
			for c: int in COLS:
				if board.is_water(r, c):
					cells.append(Vector2i(c, r))
		# pass 1: straight edges (with their baked shadow on the water)
		for cell: Vector2i in cells:
			var p := ORIGIN + CELL * Vector2(cell)
			var r := cell.y
			var c := cell.x
			if _land(r - 1, c):
				_piece(board._edge_h, p, tl, 0.0)
			if _land(r + 1, c):
				_piece(board._edge_h, p, brc, PI)
			if _land(r, c - 1):
				_piece(board._edge_v, p, bl, -PI * 0.5)
			if _land(r, c + 1):
				_piece(board._edge_v, p, tr, PI * 0.5)
		# pass 2: corners
		for cell: Vector2i in cells:
			var p := ORIGIN + CELL * Vector2(cell)
			var r := cell.y
			var c := cell.x
			var n := _land(r - 1, c)
			var s := _land(r + 1, c)
			var w := _land(r, c - 1)
			var e := _land(r, c + 1)
			if n and w:
				_piece(board._corner_out, p, tl, 0.0)
			elif not n and not w and _land(r - 1, c - 1):
				_piece(board._corner_in, p, tl, 0.0)
			if n and e:
				_piece(board._corner_out, p, tr, PI * 0.5)
			elif not n and not e and _land(r - 1, c + 1):
				_piece(board._corner_in, p, tr, PI * 0.5)
			if s and e:
				_piece(board._corner_out, p, brc, PI)
			elif not s and not e and _land(r + 1, c + 1):
				_piece(board._corner_in, p, brc, PI)
			if s and w:
				_piece(board._corner_out, p, bl, -PI * 0.5)
			elif not s and not w and _land(r + 1, c - 1):
				_piece(board._corner_in, p, bl, -PI * 0.5)
		draw_set_transform_matrix(Transform2D.IDENTITY)


class HoverLayer:
	extends Node2D
	var board: Board
	func _draw() -> void:
		var hc_cell := board.hover_cell
		if hc_cell.x < 0:
			return
		var hr := Rect2(ORIGIN + CELL * Vector2(hc_cell), CELL)
		var hc := Color(1, 1, 1, 0.2) if board.hover_ok else Color(1, 0.15, 0.1, 0.32)
		draw_rect(hr.grow(-3), hc)
		draw_rect(hr.grow(-3), Color(hc.r, hc.g, hc.b, 0.85), false, 3.0)
		# Colour-blind hint: a cross on cells where the action is not possible.
		if not board.hover_ok and bool(Settings.get_value(&"colorblind_hints")):
			var c := hr.get_center()
			var k := minf(hr.size.x, hr.size.y) * 0.22
			for d: Vector2 in [Vector2(k, k), Vector2(k, -k)]:
				draw_line(c - d, c + d, Color(0, 0, 0, 0.7), 10.0)
				draw_line(c - d, c + d, Color(1, 1, 1, 0.9), 5.0)
