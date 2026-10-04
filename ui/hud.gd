class_name BattleHUD
extends CanvasLayer
## Battle UI: vertical seed bank (left), sun counter (top-left), wave
## progress + level name (top-centre), coins / speed / pause (top-right),
## glove + shovel (bottom-right), tools & objectives (bottom), overlays.

var battle: Battle
var root: Control
var sun_label: Label
var bank: VBoxContainer
var bank_panel: PanelContainer
var cards: Array[SeedPacket] = []
var shovel_btn: RoundTool
var glove_btn: RoundTool
var mower_btn: Button
var hybrid_label: Label
var wave_bar: WaveProgress
var level_label: Label
var banner_label: Label
var toast_label: Label
var hover_label: Label
var speed_btn: RoundTool
var coins_label: Label
var integrity_label: Label
var fps_label: Label
var info_panel: PanelContainer
var _info_label: Label
var _info_t: float = 0.0
var _battle_speed: float = 1.0
var _overlay_layer: Control
var _banner_tw: Tween
var _toast_tw: Tween
var _sun_icon: TextureRect
var _sun_pill: PanelContainer

const UI := "res://assets/ui/"

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = UIKit.full(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_bottom()
	_build_messages()
	_overlay_layer = UIKit.full(Control.new())
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay_layer)
	update_sun()
	EventBus.quest_ready.connect(_on_quest_ready)

## Walnut pill with a brass rim (HUD counters, menu profile chip).
static func pill() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.kit("pill"))
	return p

