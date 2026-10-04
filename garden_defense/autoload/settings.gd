extends Node
## Player settings stored separately from progress (user://settings.cfg).
## Typed shortcuts are kept for old call sites; everything else lives in `values`
## and is read with get_value()/set_value().

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const LANGUAGES: Array[String] = ["en", "ru", "zh_CN", "ja", "de"]
## All shipped locales (localization/translations.csv + content.csv).
const ENABLED_LANGUAGES: Array[String] = ["en", "ru", "zh_CN", "ja", "de"]
## CJK glyph subsets used as fallbacks of the default UI font (see assets/fonts/README.md).
const CJK_FONTS := {
	"zh": "res://assets/fonts/NotoSansSC-GD.otf",
	"ja": "res://assets/fonts/NotoSansJP-GD.otf",
}

const DEFAULTS := {
	# audio (0..1)
	&"vol_master": 0.8, &"vol_music": 0.6, &"vol_sfx": 0.8, &"mute_unfocused": true,
	# video
	&"fps_limit": 60, &"fullscreen": false, &"vsync": true, &"show_fps": false,
	&"particles": 2, &"screen_shake": true, &"ui_scale": 1.0,
	# gameplay
	&"difficulty": "standard", &"auto_collect_sun": false, &"health_bars": 0,
	&"default_speed": 1.0, &"confirm_shovel": false, &"sticky_tools": false,
	&"show_hints": true, &"seed_bank_side": 0,
	# controls
	&"haptics": true, &"drag_to_plant": true, &"long_press_info": true,
	# accessibility
	&"reduce_motion": false, &"high_contrast_hp": false, &"colorblind_hints": false,
	# language
	&"language": "en",
}

var values: Dictionary = {}

var fps_limit: int:
	get: return int(get_value(&"fps_limit"))
	set(v): values[&"fps_limit"] = v
var auto_collect_sun: bool:
	get: return bool(get_value(&"auto_collect_sun"))
	set(v): values[&"auto_collect_sun"] = v
var default_difficulty: StringName:
	get: return StringName(str(get_value(&"difficulty")))
	set(v): values[&"difficulty"] = String(v)
var language: String:
	get: return str(get_value(&"language"))
	set(v): values[&"language"] = v
var fullscreen: bool:
	get: return bool(get_value(&"fullscreen"))
	set(v): values[&"fullscreen"] = v

func _ready() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k: StringName in DEFAULTS:
			if cfg.has_section_key("settings", String(k)):
				values[k] = cfg.get_value("settings", String(k))
		# v0.6 layout
		if cfg.has_section_key("video", "fps_limit"):
			values[&"fps_limit"] = int(cfg.get_value("video", "fps_limit", 60))
			values[&"fullscreen"] = bool(cfg.get_value("video", "fullscreen", false))
			values[&"auto_collect_sun"] = bool(cfg.get_value("game", "auto_collect_sun", false))
			values[&"difficulty"] = str(cfg.get_value("game", "difficulty", "standard"))
	if not cfg.has_section_key("settings", "language"):
		values[&"language"] = detect_language()
	if not language in ENABLED_LANGUAGES:
		values[&"language"] = "en"
	if OS.has_feature("mobile") and not cfg.has_section_key("settings", "fps_limit"):
		values[&"fps_limit"] = 60
	apply()

func get_value(key: StringName, fallback: Variant = null) -> Variant:
	if values.has(key):
		return values[key]
	return DEFAULTS.get(key, fallback)

func set_value(key: StringName, v: Variant, persist: bool = true) -> void:
	values[key] = v
	if key == &"language":
		_apply_language()
	if persist:
		save()
	changed.emit(key)

## Best shipped language for the OS locale (first launch only).
static func detect_language() -> String:
	var os := OS.get_locale()
	if os.begins_with("zh"):
		return "zh_CN"
	var short := os.get_slice("_", 0)
	return short if short in ENABLED_LANGUAGES else "en"

func _apply_language() -> void:
	TranslationServer.set_locale(language)
	_apply_fonts()

## Chinese and Japanese glyphs come from bundled subset fonts chained as
## fallbacks of the default font; the preferred CJK font goes first so shared
## Han characters use the right regional shapes.
func _apply_fonts() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var order := PackedStringArray(["ja", "zh"] if language == "ja" else ["zh", "ja"])
	var chain: Array[Font] = []
	for k: String in order:
		var path: String = CJK_FONTS[k]
		if ResourceLoader.exists(path):
			var f := load(path) as Font
			if f:
				chain.append(f)
	font.fallbacks = chain

func apply() -> void:
	Engine.max_fps = fps_limit
	_apply_language()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value(&"vsync")) else DisplayServer.VSYNC_DISABLED)
	if not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	_apply_audio()

func _apply_audio() -> void:
	var master := float(get_value(&"vol_master"))
	_set_bus(&"Master", master)
	_set_bus(&"Music", float(get_value(&"vol_music")))
	_set_bus(&"SFX", float(get_value(&"vol_sfx")))

func _set_bus(bus: StringName, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))

func reset_defaults() -> void:
	# "Defaults" should not switch the player's language back to English.
	var lang := language
	values = DEFAULTS.duplicate()
	values[&"language"] = lang
	save()

func save() -> void:
	var cfg := ConfigFile.new()
	for k: StringName in values:
		cfg.set_value("settings", String(k), values[k])
	cfg.save(PATH)
	apply()

## Small vibration on supported devices (respects the Haptics setting).
func haptic(ms: int = 20) -> void:
	if bool(get_value(&"haptics")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func particle_mult() -> float:
	return [0.0, 0.5, 1.0][clampi(int(get_value(&"particles")), 0, 2)]
