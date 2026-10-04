class_name Mower
extends Node2D
## One-shot lawn mower per lane.

enum MowerState { IDLE, RUNNING, USED }

## A walking zombie triggers the mower when its feet come this close (px).
const TRIGGER_REACH := 30.0
## Blade half-width; everything between the house and the blade's front edge is cut,
## so a zombie that already slipped behind the mower cannot survive the run.
const BLADE_REACH := 50.0

var battle: Battle
var row: int = 0
var state: MowerState = MowerState.IDLE
var color: Color = Color(0.85, 0.2, 0.2)
var _wheel: float = 0.0

func setup(b: Battle, r: int, c: Color) -> void:
	battle = b
	row = r
	color = c
	position = Vector2(Board.ORIGIN.x - 55.0, Board.row_feet_y(r))

func trigger() -> void:
	Sfx.play(&"mower")
	if state == MowerState.IDLE:
		state = MowerState.RUNNING

func restore() -> void:
	state = MowerState.IDLE
	position = Vector2(Board.ORIGIN.x - 55.0, Board.row_feet_y(row))
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

func _physics_process(delta: float) -> void:
	if state != MowerState.RUNNING:
		return
	position.x += 760.0 * delta
	_wheel += delta * 20.0
	for z: Zombie in battle.zombies_in_row(row).duplicate():
		if z.is_alive() and z.position.x < position.x + BLADE_REACH:
			z.die(&"mower")
	if position.x > Board.SPAWN_X + 200.0:
		state = MowerState.USED
		visible = false
	queue_redraw()

func _draw() -> void:
	if state == MowerState.USED:
		return
	draw_colored_polygon(DrawUtil.ellipse_points(Vector2(0, 4), 42, 9), Color(0, 0, 0, 0.2))
	DrawUtil.rrect(self, Rect2(Vector2(-36, -44), Vector2(72, 32)), color, 8)
	DrawUtil.rrect(self, Rect2(Vector2(-20, -60), Vector2(30, 18)), color.darkened(0.2), 5, 3)
	DrawUtil.line(self, Vector2(-30, -40), Vector2(-56, -86), Color(0.3, 0.3, 0.32), 5)
	DrawUtil.line(self, Vector2(-66, -86), Vector2(-46, -86), Color(0.3, 0.3, 0.32), 5)
	for x: float in [-22.0, 22.0]:
		DrawUtil.circle(self, Vector2(x, -10), 12, Color(0.2, 0.2, 0.22), 3)
		draw_line(Vector2(x, -10), Vector2(x, -10) + Vector2(9, 0).rotated(_wheel), Color(0.6, 0.6, 0.6), 2)