static func outlined(text: String, size: int, col: Color = Color.WHITE, outline: Color = Color(0.1, 0.07, 0.03)) -> Label:
	var l := UIKit.label(text, size, col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	return l

func _build_top_left() -> void:
	_sun_pill = pill()
	_sun_pill.position = Vector2(8, 8)
	_sun_pill.custom_minimum_size = Vector2(240, 78)
	var h := UIKit.hbox(6)
	_sun_icon = TextureRect.new()
	_sun_icon.texture = load(UI + "sun.png")
	_sun_icon.custom_minimum_size = Vector2(64, 64)
	_sun_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sun_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sun_icon.pivot_offset = Vector2(32, 32)
	h.add_child(_sun_icon)
	sun_label = outlined("0", 44, Color(1.0, 0.95, 0.75))
	sun_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(sun_label)
	_sun_pill.add_child(h)
	root.add_child(_sun_pill)
	bank_panel = PanelContainer.new()
	bank_panel.add_theme_stylebox_override("panel", UITheme.kit("board_small", 10))
	bank_panel.position = Vector2(4, 94)
	bank = UIKit.vbox(4)
	bank_panel.add_child(bank)
	bank_panel.visible = false
	root.add_child(bank_panel)

func _build_top_center() -> void:
	var p := pill()
	var v := UIKit.vbox(0)
	level_label = outlined(_level_title(), 22, Color(1.0, 0.95, 0.8))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(level_label)
	wave_bar = WaveProgress.new()
	wave_bar.director = battle.director
	wave_bar.custom_minimum_size = Vector2(520, 44)
	v.add_child(wave_bar)
	p.add_child(v)
	p.position = Vector2(960 - 280, 6)
	p.custom_minimum_size = Vector2(560, 0)
	root.add_child(p)
	var info := UIKit.hbox(14)
	info.position = Vector2(960 - 280, 104)
	info.custom_minimum_size = Vector2(560, 0)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	integrity_label = outlined("", 20, Color(1, 0.7, 0.65))
	info.add_child(integrity_label)
	hybrid_label = outlined("", 20, Color(0.85, 1, 0.75))
	info.add_child(hybrid_label)
	root.add_child(info)

func _level_title() -> String:
	var t := Loc.title(battle.level.name_key)
	if battle.diff:
		t += "  ·  " + tr(battle.diff.name_key)
	return t

func _build_top_right() -> void:
	var h := UIKit.hbox(10)
	h.position = Vector2(1500, 10)
	var cp := pill()
	cp.custom_minimum_size = Vector2(170, 70)
	var ch := UIKit.hbox(4)
	var ci := TextureRect.new()
	ci.texture = load(UI + "coin.png")
	ci.custom_minimum_size = Vector2(50, 50)
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ch.add_child(ci)
	coins_label = outlined(str(SaveManager.coins()), 30, Color(1, 0.9, 0.5))
	ch.add_child(coins_label)
	cp.add_child(ch)
	h.add_child(cp)
	speed_btn = RoundTool.new(load(UI + "speed.png"), 76, Color(0.35, 0.6, 0.85))
	speed_btn.pressed.connect(toggle_speed)
	h.add_child(speed_btn)
	var pause := RoundTool.new(load(UI + "pause.png"), 76, Color(0.4, 0.68, 0.3))
	pause.pressed.connect(toggle_pause)
	h.add_child(pause)
	root.add_child(h)
	EventBus.coins_changed.connect(_on_coins_changed)
	fps_label = outlined("", 18)
	fps_label.position = Vector2(1840, 92)
	root.add_child(fps_label)

func _build_bottom() -> void:
	glove_btn = RoundTool.new(load(UI + "glove.png"), 118, Color(0.85, 0.55, 0.25))
	glove_btn.position = Vector2(1640, 946)
	glove_btn.label = "G"
	glove_btn.pressed.connect(func() -> void: battle.toggle_glove())
	glove_btn.visible = false
	root.add_child(glove_btn)
	shovel_btn = RoundTool.new(load(UI + "shovel.png"), 118, Color(0.55, 0.45, 0.35))
	shovel_btn.position = Vector2(1782, 946)
	shovel_btn.label = "Q"
	shovel_btn.pressed.connect(_on_shovel_down)
	shovel_btn.visible = false
	root.add_child(shovel_btn)
	mower_btn = UIKit.button("", _on_mower_kit, 240, 20)
	mower_btn.custom_minimum_size.y = 48
	mower_btn.position = Vector2(1380, 1010)
	root.add_child(mower_btn)
	update_mower_button()
	update_base_integrity()
	info_panel = UIKit.panel(10)
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_label = UIKit.label("", 20)
	info_panel.add_child(_info_label)
	root.add_child(info_panel)

func _on_coins_changed(n: int) -> void:
	coins_label.text = str(n)

func _on_shovel_down() -> void:
	if battle.shovel:
		battle.deselect()
	else:
		battle.toggle_shovel(bool(Settings.get_value(&"drag_to_plant")))
	Sfx.play(&"click")

func _on_quest_ready(id: StringName) -> void:
	var q := DB.quest(id)
	if q:
		toast(tr("MSG_QUEST_DONE").format({"name": tr(q.title_key)}))

func _on_mower_kit() -> void:
	if battle.restore_mower():
		update_mower_button()

func _build_messages() -> void:
	banner_label = UIKit.title("", 72)
	banner_label.position = Vector2(160, 420)
	banner_label.size = Vector2(1600, 180)
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	banner_label.add_theme_color_override("font_outline_color", Color(0.45, 0.1, 0.05))
	banner_label.add_theme_constant_override("outline_size", 16)
	banner_label.modulate.a = 0.0
	banner_label.pivot_offset = Vector2(800, 90)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_label)
	toast_label = UIKit.label("", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_outline_color", Color(0.4, 0.05, 0.05))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.position = Vector2(0, 930)
	toast_label.size = Vector2(1920, 50)
	toast_label.modulate.a = 0.0
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)
	hover_label = UIKit.label("", 22, Color.WHITE)
	hover_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.05))
	hover_label.add_theme_constant_override("outline_size", 7)
	hover_label.add_theme_stylebox_override("normal", UITheme.kit("pill", 14))
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hover_label)

# --- seed bank ---------------------------------------------------------------
func on_battle_started() -> void:
	for c: SeedPacket in cards:
		c.queue_free()
	cards.clear()
	var n := battle.seeds.size()
	var h := clampf((960.0 - 4.0 * n) / maxf(1.0, n), 64.0, 92.0)
	for i: int in n:
		var card := SeedPacket.new(battle.seeds[i].data, i, Vector2(236, h))
		card.hotkey = str((i + 1) % 10) if i < 10 else ""
		card.pressed.connect(func(c: SeedPacket) -> void:
			battle.select_seed(c.index, bool(Settings.get_value(&"drag_to_plant")))
			Sfx.play(&"click")
			Settings.haptic(12))
		bank.add_child(card)
		cards.append(card)
	bank_panel.visible = n > 0
	shovel_btn.visible = true
	glove_btn.visible = true
	var spd := float(Settings.get_value(&"default_speed"))
	if spd > 1.0 and _battle_speed < 2.0:
		toggle_speed()
	refresh_selection()

