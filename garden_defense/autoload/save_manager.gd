extends Node
## Persistent progress in user://save.json (versioned).

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 5
const START_PLANTS: Array[String] = ["sunbud", "pod_shooter"]
const BASE_SLOTS := 6
const MAX_SLOTS := 10

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func _default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"coins": 0,
		"materials": {"compost": 0, "scrap": 0, "crystal": 0},
		"tools": {},
		"upgrades": {},
		"completed_nodes": [],
		"star_levels": [],
		"unlocked_plants": START_PLANTS.duplicate(),
		"features": [],
		"discovered_recipes": [],
		"hinted_recipes": [],
		"seen_zombies": [],
		"purchases": {},
		"equipped_skin": "",
		"stats": {},
		"quests_claimed": [],
		"best_difficulty": {},
		"current_nodes": {},
		"extra": {},
	}

func load_game() -> void:
	data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		# Keep the unreadable file for recovery instead of silently overwriting it.
		var keep := FileAccess.open("user://save.corrupt.json", FileAccess.WRITE)
		if keep: keep.store_string(text)
		push_warning("Save file unreadable; backed up to user://save.corrupt.json")
		return
	if parsed is Dictionary:
		var loaded: Dictionary = parsed
		if int(loaded.get("save_version", 0)) < SAVE_VERSION and not FileAccess.file_exists("user://save.pre_v05.json"):
			var backup := FileAccess.open("user://save.pre_v05.json", FileAccess.WRITE)
			if backup: backup.store_string(JSON.stringify(loaded, "\t"))
		# Sanitise before migrating so migrations can rely on field types too.
		for k: String in data.keys():
			if loaded.has(k):
				loaded[k] = _sanitized(k, loaded[k], data[k])
		loaded = _migrate(loaded)
		for k: String in data.keys():
			if loaded.has(k):
				data[k] = loaded[k]

## A hand-edited or partially written save must not crash the game: every field
## keeps its default type (numbers stay numbers, lists stay lists of strings, ...).
func _sanitized(key: String, value: Variant, fallback: Variant) -> Variant:
	match typeof(fallback):
		TYPE_INT, TYPE_FLOAT:
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				return maxi(0, int(value)) if key == "coins" else int(value)
			return fallback
		TYPE_STRING:
			return str(value) if value != null else fallback
		TYPE_ARRAY:
			if not value is Array:
				return fallback
			var out: Array = []
			for item: Variant in value:
				var text := str(item)
				if item != null and not text in out:
					out.append(text)
			return out
		TYPE_DICTIONARY:
			if not value is Dictionary:
				return fallback
			var merged: Dictionary = (fallback as Dictionary).duplicate(true)
			for k: Variant in value:
				var v: Variant = value[k]
				# Counter dictionaries (materials, tools, stats, ...) hold numbers only.
				if key in ["materials", "tools", "upgrades", "purchases", "stats", "best_difficulty"]:
					if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
						merged[str(k)] = int(v)
				elif key == "current_nodes":
					merged[str(k)] = str(v)
				else:
					merged[str(k)] = v
			return merged
	return value

func _migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("save_version", 0))
	if v < 2:
		var old_node := str(d.get("current_node", ""))
		d["current_nodes"] = {"lawn": old_node} if old_node != "" else {}
		d.erase("current_node")
	if v < 3:
		# Re-map legacy level-node IDs without granting unplayed levels or worlds.
		var done: Array = d.get("completed_nodes", [])
		for level_id: Variant in d.get("star_levels", []):
			if DB.level(StringName(str(level_id))) and not str(level_id) in done:
				done.append(str(level_id))
		d["completed_nodes"] = done
	if v < 4:
		# v0.7: grant newly added reward plants for levels the player already cleared.
		var plants: Array = d.get("unlocked_plants", [])
		for level_id: Variant in d.get("completed_nodes", []):
			var lv := DB.level(StringName(str(level_id)))
			if lv and lv.reward_plant != &"" and not String(lv.reward_plant) in plants:
				plants.append(String(lv.reward_plant))
		d["unlocked_plants"] = plants
	if v < 5:
		# v0.7 hybrids only: evolutions and star-ups were removed. Twin forms are
		# graft-only hybrids now, so drop them (and the old feature flag) from saves.
		var feats: Array = d.get("features", [])
		feats.erase("evolve")
		d["features"] = feats
		var owned: Array = d.get("unlocked_plants", [])
		for id: String in ["twin_pod", "twin_sunbud", "ironbark_wall"]:
			owned.erase(id)
		d["unlocked_plants"] = owned
	if v < SAVE_VERSION:
		d["save_version"] = SAVE_VERSION
	return d

