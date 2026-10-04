class_name UIKit
extends RefCounted
## Small factory helpers so screens stay readable. All texts are translation keys.

static func label(text: String, size: int = 26, color: Color = UITheme.INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

## Single-line label whose font shrinks (down to min_size) until the text fits
## max_w; used for translated names in fixed-size tiles.
static func fit_label(text: String, size: int, max_w: float, color: Color = UITheme.INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, min_size: int = 11) -> Label:
	var fs := size
	var font := ThemeDB.fallback_font
	while font and fs > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	var l := label(text, fs, color, align)
	l.clip_text = true
	return l

static func title(text: String, size: int = 56) -> Label:
	var l := label(text, size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", UITheme.LEAF_DARK)
	l.add_theme_constant_override("outline_size", 12)
	return l

static func wrap(text: String, size: int = 24, color: Color = UITheme.INK) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, cb: Callable, min_w: float = 220.0, size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 64)
	b.add_theme_font_size_override("font_size", size)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func panel(margin: int = -1) -> PanelContainer:
	var p := PanelContainer.new()
	if margin >= 0:
		var sb := UITheme.panel_box()
		sb.set_content_margin_all(margin)
		p.add_theme_stylebox_override("panel", sb)
	return p

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer(h: float = 0.0, expand: bool = true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

static func centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.add_child(c)
	return cc