func refresh_selection() -> void:
	for c: SeedPacket in cards:
		c.queue_redraw()
	if shovel_btn:
		shovel_btn.active = battle.shovel
		glove_btn.active = battle.glove
		shovel_btn.queue_redraw()
		glove_btn.queue_redraw()

func _process(delta: float) -> void:
	if battle == null:
		return
	for i: int in cards.size():
		var s := battle.seeds[i]
		cards[i].set_state(battle.selected == i, s.progress(), battle.sun >= s.data.cost)
	var cap := battle.level.hybrid_cap if (battle.level.allow_hybrids and SaveManager.has_feature(&"graft")) else 0
	hybrid_label.text = tr("HUD_HYBRIDS").format({"n": battle.hybrid_count(), "max": cap}) if cap > 0 else ""
	glove_btn.cooldown = battle.glove_cd / maxf(0.01, battle.glove_cd_max)
	glove_btn.queue_redraw()
	fps_label.visible = bool(Settings.get_value(&"show_fps"))
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if _info_t > 0.0:
		_info_t -= delta
		if _info_t <= 0.0:
			info_panel.visible = false

func update_sun() -> void:
	if sun_label and battle:
		var old := sun_label.text
		sun_label.text = str(battle.sun)
		if old != sun_label.text and old != "0" and int(old) < battle.sun:
			var tw := create_tween()
			_sun_icon.scale = Vector2(1.25, 1.25)
			tw.tween_property(_sun_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func update_base_integrity() -> void:
	if integrity_label and battle:
		integrity_label.visible = battle.level.mode == &"holdout" or battle.base_integrity < battle.max_base_integrity
		integrity_label.text = tr("HUD_BASE_INTEGRITY").format({"n": battle.base_integrity, "max": battle.max_base_integrity})

func toggle_speed() -> void:
	if battle.phase != Battle.Phase.PLAYING:
		return
	_battle_speed = 2.0 if _battle_speed < 2.0 else 1.0
	Engine.time_scale = _battle_speed
	speed_btn.active = _battle_speed > 1.0
	speed_btn.queue_redraw()
	Sfx.play(&"click")

func update_mower_button() -> void:
	if mower_btn == null:
		return
	var kits := SaveManager.purchased(&"mower_kit")
	mower_btn.text = tr("HUD_MOWER_KIT").format({"n": kits})
	mower_btn.visible = kits > 0 and battle.level.mowers
	mower_btn.disabled = not battle.has_used_mower()

func sun_icon_screen_pos() -> Vector2:
	return _sun_icon.global_position + _sun_icon.size * 0.5

## Tap on a plant without a tool: name, health and layer.
func show_plant_info(p: Plant) -> void:
	var t := "%s\n%s %d / %d" % [tr(p.data.name_key), tr("UI_HEALTH"), int(p.hp), int(p.max_hp_now())]
	if p.data.layer != &"main":
		t += "\n" + tr("LAYER_" + String(p.data.layer).to_upper())
	if p.data.badge != "":
		t += "\n" + Loc.text(p.data.badge)
	_info_label.text = t
	info_panel.visible = true
	info_panel.size = Vector2.ZERO
	var pos := battle.world.get_global_transform_with_canvas() * (p.position + Vector2(50, -170 - p.hover_height()))
	info_panel.position = Vector2(clampf(pos.x, 260, 1600), clampf(pos.y, 130, 900))
	_info_t = 2.5

# --- messages ------------------------------------------------------------------
func banner(text: String, duration: float = 2.5) -> void:
	banner_label.text = text
	if _banner_tw:
		_banner_tw.kill()
	banner_label.scale = Vector2(1.6, 1.6)
	banner_label.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(banner_label, "modulate:a", 1.0, 0.2)
	_banner_tw.tween_property(banner_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(duration)
	_banner_tw.chain().tween_property(banner_label, "modulate:a", 0.0, 0.5)

func toast(text: String) -> void:
	toast_label.text = text
	if _toast_tw:
		_toast_tw.kill()
	toast_label.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(1.2)
	_toast_tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)

func set_hover_info(text: String, ok: bool, world_pos: Vector2) -> void:
	hover_label.text = text
	hover_label.visible = text != "" and bool(Settings.get_value(&"show_hints"))
	if hover_label.visible:
		hover_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7) if ok else Color(1.0, 0.75, 0.7))
		hover_label.position = world_pos + Vector2(36, 20)
		hover_label.size = Vector2.ZERO
		if hover_label.position.x > 1500:
			hover_label.position.x -= 420

