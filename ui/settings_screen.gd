class_name SettingsScreen
extends Control
## Tabbed settings: Audio, Video, Gameplay, Controls, Accessibility, Language, Data.

var _back: StringName = &"menu"
var _confirm_reset: bool = false
var _reset_btn: Button

func set_args(args: Dictionary) -> void:
	_back = args.get("back", &"menu")

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.with_art("res://assets/art/keyart.jpg", 0.45))
	var p := UIKit.panel(26)
	p.custom_minimum_size = Vector2(1180, 820)
	var v := UIKit.vbox(14)
	var head := UIKit.hbox(12)
	var gear := TextureRect.new()
	gear.texture = load("res://assets/ui/gear.png")
	gear.custom_minimum_size = Vector2(56, 56)
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear.modulate = Color(0.45, 0.32, 0.2)
	head.add_child(gear)
	head.add_child(UIKit.label(tr("UI_SETTINGS"), 46))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.button(tr("SETTINGS_DEFAULTS"), _defaults, 260, 22))
	head.add_child(UIKit.button(tr("UI_BACK"), func() -> void: GameState.goto(_back), 200))
	v.add_child(head)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 680)
	tabs.add_theme_font_size_override("font_size", 24)
	tabs.add_child(_tab("SETTINGS_TAB_AUDIO", _audio()))
	tabs.add_child(_tab("SETTINGS_TAB_VIDEO", _video()))
	tabs.add_child(_tab("SETTINGS_TAB_GAMEPLAY", _gameplay()))
	tabs.add_child(_tab("SETTINGS_TAB_CONTROLS", _controls()))
	tabs.add_child(_tab("SETTINGS_TAB_ACCESS", _access()))
	tabs.add_child(_tab("SETTINGS_TAB_LANGUAGE", _language()))
	tabs.add_child(_tab("SETTINGS_TAB_DATA", _data()))
	v.add_child(tabs)
	p.add_child(v)
	add_child(UIKit.centered(p))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.goto(_back)

func _tab(key: String, content: Control) -> Control:
	var s := ScrollContainer.new()
	s.name = tr(key)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s

static func row(text: String, control: Control, hint: String = "") -> Control:
	var v := UIKit.vbox(2)
	var h := UIKit.hbox(16)
	var l := UIKit.label(text, 26)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 320)
	h.add_child(control)
	v.add_child(h)
	if hint != "":
		v.add_child(UIKit.wrap(hint, 19, UITheme.INK.lightened(0.35)))
	return v

static func slider(key: StringName, persist_on_release: bool = true) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(320, 40)
	s.value = float(Settings.get_value(key)) * 100.0
	s.value_changed.connect(func(x: float) -> void:
		Settings.set_value(key, x / 100.0, false)
		Settings.apply())
	s.drag_ended.connect(func(_c: bool) -> void:
		Settings.save()
		Sfx.play(&"click"))
	return s

## Pill-shaped on/off switch (the theme's CheckButton is stretched by rows).
class Switch:
	extends Button
	func _init() -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(110, 48)
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		toggled.connect(func(_on: bool) -> void: queue_redraw())
	func _draw() -> void:
		var w := 100.0
		var h := 44.0
		var r := Rect2(Vector2(size.x - w, (size.y - h) * 0.5), Vector2(w, h))
		var on := button_pressed
		DrawUtil.rrect(self, r, Color(0.3, 0.62, 0.2) if on else Color(0.55, 0.5, 0.45), h * 0.5, 0)
		DrawUtil.rrect(self, r.grow(-3), Color(0.42, 0.78, 0.28) if on else Color(0.72, 0.67, 0.6), h * 0.5 - 3, 0)
		var kx := r.end.x - h * 0.5 if on else r.position.x + h * 0.5
		draw_circle(Vector2(kx, r.get_center().y), h * 0.5 - 5, Color(1, 1, 0.97))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(r.position.x + (10 if on else 48), r.get_center().y + 7), tr("UI_ON") if on else tr("UI_OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.95))

static func toggle(key: StringName, extra: Callable = Callable()) -> Button:
	var c := Switch.new()
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(on: bool) -> void:
		Settings.set_value(key, on)
		Sfx.play(&"click")
		if extra.is_valid():
			extra.call(on))
	return c

static func choice(key: StringName, labels: Array, values: Array) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 22)
	var cur: Variant = Settings.get_value(key)
	for i: int in labels.size():
		o.add_item(TranslationServer.translate(labels[i]))
		if str(values[i]) == str(cur):
			o.select(i)
	o.item_selected.connect(func(i: int) -> void:
		Settings.set_value(key, values[i])
		Sfx.play(&"click"))
	return o

func _section() -> VBoxContainer:
	var v := UIKit.vbox(18)
	v.add_theme_constant_override("separation", 18)
	return v

func _audio() -> Control:
	var v := _section()
	v.add_child(row(tr("SETTINGS_VOL_MASTER"), slider(&"vol_master")))
	v.add_child(row(tr("SETTINGS_VOL_MUSIC"), slider(&"vol_music")))
	v.add_child(row(tr("SETTINGS_VOL_SFX"), slider(&"vol_sfx")))
	if not OS.has_feature("mobile"):
		v.add_child(row(tr("SETTINGS_MUTE_UNFOCUSED"), toggle(&"mute_unfocused")))
	v.add_child(UIKit.button(tr("SETTINGS_TEST_SOUND"), func() -> void: Sfx.play(&"sun"), 300, 22))
	return v

