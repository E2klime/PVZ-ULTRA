class_name SeedCard
extends Control
## A seed packet: plant preview, cost, recharge overlay, hotkey and selection frame.

signal pressed(card: SeedCard)
signal hovered(card: SeedCard)

const SIZE := Vector2(108, 140)

var data: PlantData
var index: int = -1
var hotkey: String = ""
var selected: bool = false
var dimmed: bool = false
var recharge: float = 1.0   # 1 = ready
var affordable: bool = true
var _preview: EntityPreview

func _init(d: PlantData, i: int = -1) -> void:
	data = d
	index = i
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preview = EntityPreview.new(Vector2(SIZE.x, 104))
	_preview.position = Vector2(0, 4)
	_preview.size = Vector2(SIZE.x, 104)
	add_child(_preview)
	_preview.show_plant(d, 0.62)
	tooltip_text = ""
	mouse_entered.connect(func() -> void: hovered.emit(self))

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		pressed.emit(self)
		accept_event()

func set_state(p_selected: bool, p_recharge: float, p_affordable: bool) -> void:
	if p_selected != selected or absf(p_recharge - recharge) > 0.004 or p_affordable != affordable:
		selected = p_selected
		recharge = p_recharge
		affordable = p_affordable
		refresh()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var legend := data.rarity == &"legendary"
	var bg := UITheme.LEGEND_LIGHT if legend else Color(0.93, 0.86, 0.66)
	DrawUtil.rrect(self, r.grow(-3), bg, 12, 4)
	if legend:
		draw_rect(Rect2(Vector2(8, 8), Vector2(size.x - 16, 94)), Color(0.98, 0.75, 0.3, 0.55))
		var t := Time.get_ticks_msec() * 0.001
		var band := fmod(t * 0.5, 1.6) - 0.3
		var x := 8.0 + band * (size.x - 16)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 8), Vector2(x + 18, 8), Vector2(x - 8, 102), Vector2(x - 26, 102)]), Color(1, 1, 1, 0.35))
		draw_rect(r.grow(-4), UITheme.LEGEND, false, 4.0)
	else:
		draw_rect(Rect2(Vector2(8, 8), Vector2(size.x - 16, 94)), Color(0.55, 0.78, 0.45, 0.6))
	# cost strip
	DrawUtil.rrect(self, Rect2(Vector2(10, size.y - 36), Vector2(size.x - 20, 28)), Color(0.98, 0.95, 0.85), 8, 2)
	var font := get_theme_default_font()
	var cost_col := UITheme.INK if affordable else UITheme.BAD
	draw_string(font, Vector2(10, size.y - 14), str(data.cost), HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 22, cost_col)
	if hotkey != "":
		draw_string(font, Vector2(12, 28), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.2, 0.3, 0.15))

## Overlay drawn above the preview child (recharge, dimming, selection).
class Overlay:
	extends Control
	var card: SeedCard
	func _draw() -> void:
		if card == null:
			return
		var r := Rect2(Vector2.ZERO, card.size)
		if card.dimmed or not card.affordable:
			DrawUtil.rrect(self, r.grow(-3), Color(0, 0, 0, 0.38), 12, 0)
		if card.recharge < 1.0:
			var h := (r.size.y - 6) * (1.0 - card.recharge)
			draw_rect(Rect2(Vector2(3, 3), Vector2(r.size.x - 6, h)), Color(0, 0, 0, 0.5))
		if card.selected:
			draw_rect(r.grow(-1), UITheme.SUN, false, 5.0)

var _overlay: Overlay

func _ready() -> void:
	_overlay = Overlay.new()
	_overlay.card = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

func _process(_delta: float) -> void:
	if data and data.rarity == &"legendary":
		queue_redraw()

func refresh() -> void:
	queue_redraw()
	if _overlay:
		_overlay.queue_redraw()
