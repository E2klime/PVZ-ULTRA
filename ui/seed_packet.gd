class_name SeedPacket
extends Control
## PvZ2-style horizontal seed packet for the vertical battle seed bank:
## portrait on the left, name, red cost tag, recharge shade and layer badge.

signal pressed(packet: SeedPacket)

var data: PlantData
var index: int = -1
var hotkey: String = ""
var selected: bool = false
var recharge: float = 1.0
var affordable: bool = true
var _preview: EntityPreview
var _sel_t: float = 0.0

const BADGES := {&"air": "^", &"under": "v", &"shell": "o"}

func _init(d: PlantData, i: int, sz: Vector2) -> void:
	data = d
	index = i
	custom_minimum_size = sz
	size = sz
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ph := sz.y - 8.0
	_preview = EntityPreview.new(Vector2(ph, ph))
	_preview.position = Vector2(6, 4)
	_preview.size = Vector2(ph, ph)
	_preview.clip_contents = true
	add_child(_preview)
	_preview.show_plant(d, ph / 112.0)

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		pressed.emit(self)
		accept_event()
	var st := event as InputEventScreenTouch
	if st and st.pressed:
		accept_event()

func set_state(p_selected: bool, p_recharge: float, p_affordable: bool) -> void:
	if p_selected != selected or absf(p_recharge - recharge) > 0.003 or p_affordable != affordable:
		if p_recharge >= 1.0 and recharge < 1.0:
			_sel_t = 0.35  # "ready" flash
		selected = p_selected
		recharge = p_recharge
		affordable = p_affordable
		queue_redraw()

func _process(delta: float) -> void:
	if _sel_t > 0.0 or selected or data.rarity == &"legendary":
		_sel_t = maxf(0.0, _sel_t - delta)
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var legend := data.rarity == &"legendary"
	var off := Vector2(10, 0) if selected else Vector2.ZERO
	r.position += off
	# packet body
	var top := Color(0.99, 0.95, 0.78) if not legend else Color(1.0, 0.9, 0.5)
	DrawUtil.rrect(self, r.grow(-2), Color(0.25, 0.17, 0.08), 12, 0)
	DrawUtil.rrect(self, Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 7)), top, 11, 0)
	# portrait window
	var ph := size.y - 8.0
	var win := Rect2(r.position + Vector2(5, 4), Vector2(ph, ph))
	var g1 := Color(0.55, 0.82, 0.42) if not legend else Color(1.0, 0.72, 0.25)
	DrawUtil.rrect(self, win, g1.darkened(0.15), 9, 0)
	DrawUtil.rrect(self, Rect2(win.position + Vector2(3, 3), win.size - Vector2(6, ph * 0.45)), g1.lightened(0.18), 7, 0)
	_preview.position = win.position + Vector2(0, 0)
	var font := get_theme_default_font()
	var tx := win.end.x + 8.0
	var name_w := r.end.x - tx - 6.0
	var nm := tr(data.name_key)
	# Shrink long (translated) names until they fit instead of clipping them.
	var fs := 19
	while fs > 11 and font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_w:
		fs -= 1
	draw_string(font, Vector2(tx, r.position.y + 28), nm, HORIZONTAL_ALIGNMENT_LEFT, name_w, fs, Color(0.25, 0.16, 0.08))
	if BADGES.has(data.layer):
		draw_string(font, Vector2(tx, r.position.y + 50), BADGES[data.layer] + " " + tr("LAYER_" + String(data.layer).to_upper()), HORIZONTAL_ALIGNMENT_LEFT, name_w, 15, Color(0.25, 0.4, 0.6))
	elif legend:
		draw_string(font, Vector2(tx, r.position.y + 50), "★ " + tr("UI_LEGENDARY"), HORIZONTAL_ALIGNMENT_LEFT, name_w, 15, UITheme.LEGEND)
	# red cost tag (PvZ2 style)
	var tag := Rect2(Vector2(r.end.x - 74, r.end.y - 36), Vector2(66, 30))
	DrawUtil.rrect(self, tag, Color(0.78, 0.12, 0.1) if affordable else Color(0.45, 0.2, 0.2), 9, 3)
	draw_string(font, tag.position + Vector2(0, 23), str(data.cost), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 23, Color.WHITE if affordable else Color(1, 0.75, 0.7))
	if hotkey != "":
		draw_string(font, Vector2(tx, r.end.y - 12), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.45, 0.35, 0.2, 0.8))
	if legend:
		var t := Time.get_ticks_msec() * 0.001
		var x := r.position.x + fmod(t * 0.45, 1.6) * r.size.x - 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y + 4), Vector2(x + 16, r.position.y + 4), Vector2(x - 10, r.end.y - 6), Vector2(x - 26, r.end.y - 6)]), Color(1, 1, 1, 0.3))

## Overlay above the preview: recharge shade, dimming and selection glow.
class Overlay:
	extends Control
	var p: SeedPacket
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, p.size)
		if p.selected:
			r.position.x += 10
		if not p.affordable:
			DrawUtil.rrect(self, r.grow(-3), Color(0, 0, 0, 0.28), 11, 0)
		if p.recharge < 1.0:
			var h := (r.size.y - 6) * (1.0 - p.recharge)
			DrawUtil.rrect(self, Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, h)), Color(0.05, 0.05, 0.08, 0.55), 10, 0)
		if p.selected:
			var a := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
			draw_rect(r.grow(-1), Color(1.0, 0.92, 0.3, a), false, 5.0)
		if p._sel_t > 0.0:
			DrawUtil.rrect(self, r.grow(-3), Color(1, 1, 0.8, p._sel_t * 1.5), 11, 0)

var _overlay: Overlay

func _ready() -> void:
	_overlay = Overlay.new()
	_overlay.p = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	set_process(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and _overlay:
		_overlay.queue_redraw()