func _video() -> Control:
	var v := _section()
	v.add_child(row(tr("SETTINGS_FPS"), choice(&"fps_limit", ["30 FPS", "60 FPS", "90 FPS", "120 FPS"], [30, 60, 90, 120]), tr("SETTINGS_FPS_HINT")))
	if not OS.has_feature("mobile"):
		v.add_child(row(tr("SETTINGS_FULLSCREEN"), toggle(&"fullscreen")))
	v.add_child(row(tr("SETTINGS_VSYNC"), toggle(&"vsync")))
	v.add_child(row(tr("SETTINGS_PARTICLES"), choice(&"particles", ["SETTINGS_OFF", "SETTINGS_LOW", "SETTINGS_HIGH"], [0, 1, 2])))
	v.add_child(row(tr("SETTINGS_SHAKE"), toggle(&"screen_shake")))
	v.add_child(row(tr("SETTINGS_SHOW_FPS"), toggle(&"show_fps")))
	return v

func _gameplay() -> Control:
	var v := _section()
	var ids: Array = []
	var names: Array = []
	for d: DifficultyData in DB.difficulties:
		ids.append(String(d.id))
		names.append(d.name_key)
	var diff := choice(&"difficulty", names, ids)
	diff.item_selected.connect(func(i: int) -> void: GameState.difficulty_id = StringName(ids[i]))
	v.add_child(row(tr("SETTINGS_DIFFICULTY"), diff, tr("SETTINGS_DIFFICULTY_HINT")))
	v.add_child(row(tr("SETTINGS_AUTO_SUN"), toggle(&"auto_collect_sun")))
	v.add_child(row(tr("SETTINGS_DEFAULT_SPEED"), choice(&"default_speed", ["×1", "×2"], [1.0, 2.0])))
	v.add_child(row(tr("SETTINGS_HEALTH_BARS"), choice(&"health_bars", ["SETTINGS_OFF", "SETTINGS_DAMAGED", "SETTINGS_ALWAYS"], [0, 1, 2])))
	v.add_child(row(tr("SETTINGS_STICKY_TOOLS"), toggle(&"sticky_tools"), tr("SETTINGS_STICKY_TOOLS_HINT")))
	v.add_child(row(tr("SETTINGS_HINTS"), toggle(&"show_hints")))
	return v

func _controls() -> Control:
	var v := _section()
	v.add_child(row(tr("SETTINGS_HAPTICS"), toggle(&"haptics")))
	v.add_child(row(tr("SETTINGS_DRAG"), toggle(&"drag_to_plant"), tr("SETTINGS_DRAG_HINT")))
	v.add_child(row(tr("SETTINGS_LONG_PRESS"), toggle(&"long_press_info")))
	if not OS.has_feature("mobile"):
		v.add_child(UIKit.wrap(tr("SETTINGS_KEYS"), 22))
	return v

func _access() -> Control:
	var v := _section()
	v.add_child(row(tr("SETTINGS_REDUCE_MOTION"), toggle(&"reduce_motion"), tr("SETTINGS_REDUCE_MOTION_HINT")))
	v.add_child(row(tr("SETTINGS_HC_HP"), toggle(&"high_contrast_hp")))
	v.add_child(row(tr("SETTINGS_CB_HINTS"), toggle(&"colorblind_hints"), tr("SETTINGS_CB_HINTS_HINT")))
	return v

func _language() -> Control:
	var v := _section()
	var langs := OptionButton.new()
	for i: int in Settings.LANGUAGES.size():
		var code := Settings.LANGUAGES[i]
		langs.add_item(tr("LANG_" + code.to_upper()))
		langs.set_item_disabled(i, not code in Settings.ENABLED_LANGUAGES)
		if code == Settings.language:
			langs.select(i)
	langs.item_selected.connect(func(i: int) -> void:
		Settings.set_value(&"language", Settings.LANGUAGES[i])
		GameState.goto(&"settings", {"back": _back}))
	v.add_child(row(tr("SETTINGS_LANGUAGE"), langs, tr("SETTINGS_LANGUAGE_HINT")))
	return v

func _data() -> Control:
	var v := _section()
	v.add_child(UIKit.wrap(tr("SETTINGS_SAVE_PATH").format({"p": ProjectSettings.globalize_path("user://")}), 20))
	v.add_child(UIKit.label(tr("SETTINGS_STATS_LINE").format({"wins": SaveManager.stat(&"wins"), "plants": SaveManager.stat(&"planted"), "grafts": SaveManager.stat(&"grafts")}), 22))
	_reset_btn = UIKit.button(tr("SETTINGS_RESET"), _on_reset, 380)
	_reset_btn.add_theme_stylebox_override("normal", UITheme.kit("button_danger"))
	_reset_btn.add_theme_stylebox_override("hover", UITheme.kit("button_danger_hover"))
	v.add_child(_reset_btn)
	return v

func _defaults() -> void:
	Settings.reset_defaults()
	GameState.goto(&"settings", {"back": _back})

func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = tr("SETTINGS_RESET_CONFIRM")
		return
	SaveManager.reset()
	_confirm_reset = false
	_reset_btn.text = tr("SETTINGS_RESET_DONE")

## Compact volume/auto-sun controls for the pause menu.
static func quick_panel() -> Control:
	var v := UIKit.vbox(6)
	v.add_child(row(TranslationServer.translate("SETTINGS_VOL_MUSIC"), slider(&"vol_music")))
	v.add_child(row(TranslationServer.translate("SETTINGS_VOL_SFX"), slider(&"vol_sfx")))
	v.add_child(row(TranslationServer.translate("SETTINGS_AUTO_SUN"), toggle(&"auto_collect_sun")))
	return v
