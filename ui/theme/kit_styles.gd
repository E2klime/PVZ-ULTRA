class_name KitStyles
extends RefCounted
## Loads painted 9-slice StyleBoxTextures from assets/ui/kit/styles (built by tools/art/ui/build_ui.py).
## Missing art is never hidden: it logs a loud error and returns an obvious magenta placeholder.

const DIR := "res://assets/ui/kit/styles/"
const TEX_DIR := "res://assets/ui/kit/"
const MISSING := Color(1.0, 0.0, 1.0)
static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

## Fresh copy of a kit style so callers may tweak margins/modulate safely.
static func get_style(kit_name: String, content: int = -1, tint: Color = Color.WHITE) -> StyleBox:
	var base: StyleBox = _cache.get(kit_name)
	if base == null:
		var path := DIR + kit_name + ".tres"
		if ResourceLoader.exists(path):
			base = load(path)
		if base == null:
			push_error("KitStyles: MISSING UI style '%s' (%s) - rebuild with tools/art/build_all.py --only ui" % [kit_name, path])
			base = placeholder_box()
		_cache[kit_name] = base
	var s: StyleBox = base.duplicate()
	if content >= 0:
		s.set_content_margin_all(content)
	if s is StyleBoxTexture:
		(s as StyleBoxTexture).modulate_color = tint
	return s

static func texture(tex_name: String) -> Texture2D:
	var cached: Texture2D = _tex_cache.get(tex_name)
	if cached != null:
		return cached
	var path := TEX_DIR + tex_name + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		push_error("KitStyles: MISSING UI texture '%s' (%s)" % [tex_name, path])
		tex = placeholder_texture(32)
	_tex_cache[tex_name] = tex
	return tex

static func placeholder_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = MISSING
	s.border_color = Color.BLACK
	s.set_border_width_all(4)
	s.set_content_margin_all(8)
	return s

## Magenta/black checker: impossible to mistake for real art.
static func placeholder_texture(px: int) -> Texture2D:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var half := maxi(1, px / 4)
	for y: int in px:
		for x: int in px:
			img.set_pixel(x, y, MISSING if ((x / half) + (y / half)) % 2 == 0 else Color.BLACK)
	return ImageTexture.create_from_image(img)