## Free-form persistent values (endless best, daily challenge date, ...).
func get_extra(key: String, fallback: Variant = null) -> Variant:
	return (data.get("extra", {}) as Dictionary).get(key, fallback)

func set_extra(key: String, value: Variant) -> void:
	if not data.has("extra"):
		data["extra"] = {}
	data["extra"][key] = value

func save_game() -> void:
	# Write-then-rename so a crash mid-write never corrupts the only save.
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		# Some platforms refuse to rename over an existing file: replace it explicitly.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
		if err != OK:
			push_warning("Could not write save file (error %d)" % err)

func reset() -> void:
	data = _default_data()
	save_game()
	EventBus.coins_changed.emit(coins())
	EventBus.stars_changed.emit(stars())

# --- helpers for array-of-strings fields -------------------------------------
func _has(field: String, value: StringName) -> bool:
	var arr: Array = data[field]
	return String(value) in arr

func _add(field: String, value: StringName) -> bool:
	var arr: Array = data[field]
	if String(value) in arr:
		return false
	arr.append(String(value))
	return true

# --- coins & stars -----------------------------------------------------------
func coins() -> int:
	return int(data["coins"])

func add_coins(amount: int) -> void:
	data["coins"] = coins() + amount
	EventBus.coins_changed.emit(coins())

func spend_coins(amount: int) -> bool:
	if coins() < amount:
		return false
	data["coins"] = coins() - amount
	EventBus.coins_changed.emit(coins())
	return true

func stars() -> int:
	return (data["star_levels"] as Array).size()

func has_star(level_id: StringName) -> bool:
	return _has("star_levels", level_id)

func award_star(level_id: StringName) -> bool:
	var added := _add("star_levels", level_id)
	if added:
		EventBus.stars_changed.emit(stars())
	return added

# --- map ---------------------------------------------------------------------
func is_node_completed(node_id: StringName) -> bool:
	return _has("completed_nodes", node_id)

func complete_node(node_id: StringName) -> void:
	_add("completed_nodes", node_id)

func current_node(map_id: StringName = &"lawn") -> StringName:
	var nodes: Dictionary = data["current_nodes"]
	return StringName(str(nodes.get(String(map_id), "")))

func set_current_node(map_id: StringName, node_id: StringName) -> void:
	var nodes: Dictionary = data["current_nodes"]
	nodes[String(map_id)] = String(node_id)

func best_difficulty(level_id: StringName) -> int:
	var d: Dictionary = data["best_difficulty"]
	return int(d.get(String(level_id), -1))

func record_difficulty(level_id: StringName, order: int) -> void:
	var d: Dictionary = data["best_difficulty"]
	if order > best_difficulty(level_id):
		d[String(level_id)] = order

# --- unlocks -----------------------------------------------------------------
func is_plant_unlocked(id: StringName) -> bool:
	return _has("unlocked_plants", id)

func unlock_plant(id: StringName) -> bool:
	return _add("unlocked_plants", id)

func unlocked_plants() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Variant in data["unlocked_plants"]:
		out.append(StringName(str(s)))
	return out

func has_feature(f: StringName) -> bool:
	return _has("features", f)

func unlock_feature(f: StringName) -> bool:
	return _add("features", f)

func is_recipe_discovered(recipe_id: StringName) -> bool:
	return _has("discovered_recipes", recipe_id)

func discover_recipe(recipe_id: StringName) -> bool:
	var added := _add("discovered_recipes", recipe_id)
	if added:
		set_stat(&"recipes", (data["discovered_recipes"] as Array).size())
		EventBus.recipe_discovered.emit(recipe_id)
	return added

func is_recipe_hinted(recipe_id: StringName) -> bool:
	return _has("hinted_recipes", recipe_id)

