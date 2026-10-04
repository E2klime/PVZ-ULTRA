class_name FxSheet
extends Sprite2D
## Plays a horizontal sprite-sheet strip (rendered by tools/art/render_fx.sh from
## Inkscape sources). One-shot sheets free themselves; looping ones run until freed.

const SHEETS := {
	&"sparkle": ["res://assets/fx/sparkle_sheet.png", 8],
	&"flame": ["res://assets/fx/flame_sheet.png", 6],
	&"frost_burst": ["res://assets/fx/frost_burst_sheet.png", 6],
	&"lightning": ["res://assets/fx/lightning_sheet.png", 4],
	&"leaf": ["res://assets/fx/leaf_sheet.png", 4],
}

static var _cache: Dictionary = {}

var fps: float = 14.0
var loop: bool = false
var _t: float = 0.0

static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D
	return _cache[path]

static func sheet(id: StringName) -> Texture2D:
	return tex(SHEETS[id][0])

static func frames_of(id: StringName) -> int:
	return int(SHEETS[id][1])

## Region of frame i of sheet id (for drawing directly in _draw()).
static func frame_rect(id: StringName, i: int) -> Rect2:
	var t := sheet(id)
	var n := frames_of(id)
	var w := t.get_width() / float(n)
	return Rect2(w * float(posmod(i, n)), 0, w, t.get_height())

static func make(id: StringName, p_fps: float = 14.0, p_loop: bool = false) -> FxSheet:
	var s := FxSheet.new()
	s.texture = sheet(id)
	s.hframes = frames_of(id)
	s.fps = p_fps
	s.loop = p_loop
	return s

func _process(delta: float) -> void:
	_t += delta * fps
	var f := int(_t)
	if f >= hframes:
		if not loop:
			queue_free()
			return
		f = f % hframes
	frame = f
