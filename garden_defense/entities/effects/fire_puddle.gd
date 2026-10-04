class_name FirePuddle
extends Node2D
## Burning ground left by Volcano Mine. Burns zombies standing in it.

var battle: Battle
var row: int = 0
var dps: float = 40.0
var life: float = 5.0
var half_width: float = 1.5 * Board.CELL.x
var _t: float = 0.0
var _tick: float = 0.0

func setup(b: Battle, r: int, c: int, p_dps: float, p_life: float) -> void:
	battle = b
	row = r
	dps = p_dps
	life = p_life
	position = Board.cell_feet(r, c)

func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for rr: int in [row - 1, row, row + 1]:
			for z: Zombie in battle.zombies_in_row(rr).duplicate():
				if absf(z.position.x - position.x) < half_width:
					z.burn(dps, 1.0)
	if _t >= life:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var a := clampf((life - _t) / 1.0, 0.0, 1.0)
	draw_colored_polygon(DrawUtil.ellipse_points(Vector2.ZERO, half_width, Board.CELL.y * 0.9), Color(1, 0.4, 0.05, 0.12 * a))
	for i: int in 9:
		var x := -half_width * 0.85 + i * half_width * 0.21
		var h := 18.0 + 10.0 * sin(_t * 9.0 + i * 1.7)
		DrawUtil.poly(self, PackedVector2Array([Vector2(x - 9, 0), Vector2(x, -h), Vector2(x + 9, 0)]), Color(1, 0.55, 0.1, 0.85 * a), 0)