## Reveals ingredients of a random unknown recipe. Returns its id or &"".
func grant_recipe_hint() -> StringName:
	var pool: Array[StringName] = []
	for r: FusionRecipe in DB.recipes:
		var rid := r.recipe_id()
		if not is_recipe_discovered(rid) and not is_recipe_hinted(rid):
			pool.append(rid)
	if pool.is_empty():
		return &""
	var pick: StringName = pool.pick_random()
	_add("hinted_recipes", pick)
	return pick

func hints_available() -> bool:
	for r: FusionRecipe in DB.recipes:
		var rid := r.recipe_id()
		if not is_recipe_discovered(rid) and not is_recipe_hinted(rid):
			return true
	return false

func is_zombie_seen(id: StringName) -> bool:
	return _has("seen_zombies", id)

func mark_zombie_seen(id: StringName) -> void:
	_add("seen_zombies", id)

# --- shop --------------------------------------------------------------------
func purchased(item_id: StringName) -> int:
	var p: Dictionary = data["purchases"]
	return int(p.get(String(item_id), 0))

func add_purchase(item_id: StringName, delta: int = 1) -> void:
	var p: Dictionary = data["purchases"]
	p[String(item_id)] = max(0, purchased(item_id) + delta)

func seed_slots() -> int:
	return min(MAX_SLOTS, BASE_SLOTS + purchased(&"extra_slot"))

## Permanent workshop upgrades (tiered). Effects are deliberately small and never required.
func upgrade_level(id: String) -> int:
	return int((data.get("upgrades", {}) as Dictionary).get(id, 0))

func add_upgrade(id: String) -> void:
	if not data.has("upgrades"): data["upgrades"] = {}
	data["upgrades"][id] = upgrade_level(id) + 1

func recharge_mult() -> float:
	return 1.0 - 0.05 * upgrade_level("sprinkler")

func opening_cooldown_mult() -> float:
	return 1.0 - 0.25 * upgrade_level("seed_pouch")

func sky_sun_bonus() -> int:
	return 5 * upgrade_level("sun_lens")

func bonus_start_sun() -> int:
	return 25 * purchased(&"start_sun")

func equipped_skin() -> StringName:
	return StringName(str(data["equipped_skin"]))

func equip_skin(id: StringName) -> void:
	data["equipped_skin"] = String(id)

# --- stats & quests ----------------------------------------------------------
func stat(name: StringName) -> int:
	var s: Dictionary = data["stats"]
	return int(s.get(String(name), 0))

func add_stat(name: StringName, delta: int = 1) -> void:
	set_stat(name, stat(name) + delta)

func set_stat(name: StringName, value: int) -> void:
	var s: Dictionary = data["stats"]
	var old := stat(name)
	s[String(name)] = value
	for q: QuestData in DB.quests:
		if q.stat == name and old < q.amount and value >= q.amount and not is_quest_claimed(q.id):
			EventBus.quest_ready.emit(q.id)

func quest_progress(q: QuestData) -> int:
	return min(stat(q.stat), q.amount)

func is_quest_claimed(id: StringName) -> bool:
	return _has("quests_claimed", id)

func claim_quest(q: QuestData) -> StringName:
	if is_quest_claimed(q.id) or stat(q.stat) < q.amount:
		return &""
	_add("quests_claimed", q.id)
	add_coins(q.reward_coins)
	var hint: StringName = &""
	if q.reward_hint:
		hint = grant_recipe_hint()
	save_game()
	return hint

func claimable_quests() -> int:
	var n := 0
	for q: QuestData in DB.quests:
		if not is_quest_claimed(q.id) and stat(q.stat) >= q.amount:
			n += 1
	return n


# --- workshop inventory -------------------------------------------------------
func material(id: String) -> int:
	return int((data["materials"] as Dictionary).get(id, 0))

func add_material(id: String, amount: int) -> void:
	data["materials"][id] = maxi(0, material(id) + amount)

func tool_count(id: String) -> int:
	return int((data["tools"] as Dictionary).get(id, 0))

func add_tool(id: String, amount: int) -> void:
	data["tools"][id] = clampi(tool_count(id) + amount, 0, 9)
