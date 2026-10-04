class_name CampaignProgress
extends RefCounted

static func world_unlocked(id: StringName) -> bool:
	var map := DB.map(id)
	if map == null:
		return false
	return map.previous_world == &"" or world_cleared(map.previous_world)

static func world_cleared(id: StringName) -> bool:
	var map := DB.map(id)
	if map == null:
		return false
	for node: MapNodeData in map.nodes:
		if not SaveManager.has_star(node.level_id):
			return false
	return true

static func level_unlocked(id: StringName) -> bool:
	var level := DB.level(id)
	if level == null or not world_unlocked(level.world_id):
		return false
	return level.ordinal == 1 or SaveManager.has_star(StringName("%s_%02d" % [level.world_id, level.ordinal - 1]))

static func cleared_count(id: StringName) -> int:
	var n := 0
	for node: MapNodeData in DB.map(id).nodes:
		if SaveManager.has_star(node.level_id):
			n += 1
	return n

static func finished() -> bool:
	for id: String in CampaignLoader.WORLDS:
		if not world_cleared(StringName(id)):
			return false
	return true
