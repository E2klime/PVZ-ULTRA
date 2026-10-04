extends Node
## Session state: which level is being played, with which seeds and difficulty.

var map_id: StringName = &"lawn"
var node_id: StringName = &""
var level_id: StringName = &""
var difficulty_id: StringName = &"standard"
var last_seeds: Array[StringName] = []
## Filled by Battle when a level ends; read by the result screen.
var last_result: Dictionary = {}
## Generated level for Endless / Daily Challenge (null = campaign level).
var custom_level: LevelData
var custom_kind: StringName = &""

func _ready() -> void:
	difficulty_id = Settings.default_difficulty

func difficulty() -> DifficultyData:
	return DB.difficulty(difficulty_id)

func level() -> LevelData:
	if custom_level:
		return custom_level
	return DB.level(level_id)

## Where "back"/"continue" leads from a battle.
func back_screen() -> StringName:
	return &"menu" if custom_level else &"map"

func start_campaign_level_cleanup() -> void:
	custom_level = null
	custom_kind = &""

## Endless Survival: escalating flag waves built from every zombie seen so far.
func start_endless(world: StringName = &"lawn") -> void:
	var lv := _base_custom(world)
	lv.id = &"endless"
	lv.name_key = "MODE_ENDLESS"
	lv.waves = 60
	lv.flag_every = 5
	lv.threat_base = 2.0
	lv.threat_growth = 1.25
	lv.first_wave_delay = 30.0
	lv.wave_interval = 30.0
	lv.start_sun = 150
	lv.hybrid_cap = 10
	lv.reward_coins = 0
	custom_kind = &"endless"
	custom_level = lv
	goto(&"battle")

## Daily Challenge: the date seeds the world, zombies, banned plants and twist.
func start_daily() -> void:
	var d := Time.get_date_dict_from_system()
	var seed_v := int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var worlds: Array[StringName] = []
	for m: MapData in DB.maps:
		if CampaignProgress.world_unlocked(m.id):
			worlds.append(m.id)
	if worlds.is_empty():
		worlds.append(&"lawn")
	var lv := _base_custom(worlds[rng.randi() % worlds.size()], rng)
	lv.id = &"daily"
	lv.name_key = "MODE_DAILY"
	lv.waves = 14
	lv.flag_every = 7
	lv.threat_base = 2.2
	lv.threat_growth = 1.0
	lv.start_sun = [50, 150, 300][rng.randi() % 3]
	lv.reward_coins = 0 if SaveManager.get_extra("daily_done", "") == daily_key() else 250
	# Bans must be the same for every attempt of the day: sort first and draw from the
	# date-seeded RNG (Array.shuffle() used the global RNG, so each retry differed and
	# could repeat a ban). Starter plants and the free raft are never banned.
	var candidates: Array[StringName] = []
	for id: StringName in SaveManager.unlocked_plants():
		if not String(id) in SaveManager.START_PLANTS and id != &"lily_raft":
			candidates.append(id)
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for i: int in mini(3, maxi(0, candidates.size() - 6)):
		lv.banned_plants.append(candidates.pop_at(rng.randi() % candidates.size()))
	custom_kind = &"daily"
	custom_level = lv
	goto(&"battle")

func daily_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

func _base_custom(world: StringName, rng: RandomNumberGenerator = null) -> LevelData:
	var lv := LevelData.new()
	lv.world_id = world
	lv.mode = &"defense"
	var pool: Array[StringName] = []
	for id: StringName in DB.ZOMBIE_ORDER:
		var z := DB.zombie(id)
		if z and SaveManager.is_zombie_seen(id) and z.tier <= 4 and not id in [&"flagbearer"]:
			pool.append(id)
	if pool.size() < 3:
		pool = [&"shambler", &"cone_head", &"bucket_head"] as Array[StringName]
	if rng:
		var picked: Array[StringName] = [&"shambler"]
		for i: int in 6:
			var z: StringName = pool[rng.randi() % pool.size()]
			if not picked.has(z):
				picked.append(z)
		pool = picked
	lv.zombie_pool = pool
	if world == &"pool":
		lv.water = PackedStringArray([".........", ".........", "..~~~~~~~", "..~~~~~~~", "........."])
	elif world == &"roof" or world == &"night":
		lv.sky_sun = world != &"night"
	return lv

func goto(screen: StringName, args: Dictionary = {}) -> void:
	EventBus.screen_requested.emit(screen, args)

func start_level(p_node_id: StringName, p_level_id: StringName) -> void:
	if not CampaignProgress.level_unlocked(p_level_id):
		return
	custom_level = null
	custom_kind = &""
	node_id = p_node_id
	level_id = p_level_id
	goto(&"battle")

## Applies rewards after a win. Returns a summary for the UI.
func finish_level(won: bool, lost_mower: bool, waves_reached: int = 0) -> Dictionary:
	var lvl := level()
	var diff := difficulty()
	var result := {"won": won, "star": false, "coins": 0, "plant": &"", "feature": &"", "first_clear": false}
	if custom_level:
		if custom_kind == &"endless":
			result["endless_wave"] = waves_reached
			if waves_reached > int(SaveManager.get_extra("endless_best", 0)):
				SaveManager.set_extra("endless_best", waves_reached)
			var c := waves_reached * 6
			SaveManager.add_coins(c)
			result["coins"] = c
		elif custom_kind == &"daily" and won and lvl.reward_coins > 0:
			SaveManager.set_extra("daily_done", daily_key())
			SaveManager.add_coins(lvl.reward_coins)
			result["coins"] = lvl.reward_coins
			SaveManager.add_stat(&"dailies")
		if won:
			SaveManager.add_stat(&"wins")
		SaveManager.save_game()
		last_result = result
		return result
	if won and lvl:
		var first := not SaveManager.has_star(lvl.id)
		result["first_clear"] = first
		SaveManager.complete_node(lvl.id)
		result["star"] = SaveManager.award_star(lvl.id)
		var base_coins := lvl.reward_coins if first else int(lvl.reward_coins * 0.4)
		var coins := int(round(base_coins * diff.coin_reward_mult))
		SaveManager.add_coins(coins)
		result["coins"] = coins
		var mats: Dictionary = {}
		for key: String in lvl.material_rewards:
			var replay_crystal := 1 if lvl.ordinal % 5 == 0 else 0  # milestone replays keep crystals farmable (slowly)
			var amount := int(lvl.material_rewards[key]) if first else (replay_crystal if key == "crystal" else 1)
			SaveManager.add_material(key, amount)
			mats[key] = amount
		result["materials"] = mats
		result["campaign_complete"] = CampaignProgress.finished()
		if lvl.reward_plant != &"" and SaveManager.unlock_plant(lvl.reward_plant):
			result["plant"] = lvl.reward_plant
		if lvl.reward_feature != &"" and SaveManager.unlock_feature(lvl.reward_feature):
			result["feature"] = lvl.reward_feature
		SaveManager.record_difficulty(lvl.id, diff.order)
		SaveManager.add_stat(&"wins")
		if diff.order > 0:
			SaveManager.add_stat(&"hard_wins")
		if not lost_mower:
			SaveManager.add_stat(&"clean_wins")
	SaveManager.save_game()
	last_result = result
	EventBus.level_finished.emit(level_id, won)
	return result
