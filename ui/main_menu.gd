class_name MainMenu
extends Control
## Title screen: key art, logo, Adventure, Endless / Daily, and a dock with
## Almanac, Workshop, Shop, Quests, Stats, Help, Settings (and Quit on desktop).

const UI := "res://assets/ui/"

func _ready() -> void:
	UIKit.full(self)
	add_child(ScreenBg.for_screen(&"menu"))
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.03, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UIKit.full(shade))
	add_child(MenuAmbience.new())
	Sfx.play_music(&"menu")
	# logo
	var logo := TextureRect.new()
	logo.texture = load(UI + "logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(760, 262)
	logo.position = Vector2(580, 14)
	logo.pivot_offset = logo.size * 0.5
	add_child(logo)
	var bob := create_tween().set_loops()
	bob.tween_property(logo, "position:y", 22.0, 1.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(logo, "position:y", 10.0, 1.8).set_trans(Tween.TRANS_SINE)
	# profile pill
	var prof := BattleHUD.pill()
	prof.position = Vector2(18, 16)
	var ph := UIKit.hbox(10)
	ph.add_child(_icon(UI + "coin.png", 44))
	ph.add_child(BattleHUD.outlined(str(SaveManager.coins()), 28, Color(1, 0.9, 0.5)))
	ph.add_child(BattleHUD.outlined("   ★ %d" % SaveManager.stars(), 28, Color(1, 0.95, 0.6)))
	ph.add_child(BattleHUD.outlined("   " + tr("MENU_PROGRESS").format({"n": _campaign_count(), "max": DB.levels.size()}), 26, Color(0.85, 1, 0.75)))
	prof.add_child(ph)
	add_child(prof)
	# main column
	var v := UIKit.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.position = Vector2(700, 560)
	v.custom_minimum_size = Vector2(520, 0)
	var play := _big_button(tr("UI_ADVENTURE"), func() -> void: GameState.goto(&"hub"), Color(0.4, 0.75, 0.22), 520, 104, 46)
	v.add_child(play)
	var row := UIKit.hbox(16)
	row.add_child(_big_button(tr("MODE_ENDLESS"), func() -> void: GameState.start_endless(), Color(0.85, 0.5, 0.2), 252, 80, 28))
	var daily_done: bool = SaveManager.get_extra("daily_done", "") == GameState.daily_key()
	var daily := _big_button(tr("MODE_DAILY") + ("  ✔" if daily_done else "  !"), func() -> void: GameState.start_daily(), Color(0.35, 0.55, 0.9), 252, 80, 28)
	row.add_child(daily)
	v.add_child(row)
	var best := int(SaveManager.get_extra("endless_best", 0))
	var sub := BattleHUD.outlined(tr("MENU_ENDLESS_BEST").format({"n": best}) if best > 0 else tr("GAME_SUBTITLE"), 22, Color(1, 1, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	add_child(v)
	# dock
	var dock_bg := PanelContainer.new()
	var sb := UITheme.kit("board_small", 14)
	dock_bg.add_theme_stylebox_override("panel", sb)
	var dock := UIKit.hbox(14)
	var q := tr("UI_QUESTS")
	var n := SaveManager.claimable_quests()
	if n > 0:
		q += " (%d!)" % n
	var entries := [
		[tr("UI_ALMANAC"), "book", func() -> void: GameState.goto(&"almanac", {"back": &"menu"})],
		[tr("UI_WORKSHOP"), "hammer", func() -> void: GameState.goto(&"workshop", {"back": &"menu"})],
		[tr("UI_SHOP"), "cart", func() -> void: GameState.goto(&"shop", {"back": &"menu"})],
		[q, "scroll", func() -> void: GameState.goto(&"quests", {"back": &"menu"})],
		[tr("UI_STATS"), "chart", func() -> void: GameState.goto(&"stats", {"back": &"menu"})],
		[tr("UI_HELP"), "question", func() -> void: GameState.goto(&"help", {"back": &"menu"})],
		[tr("UI_SETTINGS"), "gear", func() -> void: GameState.goto(&"settings", {"back": &"menu"})],
	]
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		entries.append([tr("UI_QUIT"), "power", func() -> void: get_tree().quit()])
	for e: Array in entries:
		dock.add_child(_dock_button(e[0], e[1], e[2]))
	dock_bg.add_child(dock)
	add_child(dock_bg)
	dock_bg.reset_size()
	await get_tree().process_frame
	dock_bg.position = Vector2((1920 - dock_bg.size.x) * 0.5, 1080 - dock_bg.size.y - 16)
	play.grab_focus()
	v.modulate.a = 0.0
	create_tween().tween_property(v, "modulate:a", 1.0, 0.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not OS.has_feature("web"):
		get_tree().quit()

func _campaign_count() -> int:
	var n := 0
	for map: MapData in DB.maps:
		n += CampaignProgress.cleared_count(map.id)
	return n

func _icon(path: String, s: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.custom_minimum_size = Vector2(s, s)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t

static func _big_button(text: String, cb: Callable, col: Color, w: float, h: float, fs: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_constant_override("outline_size", 10)
	b.add_theme_color_override("font_outline_color", col.darkened(0.6))
	var fam := "button" if col.g >= col.r else "button_wood"
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var kit_name := fam if st == "normal" else (fam + "_" + st if st != "focus" else "button_focus")
		b.add_theme_stylebox_override(st, UITheme.kit(kit_name))
	b.pressed.connect(func() -> void:
		Sfx.play(&"click")
		cb.call())
	b.pivot_offset = Vector2(w, h) * 0.5
	b.mouse_entered.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.1))
	b.mouse_exited.connect(func() -> void: b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	return b

func _dock_button(text: String, icon_name: String, cb: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 124)
	b.text = text
	b.icon = load(UI + icon_name + ".png")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 60)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void:
		Sfx.play(&"click")
		cb.call())
	return b
