extends Node
## Art wiring test: every themed control is painted (StyleBoxTexture) in every state, every
## screen id resolves through ScreenArt, and all 8 worlds load a complete, distinct layer set.
## Run: godot --headless --path . res://tools/tests/art_wiring_test.tscn   (exit 1 on failure)

const STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]
const BUTTONS: Array[String] = ["Button", "WoodButton", "OptionButton", "CheckButton", "MenuButton"]
## CheckBox rows are deliberately frameless: the painted part is the check/radio icon.
const ICON_ONLY: Array[String] = ["CheckBox"]
const PANELS: Dictionary = {
	"Panel": ["panel"], "PanelContainer": ["panel"], "PopupMenu": ["panel", "hover"],
	"PopupPanel": ["panel"], "TooltipPanel": ["panel"], "TabContainer": ["panel"],
	"ProgressBar": ["background", "fill"], "HSlider": ["slider", "grabber_area"],
	"LineEdit": ["normal", "focus"], "VScrollBar": ["scroll", "grabber"], "HScrollBar": ["scroll", "grabber"],
}
const ICONS: Dictionary = {
	"CheckBox": ["checked", "unchecked", "radio_checked", "radio_unchecked"],
	"CheckButton": ["checked", "unchecked"], "OptionButton": ["arrow"],
	"HSlider": ["grabber", "grabber_highlight"], "PopupMenu": ["checked", "unchecked"],
}
## Every control type the game instantiates: each stylebox the engine default theme draws for
## it must be overridden by our theme (painted texture, or a deliberate StyleBoxEmpty).
const USED_TYPES: Array[String] = ["Button", "CheckBox", "CheckButton", "OptionButton", "MenuButton",
	"Panel", "PanelContainer", "PopupMenu", "PopupPanel", "TooltipPanel", "TabContainer", "TabBar",
	"ProgressBar", "HSlider", "VSlider", "LineEdit", "VScrollBar", "HScrollBar", "ScrollContainer", "RichTextLabel"]
const SCREENS: Array[String] = ["menu", "loading", "help", "stats", "settings", "hub", "workshop", "almanac", "quests", "shop"]

var fails: int = 0


func _ready() -> void:
	_check_theme(UITheme.build())
	await _check_effective()
	_check_screens()
	_check_worlds()
	print("art_wiring_test: %d failure(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	printerr("FAIL ", msg)


func _painted(t: Theme, item: String, type: String) -> void:
	if not t.has_stylebox(item, type):
		_fail("theme %s/%s: no stylebox" % [type, item])
		return
	var sb: StyleBox = t.get_stylebox(item, type)
	if not (sb is StyleBoxTexture) or (sb as StyleBoxTexture).texture == null:
		_fail("theme %s/%s: %s is not a painted StyleBoxTexture" % [type, item, sb.get_class()])


func _check_theme(t: Theme) -> void:
	for type in BUTTONS:
		for st in STATES:
			_painted(t, st, type)
	for type in ICON_ONLY:
		for st in STATES:
			if not t.has_stylebox(st, type):
				_fail("theme %s/%s: no stylebox" % [type, st])
	for type: String in PANELS:
		for item: String in PANELS[type]:
			_painted(t, item, type)
	for type: String in ICONS:
		for item: String in ICONS[type]:
			if not t.has_icon(item, type) or t.get_icon(item, type) == null:
				_fail("theme %s icon %s missing" % [type, item])
	var engine := ThemeDB.get_default_theme()
	for type in USED_TYPES:
		for item: String in engine.get_stylebox_list(type):
			var ours: StyleBox = t.get_stylebox(item, type) if t.has_stylebox(item, type) else null
			if ours == null:
				_fail("theme %s/%s: falls back to the engine's flat default" % [type, item])
			elif ours is StyleBoxFlat:
				_fail("theme %s/%s: StyleBoxFlat (not painted)" % [type, item])
	if t.default_font_size < 20:
		_fail("theme default font size %d too small for 1080p" % t.default_font_size)


## What a real control resolves, parented under a plain Node like every game screen.
func _check_effective() -> void:
	var holder := VBoxContainer.new()
	add_child(holder)
	var probes: Array[Control] = [Button.new(), OptionButton.new(), PanelContainer.new(), ProgressBar.new()]
	for c in probes:
		holder.add_child(c)
	await get_tree().process_frame
	var items: Array[String] = ["normal", "normal", "panel", "fill"]
	for i in probes.size():
		var sb := probes[i].get_theme_stylebox(items[i])
		if not (sb is StyleBoxTexture):
			_fail("effective %s/%s is %s: painted theme not installed globally" % [probes[i].get_class(), items[i], sb.get_class()])
	holder.queue_free()


func _check_screens() -> void:
	var ids: Array[String] = SCREENS.duplicate()
	for w in WorldArtLoader.WORLDS:
		ids.append("map_" + String(w))
	for id in ids:
		var art := ScreenArt.for_screen(StringName(id))
		if art == null:
			_fail("screen %s: no ScreenArt" % id)
		elif art.texture.get_size() != Vector2(1920, 1080):
			_fail("screen %s: texture %s is not 1920x1080" % [id, art.texture.get_size()])


func _check_worlds() -> void:
	var seen: Dictionary = {}
	for w in WorldArtLoader.WORLDS:
		var cfg := WorldArtLoader.load_world(w)
		if cfg.ground_type == &"missing":
			_fail("world %s: placeholder art" % w)
			continue
		if cfg.ground == null or cfg.ground.get_size() != Vector2(1170, 700):
			_fail("world %s: ground missing or not 1170x700" % w)
		if cfg.environment == null or cfg.edge == null or cfg.tuft == null or cfg.blocked == null:
			_fail("world %s: environment/edge/tuft/blocked missing" % w)
		if cfg.fringe.size() != 5 or cfg.fringe.has(null):
			_fail("world %s: expected 5 fringe strips, got %d" % [w, cfg.fringe.size()])
		if cfg.ground != null:
			var path := cfg.ground.resource_path
			if seen.has(path):
				_fail("world %s shares ground with %s" % [w, seen[path]])
			seen[path] = w
