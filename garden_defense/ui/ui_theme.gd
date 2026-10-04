class_name UITheme
extends RefCounted
## Hand-built UI theme (no generated UI art): flat panels with coloured borders.

const INK := Color(0.24, 0.16, 0.1)
const PAPER := Color(0.98, 0.93, 0.8)
const LEAF := Color(0.36, 0.62, 0.26)
const LEAF_DARK := Color(0.2, 0.4, 0.15)
const SUN := Color(1.0, 0.82, 0.25)
const BAD := Color(0.85, 0.25, 0.2)
## Legendary rarity accent (cards, almanac, shop).
const LEGEND := Color(0.85, 0.58, 0.08)
const LEGEND_LIGHT := Color(1.0, 0.9, 0.55)

static func box(bg: Color, border: Color, radius: int = 14, border_w: int = 4, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

static func panel_box() -> StyleBoxFlat:
	var panel := box(PAPER, Color(0.55, 0.38, 0.22), 18, 5, 18)
	panel.shadow_size = 8
	panel.shadow_color = Color(0, 0, 0, 0.3)
	return panel

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	# Buttons
	var normal := box(LEAF, LEAF_DARK, 14, 4, 14)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	normal.shadow_color = Color(0, 0, 0, 0.25)
	var hover := box(LEAF.lightened(0.12), LEAF_DARK, 14, 4, 14)
	var pressed := box(LEAF.darkened(0.15), LEAF_DARK, 14, 4, 14)
	var disabled := box(Color(0.55, 0.55, 0.5), Color(0.38, 0.38, 0.35), 14, 4, 14)
	var focus := box(Color(0, 0, 0, 0), SUN, 14, 3, 14)
	for type: String in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, Color.WHITE)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color(0.95, 0.95, 0.9))
		t.set_color("font_disabled_color", type, Color(0.85, 0.85, 0.82))
		t.set_color("font_outline_color", type, LEAF_DARK)
		t.set_constant("outline_size", type, 4)
	# Panels
	var panel := panel_box()
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_color", "RichTextLabel", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_stylebox("normal", "CheckBox", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 6))
	t.set_stylebox("hover", "CheckBox", box(Color(0, 0, 0, 0.05), Color(0, 0, 0, 0), 4, 0, 6))
	t.set_stylebox("pressed", "CheckBox", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 6))
	# Progress
	t.set_stylebox("background", "ProgressBar", box(Color(0.3, 0.22, 0.14), Color(0.2, 0.14, 0.08), 10, 3, 0))
	t.set_stylebox("fill", "ProgressBar", box(LEAF, LEAF_DARK, 10, 3, 0))
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	# Tabs
	t.set_stylebox("panel", "TabContainer", box(Color(0.93, 0.87, 0.72, 0.96), Color(0.55, 0.38, 0.22), 14, 4, 14))
	for tt: String in ["TabContainer"]:
		t.set_stylebox("tab_selected", tt, box(PAPER, Color(0.55, 0.38, 0.22), 10, 4, 12))
		t.set_stylebox("tab_unselected", tt, box(Color(0.85, 0.78, 0.62), Color(0.55, 0.38, 0.22), 10, 4, 12))
		t.set_stylebox("tab_hovered", tt, box(Color(0.92, 0.86, 0.7), Color(0.55, 0.38, 0.22), 10, 4, 12))
		t.set_color("font_selected_color", tt, INK)
		t.set_color("font_unselected_color", tt, INK.lightened(0.25))
		t.set_color("font_hovered_color", tt, INK)
	t.set_stylebox("tab_selected", "TabBar", box(PAPER, Color(0.55, 0.38, 0.22), 10, 4, 12))
	t.set_stylebox("tab_unselected", "TabBar", box(Color(0.85, 0.78, 0.62), Color(0.55, 0.38, 0.22), 10, 4, 12))
	t.set_stylebox("tab_hovered", "TabBar", box(Color(0.92, 0.86, 0.7), Color(0.55, 0.38, 0.22), 10, 4, 12))
	t.set_color("font_selected_color", "TabBar", INK)
	t.set_color("font_unselected_color", "TabBar", INK.lightened(0.25))
	t.set_color("font_hovered_color", "TabBar", INK)
	# Scroll bars a bit thicker for touch
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.12), Color(0, 0, 0, 0), 8, 0, 6))
	t.set_stylebox("grabber", "VScrollBar", box(Color(0.55, 0.38, 0.22), Color(0, 0, 0, 0), 8, 0, 6))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(0.65, 0.45, 0.28), Color(0, 0, 0, 0), 8, 0, 6))
	return t
