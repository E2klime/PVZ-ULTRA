class_name CampaignLoader
extends RefCounted
## Read explicit, versioned world manifests. No runtime level randomization.
const WORLDS := ["lawn", "pool", "night", "desert", "roof", "frost", "factory", "moon"]

static func populate(db: Node) -> void:
	db.levels.clear()
	db.maps.clear()
	for world_id: String in WORLDS:
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign/%s.json" % world_id))
		var map := MapData.new()
		map.id = StringName(world_id)
		map.name_key = str(raw["name"])
		map.available = true
		map.order = int(raw["order"])
		map.rule_text = str(raw["rule_text"])
		map.tint = Color(str(raw["color"]))
		map.previous_world = StringName(str(raw.get("previous", "")))
		for entry: Dictionary in raw["levels"]:
			var level := LevelData.new()
			level.id = StringName(entry["id"])
			level.name_key = entry["title"]
			level.desc_key = entry["briefing"]
			level.hint_key = entry["joke"]
			level.world_id = map.id
			level.ordinal = int(entry["number"])
			level.mode = StringName(entry["mode"])
			level.field_rule = StringName(entry["field_rule"])
			level.water = PackedStringArray(entry["layout"])
			level.objectives.assign(entry["objectives"])
			level.wave_specs.assign(entry["wave_specs"])
			level.waves = level.wave_specs.size()
			level.zombie_pool.assign(_names(entry["zombie_pool"]))
			level.fixed_seeds.assign(_names(entry["fixed_seeds"]))
			level.banned_plants.assign(_names(entry["banned_plants"]))
			level.preplants.assign(entry["preplants"])
			level.start_sun = int(entry["start_sun"])
			level.sky_sun = bool(entry["sky_sun"])
			level.sky_sun_value = int(entry["sky_sun_value"])
			level.sky_sun_interval = float(entry["sky_sun_interval"])
			level.first_wave_delay = float(entry["first_wave_delay"])
			level.wave_interval = float(entry["wave_interval"])
			level.hybrid_cap = int(entry["hybrid_cap"])
			level.allow_hybrids = level.hybrid_cap > 0
			level.mowers = bool(entry["mowers"])
			level.reward_plant = StringName(entry["reward_plant"])
			level.reward_feature = StringName(entry["reward_feature"])
			level.reward_coins = int(entry["reward_coins"])
			level.material_rewards = entry["materials"]
			level.artillery_damage = float(entry.get("artillery_damage", 550.0))
			level.artillery_cooldown = float(entry.get("artillery_cooldown", 2.0))
			db.levels[level.id] = level
			var node := MapNodeData.new()
			node.id = level.id
			node.level_id = level.id
			var i := level.ordinal - 1
			var row := i / 5
			var col := i % 5 if row % 2 == 0 else 4 - i % 5
			node.position = Vector2(230 + col * 245, 215 + row * 165)
			if i < 24:
				node.next_ids.append(StringName("%s_%02d" % [world_id, i + 2]))
			map.nodes.append(node)
		map.start_node = map.nodes[0].id
		db.maps.append(map)

static func _names(values: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in values:
		out.append(StringName(str(v)))
	return out
