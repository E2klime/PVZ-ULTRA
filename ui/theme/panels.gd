class_name ThemePanels
extends RefCounted
## Panel family: parchment-in-honeywood (light) and walnut boards (dark), plus tabs.

static func apply(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", KitStyles.get_style("panel"))
	t.set_stylebox("panel", "Panel", KitStyles.get_style("panel"))
	t.set_type_variation("BoardPanel", "PanelContainer")
	t.set_stylebox("panel", "BoardPanel", KitStyles.get_style("board"))
	t.set_stylebox("panel", "TabContainer", KitStyles.get_style("panel"))
	for tt: String in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", tt, KitStyles.get_style("tab_selected"))
		t.set_stylebox("tab_unselected", tt, KitStyles.get_style("tab"))
		t.set_stylebox("tab_hovered", tt, KitStyles.get_style("tab_hover"))
		t.set_stylebox("tab_focus", tt, StyleBoxEmpty.new())
		t.set_color("font_selected_color", tt, UITheme.INK)
		t.set_color("font_unselected_color", tt, Color(1, 0.93, 0.8))
		t.set_color("font_hovered_color", tt, Color.WHITE)
		t.set_color("font_outline_color", tt, Color(0.2, 0.1, 0.04))
		t.set_constant("outline_size", tt, 0)
	t.set_color("font_color", "Label", UITheme.INK)
	for c: String in ["CheckBox"]:
		t.set_color("font_color", c, UITheme.INK)
		t.set_color("font_hover_color", c, UITheme.INK)
		t.set_color("font_pressed_color", c, UITheme.INK)
	t.set_color("font_color", "RichTextLabel", UITheme.INK)
	t.set_color("default_color", "RichTextLabel", UITheme.INK)
