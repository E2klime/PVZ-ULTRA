class_name FieldRules
extends Node2D
## Biome mechanics: bounded, announced pulses. Board geometry remains 5 x 9.
var battle: Battle
var clock: float = 0.0
var pulse: float = 28.0
var active_row: int = 0
var _announced: bool = false

func setup(b: Battle) -> void:
	battle = b
	active_row = (b.level.ordinal - 1) % Board.ROWS
	z_index = 2

func _physics_process(delta: float) -> void:
	if battle.phase != Battle.Phase.PLAYING:
		return
	clock += delta
	pulse -= delta
	if pulse < 3.0 and not _announced and battle.level.field_rule != &"normal":
		_announced = true
		battle.hud.toast(tr("FIELD_PULSE").format({"n": active_row + 1, "rule": rule_name(battle.level.field_rule)}))
	if pulse <= 0.0:
		_apply_pulse()
		pulse = 28.0
		_announced = false
		active_row = (active_row + 1) % Board.ROWS
	queue_redraw()

## Localized display name of a field rule (falls back to a readable id).
static func rule_name(rule: StringName) -> String:
	var key := "FIELD_" + String(rule).to_upper()
	var t := TranslationServer.translate(key)
	return t if t != key else String(rule).replace("_", " ").capitalize()

func _apply_pulse() -> void:
	match battle.level.field_rule:
		&"heat":
			for p: Plant in battle.board.all_plants():
				if p.row == active_row and not p.is_air(): p.take_damage(25.0)
		&"frost":
			for s: SeedState in battle.seeds: s.cooldown += 1.5
			for z: Zombie in battle.zombies_in_row(active_row): z.apply_slow(0.65, 5.0)
		&"wind":
			for z: Zombie in battle.zombies_in_row(active_row): z.push(65.0)
		&"conveyor":
			for z: Zombie in battle.zombies_in_row(active_row):
				if z.is_alive(): z.position.x = maxf(Board.HOUSE_X + 100.0, z.position.x - 35.0)
		&"low_gravity":
			for z: Zombie in battle.zombies_in_row(active_row).duplicate():
				if z.is_alive(): z.move_to_row(Board.neighbor_row(active_row))
		&"tide":
			battle.spawn_sun(Board.cell_center(active_row, 4), 75, false)
		&"night":
			battle.spawn_sun(Board.cell_center(active_row, 1), 50, false)

func _draw() -> void:
	if battle == null: return
	for r: int in Board.ROWS:
		for c: int in Board.COLS:
			if battle.level.is_blocked(r, c):
				var rect := Rect2(Board.ORIGIN + Vector2(c, r) * Board.CELL, Board.CELL)
				draw_rect(rect.grow(-6), Color(0.2, 0.18, 0.2, 0.75))
				draw_line(rect.position + Vector2(20, 20), rect.end - Vector2(20, 20), Color(0.9, 0.6, 0.2), 6)
	if battle.level.field_rule != &"normal":
		var rect := Rect2(Board.ORIGIN + Vector2(0, active_row * Board.CELL.y), Vector2(Board.COLS * Board.CELL.x, Board.CELL.y))
		draw_rect(rect, Color(0.7, 0.75, 1.0, 0.06 if pulse > 3.0 else 0.22))
