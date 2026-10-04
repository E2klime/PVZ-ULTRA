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
var surfaces: Array[StringName] = []
var hover_cell := Vector2i(-1, -1)
var hover_ok := true
var mower_skin := Color(0.85, 0.2, 0.2)
## Ground art lives in core/art (LawnRenderer & co.); the board only adds the
## dynamic layers: pool water, coping and the hover cursor.
## true where the cell is pool water (row-major ROWS*COLS).
var water: PackedByteArray = PackedByteArray()

const POOL_DIR := "res://assets/tiles/pool/"
var _water_layer: PoolWaterLayer
var _edge_layer: PoolCopingLayer
var _hover_layer: CellCursor

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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_water_layer = PoolWaterLayer.new()
	_water_layer.board = self
	add_child(_water_layer)
	_edge_layer = PoolCopingLayer.new()
	_edge_layer.board = self
	add_child(_edge_layer)
	_hover_layer = CellCursor.new()
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
