class_name ThemeBars
extends RefCounted
## Bar family: walnut track + enamel fill progress bars, slim painted scrollbars.

static func apply(t: Theme) -> void:
	t.set_stylebox("background", "ProgressBar", KitStyles.get_style("bar_bg", 0))
	t.set_stylebox("fill", "ProgressBar", KitStyles.get_style("bar_fill", 0))
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	t.set_color("font_outline_color", "ProgressBar", Color(0.15, 0.1, 0.05))
	t.set_constant("outline_size", "ProgressBar", 4)
	for sb: String in ["VScrollBar"]:
		t.set_stylebox("scroll", sb, KitStyles.get_style("scroll_track"))
		t.set_stylebox("scroll_focus", sb, KitStyles.get_style("scroll_track"))
		t.set_stylebox("grabber", sb, KitStyles.get_style("scroll_grab"))
		t.set_stylebox("grabber_highlight", sb, KitStyles.get_style("scroll_grab_hover"))
		t.set_stylebox("grabber_pressed", sb, KitStyles.get_style("scroll_grab_hover"))
