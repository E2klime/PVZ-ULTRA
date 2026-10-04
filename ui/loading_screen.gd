class_name LoadingScreen
extends Control
## PvZ2-style splash: key art, logo, green loading bar and a random tip.
## Warms up the painted rigs, backdrops and sounds so the first battle is smooth.

var _bar: ProgressBar
var _tip: Label
var _queue: Array[Callable] = []
var _total: int = 1
var _done: int = 0
var _t: float = 0.0
var _logo: TextureRect

const TIPS := 12

func _ready() -> void:
	UIKit.full(self)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/keyart.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(UIKit.full(art))
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/ui/logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.size = Vector2(880, 304)
	_logo.position = Vector2(520, 30)
	_logo.pivot_offset = _logo.size * 0.5
	add_child(_logo)
	var bottom := UIKit.vbox(10)
	bottom.position = Vector2(560, 900)
	bottom.custom_minimum_size = Vector2(800, 0)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(800, 44)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", UITheme.box(Color(0.12, 0.08, 0.04, 0.85), Color(0.95, 0.85, 0.5), 22, 4, 0))
	_bar.add_theme_stylebox_override("fill", UITheme.box(Color(0.42, 0.82, 0.22), Color(0.22, 0.5, 0.1), 22, 3, 0))
	bottom.add_child(_bar)
	_tip = HUDLabel.make(tr("TIP_%d" % (randi() % TIPS + 1)), 26)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(800, 0)
	bottom.add_child(_tip)
	add_child(bottom)
	var ver := HUDLabel.make("v" + str(ProjectSettings.get_setting("application/config/version", "0.7")), 18)
	ver.position = Vector2(20, 1046)
	add_child(ver)
	# work queue
	for id: StringName in DB.PLANT_ORDER:
		_queue.append(func() -> void: Rig.plant(id))
	for id: StringName in DB.ZOMBIE_ORDER:
		_queue.append(func() -> void: Rig.zombie(id))
	for p: String in ["res://assets/art/bg/battle_lawn.jpg", "res://assets/art/bg/battle_pool.jpg", "res://assets/ui/logo.png"]:
		_queue.append(func() -> void: load(p))
	_total = maxi(1, _queue.size())
	Sfx.play_music(&"menu")

func _process(delta: float) -> void:
	_t += delta
	_logo.scale = Vector2.ONE * (1.0 + sin(_t * 2.0) * 0.015)
	var budget := Time.get_ticks_msec() + 12
	while not _queue.is_empty() and Time.get_ticks_msec() < budget:
		var job: Callable = _queue.pop_front()
		job.call()
		_done += 1
	var target := float(_done) / float(_total)
	_bar.value = lerpf(_bar.value, target * 100.0, minf(1.0, delta * 8.0))
	if _queue.is_empty() and _bar.value > 99.0 and _t > 1.2:
		set_process(false)
		GameState.goto(&"menu")

## White outlined label used on art backgrounds.
class HUDLabel:
	static func make(text: String, size: int) -> Label:
		var l := UIKit.label(text, size, Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.1, 0.05))
		l.add_theme_constant_override("outline_size", 8)
		return l
