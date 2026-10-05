class_name ThemeFillIns
extends RefCounted
## Remaining engine-default styleboxes (mirrored, disabled, focus, backgrounds) mapped onto the
## painted kit, so no control ever falls back to Godot's grey StyleBoxFlat. Enforced by
## tools/tests/art_wiring_test.gd.

static func apply(t: Theme) -> void:
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st + "_mirrored", "OptionButton", t.get_stylebox(st, "OptionButton"))
	t.set_stylebox("labeled_separator_left", "PopupMenu", StyleBoxEmpty.new())
	t.set_stylebox("labeled_separator_right", "PopupMenu", StyleBoxEmpty.new())
	for tt: String in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_disabled", tt, KitStyles.get_style("tab", -1, Color(0.75, 0.75, 0.72)))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("button_pressed", "TabBar", KitStyles.get_style("tab_selected"))
	t.set_stylebox("button_highlight", "TabBar", KitStyles.get_style("tab_hover"))
	t.set_stylebox("read_only", "LineEdit", KitStyles.get_style("panel_small", -1, Color(0.85, 0.85, 0.82)))
	# Scroll areas and rich text sit inside painted panels: they draw no frame of their own.
	for item: String in ["panel", "focus"]:
		t.set_stylebox(item, "ScrollContainer", StyleBoxEmpty.new())
	for item: String in ["normal", "focus"]:
		t.set_stylebox(item, "RichTextLabel", StyleBoxEmpty.new())
