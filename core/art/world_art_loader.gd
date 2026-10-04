class_name WorldArtLoader
extends RefCounted
## Resolves the world of a level and loads its WorldArtConfig (falls back to lawn).

const ROOT := "res://assets/art/worlds/%s/world_art.tres"
const FALLBACK := &"lawn"

static func world_key(level: LevelData) -> StringName:
	if level == null:
		return FALLBACK
	var w := String(level.world_id)
	if w == "":
		w = String(level.id).get_slice("_", 0)
	return StringName(w) if ResourceLoader.exists(ROOT % w) else FALLBACK

static func load_for(level: LevelData) -> WorldArtConfig:
	return load_world(world_key(level))

static func load_world(world: StringName) -> WorldArtConfig:
	var path := ROOT % world
	if not ResourceLoader.exists(path):
		path = ROOT % FALLBACK
	return load(path) as WorldArtConfig
