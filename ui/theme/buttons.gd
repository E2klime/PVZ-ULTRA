class_name ThemeButtons
extends RefCounted
## Button family: painted enamel (primary) and walnut (secondary) states.

const OUTLINE := Color(0.13, 0.27, 0.08)

static func apply(t: Theme) -> void:
	for type: String in ["Button", "OptionButton", "CheckButton", "MenuButton"]:
		t.set_stylebox("normal", type, KitStyles.get_style("button"))
		t.set_stylebox("hover", type, KitStyles.get_style("button_hover"))
		t.set_stylebox("pressed", type, KitStyles.get_style("button_pressed"))
		t.set_stylebox("hover_pressed", type, KitStyles.get_style("button_pressed"))
		t.set_stylebox("disabled", type, KitStyles.get_style("button_disabled"))
		t.set_stylebox("focus", type, KitStyles.get_style("button_focus"))
		t.set_color("font_color", type, Color(1, 0.99, 0.94))
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color(0.93, 0.95, 0.86))
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(0.9, 0.9, 0.86))
		t.set_color("font_outline_color", type, OUTLINE)
		t.set_constant("outline_size", type, 5)
	t.set_type_variation("WoodButton", "Button")
	t.set_stylebox("normal", "WoodButton", KitStyles.get_style("button_wood"))
	t.set_stylebox("hover", "WoodButton", KitStyles.get_style("button_wood_hover"))
	t.set_stylebox("pressed", "WoodButton", KitStyles.get_style("button_wood_pressed"))
	t.set_stylebox("disabled", "WoodButton", KitStyles.get_style("button_disabled"))
	t.set_color("font_outline_color", "WoodButton", Color(0.22, 0.11, 0.04))
	var flat := StyleBoxEmpty.new()
	flat.set_content_margin_all(6)
	var hov := flat.duplicate() as StyleBoxEmpty
	for s: String in ["normal", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(s, "CheckBox", flat)
	t.set_stylebox("hover", "CheckBox", hov)
