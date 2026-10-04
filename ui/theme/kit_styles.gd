class_name KitStyles
extends RefCounted
## Loads painted 9-slice StyleBoxTextures from assets/ui/kit/styles (built by tools/art/ui/build_ui.py).

const DIR := "res://assets/ui/kit/styles/"
const TEX_DIR := "res://assets/ui/kit/"
static var _cache: Dictionary = {}

## Fresh copy of a kit style so callers may tweak margins/modulate safely.
static func get_style(kit_name: String, content: int = -1, tint: Color = Color.WHITE) -> StyleBox:
	var base: StyleBox = _cache.get(kit_name)
	if base == null:
		if ResourceLoader.exists(DIR + kit_name + ".tres"):
			base = load(DIR + kit_name + ".tres")
		else:
			base = StyleBoxEmpty.new()
		_cache[kit_name] = base
	var s: StyleBox = base.duplicate()
	if content >= 0:
		s.set_content_margin_all(content)
	if s is StyleBoxTexture:
		(s as StyleBoxTexture).modulate_color = tint
	return s

static func texture(tex_name: String) -> Texture2D:
	var path := TEX_DIR + tex_name + ".png"
	return load(path) if ResourceLoader.exists(path) else null
