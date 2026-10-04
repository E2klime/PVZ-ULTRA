class_name Rig
extends RefCounted
## Painted cut-out rig: part textures + pivots exported by tools/art/paint/*.py.
##
## Plants: rig.json "parts" is a list (name, parent, z, pos, offset, size). Each
## part's pivot sits at `pos` relative to its parent's pivot (root = the feet).
## Zombies: "parts" is a dict (name -> offset, size); zombie.gd places pivots
## with its limb kinematics.
## Textures are painted at 2x and drawn at `scale` (0.5) so they stay crisp.

static var _cache: Dictionary = {}

var dir: String
var scale: float = 0.5
var parts: Dictionary = {}       # name -> Dictionary(tex, offset, size, pos, parent, z)
var draw_order: Array[StringName] = []
var chain_order: Array[StringName] = []
var meta: Dictionary = {}

static func plant(id: StringName) -> Rig:
	return _load_cached("res://assets/sprites/plants/%s" % id)

static func zombie(id: StringName) -> Rig:
	return _load_cached("res://assets/sprites/zombies/%s" % id)

static func _load_cached(path: String) -> Rig:
	if _cache.has(path):
		return _cache[path]
	var r: Rig = null
	var json_path := path + "/rig.json"
	if FileAccess.file_exists(json_path):
		r = Rig.new()
		r._load(path, json_path)
	_cache[path] = r
	return r

func _load(path: String, json_path: String) -> void:
	dir = path
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	scale = float(info.get("scale", 0.5))
	meta = info.get("meta", {})
	var raw: Variant = info["parts"]
	var list: Array = []
	if raw is Dictionary:
		for n: String in raw.keys():
			var d: Dictionary = raw[n]
			d["name"] = n
			list.append(d)
	else:
		list = raw
	for d: Dictionary in list:
		var n := StringName(d["name"])
		var tex: Texture2D = load(path + "/" + String(n) + ".png")
		var off: Array = d.get("offset", [0, 0])
		var sz: Array = d.get("size", [1, 1])
		var pos: Array = d.get("pos", [0, 0])
		parts[n] = {
			"tex": tex,
			"rect": Rect2(Vector2(off[0], off[1]) * scale, Vector2(sz[0], sz[1]) * scale),
			"pos": Vector2(pos[0], pos[1]) * scale,
			"parent": StringName(d.get("parent", "")),
			"z": int(d.get("z", 0)),
		}
	# parents before children
	var done: Dictionary = {}
	while chain_order.size() < parts.size():
		var progressed := false
		for n: StringName in parts.keys():
			if done.has(n):
				continue
			var par: StringName = parts[n]["parent"]
			if par == &"" or done.has(par) or not parts.has(par):
				chain_order.append(n)
				done[n] = true
				progressed = true
		if not progressed:
			break
	draw_order = chain_order.duplicate()
	draw_order.sort_custom(func(a: StringName, b: StringName) -> bool: return int(parts[a]["z"]) < int(parts[b]["z"]))

func has(n: StringName) -> bool:
	return parts.has(n)

func pos(n: StringName) -> Vector2:
	return parts[n]["pos"] if parts.has(n) else Vector2.ZERO

func parent(n: StringName) -> StringName:
	return parts[n]["parent"] if parts.has(n) else &""

func meta_vec(key: String, fallback: Vector2) -> Vector2:
	var v: Variant = meta.get(key)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(v[0], v[1])
	return fallback

## Draws part `n` with its pivot placed by `xf` (in the canvas item's space).
func draw(ci: CanvasItem, n: StringName, xf: Transform2D, mod: Color = Color.WHITE) -> void:
	var p: Dictionary = parts.get(n, {})
	if p.is_empty():
		return
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect(p["tex"], p["rect"], false, mod)

func size(n: StringName) -> Vector2:
	return (parts[n]["rect"] as Rect2).size if parts.has(n) else Vector2.ZERO

## Draws the whole plant rig at rest (no per-part animation): fusion bubbles, icons.
func draw_static(ci: CanvasItem, base: Transform2D, mod: Color = Color.WHITE) -> void:
	var world: Dictionary = {}
	for n: StringName in chain_order:
		var par := parent(n)
		var pw: Transform2D = world[par] if par != &"" and world.has(par) else base
		world[n] = pw * Transform2D(0.0, pos(n))
	for n: StringName in draw_order:
		if n in [&"lids", &"buried", &"body_1", &"body_2", &"light"]:
			continue
		draw(ci, n, world[n], mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
