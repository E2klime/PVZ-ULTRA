class_name HubWorldCard
extends Button
## One world on the hub: framed thumbnail of its real battlefield, name, progress and status.

const SIZE := Vector2(420, 330)
const THUMB := "res://assets/ui/kit/thumbs/%s.jpg"

func _init(map: MapData, playable: bool, status: String) -> void:
	custom_minimum_size = SIZE
	disabled = not playable
	focus_mode = Control.FOCUS_ALL
	var tint := Color.WHITE if playable else Color(0.78, 0.76, 0.74)
	add_theme_stylebox_override("normal", UITheme.kit("panel", 18, tint))
	add_theme_stylebox_override("hover", UITheme.kit("packet_hover", 18))
	add_theme_stylebox_override("pressed", UITheme.kit("panel", 18, Color(0.9, 0.88, 0.84)))
	add_theme_stylebox_override("disabled", UITheme.kit("panel", 18, tint))
	add_theme_stylebox_override("focus", UITheme.kit("button_focus"))
	var v := UIKit.vbox(6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22; v.offset_top = 20; v.offset_right = -22; v.offset_bottom = -18
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.kit("board_small", 5))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb := TextureRect.new()
	thumb.texture = _thumb(map)
	thumb.custom_minimum_size = Vector2(0, 178)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not playable:
		thumb.modulate = Color(0.45, 0.45, 0.5)
	frame.add_child(thumb)
	v.add_child(frame)
	var name_l := UIKit.fit_label(Loc.text(map.name_key), 24, SIZE.x - 50, UITheme.INK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	bar.max_value = maxf(1.0, float(map.nodes.size()))
	bar.value = CampaignProgress.cleared_count(map.id)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var st := UIKit.wrap(status, 17, UITheme.INK.lightened(0.15) if playable else Color(0.45, 0.2, 0.12))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	for c: Node in v.get_children():
		if c is Control: (c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)

static func _thumb(map: MapData) -> Texture2D:
	var key := &"lawn"
	if not map.nodes.is_empty():
		for n: MapNodeData in map.nodes:
			if n.level_id != &"" and DB.level(n.level_id):
				key = WorldArtLoader.world_key(DB.level(n.level_id))
				break
	var path := THUMB % key
	return load(path) if ResourceLoader.exists(path) else load(THUMB % "lawn")
