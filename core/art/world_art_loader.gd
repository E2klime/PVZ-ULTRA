class_name WorldArtLoader
extends RefCounted
## Resolves the world of a level and loads its WorldArtConfig. There is no silent fallback:
## an unknown world or a missing config logs a loud error and returns the debug placeholder
## config (magenta checker ground), so missing art is obvious in game and in tests.

const ROOT := "res://assets/art/worlds/%s/world_art.tres"
const WORLDS: Array[StringName] = [&"lawn", &"pool", &"night", &"desert", &"roof", &"frost", &"factory", &"moon"]

static func world_key(level: LevelData) -> StringName:
	if level == null:
		push_error("WorldArtLoader: null level - no world art")
		return &""
	var w := String(level.world_id)
	if w == "":
		w = String(level.id).get_slice("_", 0)
	return StringName(w)

static func load_for(level: LevelData) -> WorldArtConfig:
	return load_world(world_key(level))

static func load_world(world: StringName) -> WorldArtConfig:
	var path := ROOT % world
	var cfg: WorldArtConfig = load(path) as WorldArtConfig if ResourceLoader.exists(path) else null
	if cfg == null:
		push_error("WorldArtLoader: MISSING world art for '%s' (%s) - run tools/art/build_all.py --only worlds" % [world, path])
		return placeholder()
	return cfg

static func placeholder() -> WorldArtConfig:
	var cfg := WorldArtConfig.new()
	cfg.ground = KitStyles.placeholder_texture(140)
	cfg.environment = KitStyles.placeholder_texture(64)
	cfg.ground_type = &"missing"
	return cfg