# --- overlays ----------------------------------------------------------------
func _clear_overlay() -> void:
	for c: Node in _overlay_layer.get_children():
		c.queue_free()

func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.5)
	UIKit.full(d)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(d)
	return d

func open_seed_select() -> void:
	_clear_overlay()
	var sel := SeedSelect.new()
	sel.level = battle.level
	sel.confirmed.connect(_on_seeds_confirmed)
	sel.cancelled.connect(func() -> void: GameState.goto(GameState.back_screen()))
	_overlay_layer.add_child(sel)

func _on_seeds_confirmed(ids: Array[StringName]) -> void:
	_clear_overlay()
	battle.begin(ids)
	banner(tr("HUD_READY_SET_PLANT"), 1.2)

func toggle_pause() -> void:
	if battle.phase != Battle.Phase.PLAYING:
		return
	if get_tree().paused:
		get_tree().paused = false
		Engine.time_scale = _battle_speed
		_clear_overlay()
		return
	Sfx.play(&"pause")
	Engine.time_scale = 1.0
	get_tree().paused = true
	battle.deselect()
	_clear_overlay()
	_dim()
	var p := UIKit.panel(30)
	p.custom_minimum_size = Vector2(560, 0)
	var v := UIKit.vbox(14)
	v.add_child(UIKit.label(tr("HUD_PAUSED"), 48, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(_level_title(), 22, UITheme.INK.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.button(tr("UI_RESUME"), toggle_pause, 420))
	v.add_child(UIKit.button(tr("UI_RESTART"), func() -> void: GameState.goto(&"battle"), 420))
	v.add_child(SettingsScreen.quick_panel())
	v.add_child(UIKit.button(tr("UI_HELP"), func() -> void: _overlay_layer.add_child(HelpScreen.popup()), 420))
	v.add_child(UIKit.button(tr("UI_TO_MAP"), func() -> void: GameState.goto(GameState.back_screen()), 420))
	for c: Node in v.get_children():
		if c is Button:
			(c as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(v)
	_overlay_layer.add_child(UIKit.centered(p))

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.keycode == KEY_P or (k.keycode == KEY_ESCAPE and battle.selected < 0 and not battle.shovel and not battle.glove)):
		toggle_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and battle and battle.phase == Battle.Phase.PLAYING:
		toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and battle and battle.phase == Battle.Phase.PLAYING and not get_tree().paused and OS.has_feature("mobile"):
		toggle_pause()

func show_result(result: Dictionary) -> void:
	_clear_overlay()
	_dim()
	var won: bool = result.get("won", false)
	Sfx.play(&"win" if won else &"lose")
	var p := UIKit.panel(36)
	p.custom_minimum_size = Vector2(680, 0)
	var v := UIKit.vbox(14)
	var head := UIKit.title(tr("RESULT_WIN") if won else tr("RESULT_LOSE"), 64)
	if not won:
		head.add_theme_color_override("font_outline_color", Color(0.45, 0.08, 0.05))
	v.add_child(head)
	if result.has("endless_wave"):
		v.add_child(UIKit.label(tr("ENDLESS_REACHED").format({"n": result["endless_wave"], "best": SaveManager.get_extra("endless_best", 0)}), 30, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if won:
		if result.get("campaign_complete", false):
			v.add_child(UIKit.wrap(tr("RESULT_CAMPAIGN_DONE"), 26))
		if result.get("star", false):
			v.add_child(UIKit.label(tr("RESULT_STAR"), 30, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
		var rh := UIKit.hbox(12)
		rh.alignment = BoxContainer.ALIGNMENT_CENTER
		var ci := TextureRect.new()
		ci.texture = load(UI + "coin.png")
		ci.custom_minimum_size = Vector2(44, 44)
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rh.add_child(ci)
		rh.add_child(UIKit.label(tr("RESULT_COINS").format({"n": result.get("coins", 0)}), 30))
		v.add_child(rh)
		if result.has("materials") and not (result["materials"] as Dictionary).is_empty():
			var mats: PackedStringArray = []
			for k: String in result["materials"]:
				if int(result["materials"][k]) > 0:
					mats.append("%s ×%d" % [tr("MAT_" + k.to_upper()), int(result["materials"][k])])
			if not mats.is_empty():
				v.add_child(UIKit.label(", ".join(mats), 22, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
		var plant_id: StringName = result.get("plant", &"")
		if plant_id != &"":
			var d := DB.plant(plant_id)
			var prev := EntityPreview.new(Vector2(220, 190))
			prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(prev)
			prev.show_plant(d, 1.1)
			v.add_child(UIKit.label(tr("RESULT_NEW_PLANT").format({"name": tr(d.name_key)}), 30, UITheme.LEAF_DARK, HORIZONTAL_ALIGNMENT_CENTER))
			v.add_child(UIKit.wrap(tr(d.desc_key), 20))
		var feat: StringName = result.get("feature", &"")
		if feat != &"":
			v.add_child(UIKit.wrap(tr("FEATURE_" + String(feat).to_upper()), 24))
		v.add_child(UIKit.button(tr("UI_CONTINUE"), func() -> void: GameState.goto(GameState.back_screen()), 380))
	else:
		v.add_child(UIKit.wrap(str(result.get("failure", "")) if result.get("failure", "") != "" else tr("RESULT_LOSE_DESC"), 26))
		v.add_child(UIKit.button(tr("UI_RETRY"), func() -> void: GameState.goto(&"battle"), 380))
		v.add_child(UIKit.button(tr("UI_TO_MAP"), func() -> void: GameState.goto(GameState.back_screen()), 380))
	for c: Node in v.get_children():
		if c is Button:
			(c as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(v)
	var c := UIKit.centered(p)
	_overlay_layer.add_child(c)
	p.scale = Vector2(0.8, 0.8)
	p.pivot_offset = Vector2(340, 220)
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Round icon button (shovel, glove, speed, pause) with active ring and cooldown sweep.
class RoundTool:
	extends Control
	signal pressed
	var icon: Texture2D
	var diameter: float = 100.0
	var color: Color = Color(0.4, 0.6, 0.3)
	var active: bool = false
	var cooldown: float = 0.0
	var label: String = ""
	const DISC: Texture2D = preload("res://assets/ui/kit/round_disc.png")
	const RING: Texture2D = preload("res://assets/ui/kit/round_ring.png")
	const GLOW: Texture2D = preload("res://assets/ui/kit/round_glow.png")
	func _init(tex: Texture2D, d: float, c: Color) -> void:
		icon = tex
		diameter = d
		color = c
		custom_minimum_size = Vector2(d, d)
		size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit()
			accept_event()
	func _draw() -> void:
		var c := size * 0.5
		var r := diameter * 0.5 - 3.0
		var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_circle(c + Vector2(3, 6), r * 0.96, Color(0.05, 0.08, 0.12, 0.3))
		draw_texture_rect(DISC, box, false, (color.lightened(0.15) if active else color).lerp(Color.WHITE, 0.25))
		draw_texture_rect(RING, box, false)
		if icon:
			var s := diameter * 0.62
			draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		if cooldown > 0.0:
			var pts := PackedVector2Array([c])
			for i: int in 33:
				var a := -PI / 2.0 + TAU * cooldown * float(i) / 32.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 0.74))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
		if active:
			var a := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
			draw_texture_rect(GLOW, box.grow(r * 0.125), false, Color(1, 1, 1, a))
		if label != "" and not OS.has_feature("mobile"):
			draw_string(get_theme_default_font(), Vector2(c.x + r * 0.45, c.y + r * 0.95), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
