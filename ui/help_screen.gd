class_name HelpScreen
extends Control
## "How to play": layers, glove, fusion, twin hybrids, zombie profiles & tiers, modes.

var _back: StringName = &"menu"

func set_args(args: Dictionary) -> void:
	_back = args.get("back", &"menu")

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.for_screen(&"help"))
	var p := build_panel(func() -> void: GameState.goto(_back))
	add_child(UIKit.centered(p))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.goto(_back)

const TOPICS := [
	["HELP_BASICS", ["sunbud", "pod_shooter"]],
	["HELP_LAYERS", ["pea_bedding", "pumpkin_shell", "garlic_drone"]],
	["HELP_GLOVE", ["turbo_bean"]],
	["HELP_FUSION", ["thornwall", "chili_drone"]],
	["HELP_TWINS", ["twin_sunbud", "twin_pod"]],
	["HELP_ZOMBIES", []],
	["HELP_LEGENDARY", ["sky_dragon", "chrono_clover"]],
	["HELP_MODES", []],
]

static func build_panel(on_close: Callable) -> PanelContainer:
	var p := UIKit.panel(24)
	p.custom_minimum_size = Vector2(1300, 860)
	var v := UIKit.vbox(10)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.label(TranslationServer.translate("UI_HELP"), 44))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.button(TranslationServer.translate("UI_BACK"), on_close, 200))
	v.add_child(head)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 740)
	tabs.add_theme_font_size_override("font_size", 22)
	for t: Array in TOPICS:
		var key: String = t[0]
		var sc := ScrollContainer.new()
		sc.name = TranslationServer.translate(key + "_T")
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var h := UIKit.hbox(20)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var txt := RichTextLabel.new()
		txt.bbcode_enabled = true
		txt.fit_content = true
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_theme_font_size_override("normal_font_size", 24)
		txt.add_theme_font_size_override("bold_font_size", 25)
		txt.text = TranslationServer.translate(key + "_B")
		h.add_child(txt)
		var pics := UIKit.vbox(6)
		for id: String in t[1]:
			var d := DB.plant(StringName(id))
			if d:
				var prev := EntityPreview.new(Vector2(200, 180))
				pics.add_child(prev)
				prev.show_plant(d, 0.95)
				pics.add_child(UIKit.label(TranslationServer.translate(d.name_key), 18, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
		if key == "HELP_ZOMBIES":
			for id: StringName in [&"box_zombie", &"balloon_zombie", &"slingshot_zombie"]:
				var z := DB.zombie(id)
				if z:
					var prev := EntityPreview.new(Vector2(200, 200))
					pics.add_child(prev)
					prev.show_zombie(z, 0.62)
					pics.add_child(UIKit.label(TranslationServer.translate(z.name_key), 18, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(pics)
		sc.add_child(h)
		tabs.add_child(sc)
	v.add_child(tabs)
	p.add_child(v)
	return p

## In-battle overlay version (pause menu).
static func popup() -> Control:
	var holder := UIKit.full(Control.new())
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	holder.add_child(UIKit.full(dim))
	var p := build_panel(func() -> void: holder.queue_free())
	holder.add_child(UIKit.centered(p))
	return holder
