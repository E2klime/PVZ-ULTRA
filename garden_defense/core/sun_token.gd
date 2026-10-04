class_name SunToken
extends Node2D
## A collectible sun. Falls from the sky or pops out of a producer.

const LIFETIME := 12.0
const PICK_RADIUS := 58.0

var battle: Battle
var amount: int = 25
var collected: bool = false
var _fall_to: float = 0.0
var _falling: bool = false
var _life: float = LIFETIME
var _spin: float = randf() * TAU

func setup_sky(b: Battle, x: float, to_y: float, value: int) -> void:
	battle = b
	amount = value
	position = Vector2(x, 120.0)
	_fall_to = to_y
	_falling = true

func setup_pop(b: Battle, from: Vector2, value: int) -> void:
	battle = b
	amount = value
	position = from
	var land := from + Vector2(randf_range(-40, 40), randf_range(35, 60))
	var tw := create_tween()
	tw.tween_property(self, "position:x", land.x, 0.5)
	tw.parallel().tween_property(self, "position:y", from.y - 40.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_property(self, "position:y", land.y, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if Settings.auto_collect_sun:
		tw.chain().tween_callback(collect)

func _physics_process(delta: float) -> void:
	if collected:
		return
	_spin += delta
	if _falling:
		position.y += 70.0 * delta
		if position.y >= _fall_to:
			position.y = _fall_to
			_falling = false
			if Settings.auto_collect_sun:
				collect()
	else:
		_life -= delta
		if _life <= 0.0:
			collected = true
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.4)
			tw.tween_callback(queue_free)
	queue_redraw()

func hit(p: Vector2) -> bool:
	return not collected and position.distance_to(p) <= PICK_RADIUS

func collect() -> void:
	if collected:
		return
	collected = true
	Sfx.play(&"sun", -4.0)
	var target := battle.sun_counter_world_pos()
	var tw := create_tween()
	tw.tween_property(self, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector2(0.6, 0.6), 0.45)
	tw.tween_callback(_arrive)

func _arrive() -> void:
	battle.add_sun(amount, true)
	queue_free()

func _draw() -> void:
	var blink := 1.0
	if not collected and not _falling and _life < 3.0:
		blink = 0.4 + 0.6 * absf(sin(_life * 8.0))
	var c := Color(1.0, 0.86, 0.25, blink)
	draw_circle(Vector2.ZERO, 46, Color(1, 0.95, 0.5, 0.25 * blink))
	for i: int in 12:
		var a := _spin + TAU * float(i) / 12.0
		draw_line(Vector2.RIGHT.rotated(a) * 26, Vector2.RIGHT.rotated(a) * 40, Color(1, 0.75, 0.15, blink), 5)
	draw_circle(Vector2.ZERO, 28, Color(0.95, 0.6, 0.1, blink))
	draw_circle(Vector2.ZERO, 24, c)
	draw_circle(Vector2(-8, -8), 7, Color(1, 1, 0.85, blink))
