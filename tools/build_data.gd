extends Node
## Generates every data resource (.tres) under res://data from the balance tables below.
## Run:  godot --headless --path . res://tools/build_data.tscn
## (Runs as a scene, not with -s, so autoload singletons referenced by entity
## scripts resolve while the behaviour scripts are loaded.)
## After generation the .tres files are the source of truth and can be tuned in the inspector;
## re-running this tool overwrites them with the table values.

const P := "res://entities/plants/"
const Z := "res://entities/zombies/"

func _ready() -> void:
	if not "--legacy-rebuild" in OS.get_cmdline_user_args():
		push_error("Legacy v0.4 data generator disabled. Edit data/campaign/*.json for v0.5. Pass --legacy-rebuild only to deliberately rebuild old content.")
		get_tree().quit(1)
		return
	for d: String in ["plants", "zombies", "fusion", "levels", "maps", "difficulty", "quests", "shop"]:
		DirAccess.make_dir_recursive_absolute("res://data/" + d)
	_plants()
	_zombies()
	_recipes()
	_difficulties()
	_levels()
	_map()
	_quests()
	_shop()
	_save(UITheme.build(), "res://ui/theme.tres")
	print("Data build finished.")
	get_tree().quit()

func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %d" % [path, err])

# --- plants ------------------------------------------------------------------
func _plant(id: String, cfg: Dictionary) -> void:
	var p := PlantData.new()
	p.id = StringName(id)
	p.name_key = "PLANT_%s_NAME" % id.to_upper()
	p.desc_key = "PLANT_%s_DESC" % id.to_upper()
	for k: String in cfg.keys():
		if k == "script":
			p.behavior = load(P + str(cfg[k]) + ".gd")
		elif k == "tags" or k == "allowed_surfaces":
			var tags: Array[StringName] = []
			for t: Variant in cfg[k]:
				tags.append(StringName(t))
			p.set(k, tags)
		else:
			p.set(k, cfg[k])
	_save(p, "res://data/plants/%s.tres" % id)

func _plants() -> void:
	_plant("sunbud", {"cost": 50, "recharge": 7.5, "max_hp": 300, "role": &"producer", "script": "plant_producer",
		"sun_amount": 25, "sun_interval": 24.0, "shots": 1,
		"color_main": Color(1.0, 0.8, 0.22), "color_accent": Color(0.62, 0.4, 0.18)})
	_plant("pod_shooter", {"cost": 100, "recharge": 7.5, "max_hp": 300, "role": &"shooter", "script": "plant_shooter",
		"damage": 20, "attack_interval": 1.45,
		"color_main": Color(0.45, 0.78, 0.3), "color_accent": Color(0.6, 0.9, 0.35)})
	_plant("twin_pod", {"cost": 200, "recharge": 7.5, "max_hp": 300, "role": &"shooter", "script": "plant_shooter",
		"damage": 20, "attack_interval": 1.45, "shots": 2, "is_seed": false, "is_hybrid": true,
		"color_main": Color(0.38, 0.72, 0.28), "color_accent": Color(0.6, 0.9, 0.35)})
	_plant("bark_wall", {"cost": 50, "recharge": 30.0, "max_hp": 4000, "role": &"wall", "script": "plant_wall",
		"fusion_ready_time": 2.0,
		"color_main": Color(0.66, 0.48, 0.3), "color_accent": Color(0.48, 0.33, 0.2)})
	_plant("thorn_mine", {"cost": 25, "recharge": 30.0, "max_hp": 300, "role": &"mine", "script": "plant_mine",
		"arm_time": 14.0, "damage": 1800, "aoe_radius": 0.6, "fusion_ready_time": 2.0,
		"color_main": Color(0.55, 0.45, 0.62), "color_accent": Color(0.85, 0.82, 0.75)})
	_plant("ember_berry", {"cost": 150, "recharge": 50.0, "start_cooldown": 35.0, "max_hp": 300, "role": &"instant",
		"script": "plant_instant", "damage": 1800, "aoe_radius": 1.5, "tags": ["fire"],
		"color_main": Color(0.88, 0.2, 0.18), "color_accent": Color(1.0, 0.6, 0.15)})
	_plant("frost_mint", {"cost": 175, "recharge": 7.5, "max_hp": 300, "role": &"slower", "script": "plant_shooter",
		"damage": 20, "attack_interval": 1.45, "slow_factor": 0.5, "slow_duration": 8.0, "tags": ["frost"],
		"color_main": Color(0.55, 0.85, 0.9), "color_accent": Color(0.75, 0.95, 1.0)})
	_plant("snapper_trap", {"cost": 150, "recharge": 7.5, "max_hp": 300, "role": &"trap", "script": "plant_trap",
		"chew_time": 40.0, "damage": 400,
		"color_main": Color(0.58, 0.32, 0.62), "color_accent": Color(0.95, 0.5, 0.6)})
	_plant("bramble_vine", {"cost": 100, "recharge": 15.0, "max_hp": 800, "role": &"blocker", "script": "plant_wall",
		"thorns_damage": 12, "fusion_ready_time": 2.0,
		"color_main": Color(0.38, 0.52, 0.3), "color_accent": Color(0.78, 0.32, 0.48)})
	_plant("lantern_bloom", {"cost": 125, "recharge": 15.0, "max_hp": 300, "role": &"support", "script": "plant_support",
		"buff_mult": 1.25, "tags": ["light"],
		"color_main": Color(1.0, 0.82, 0.42), "color_accent": Color(0.8, 0.45, 0.2)})
	_plant("gale_fern", {"cost": 100, "recharge": 20.0, "start_cooldown": 10.0, "max_hp": 300, "role": &"control",
		"script": "plant_pusher", "damage": 10, "attack_interval": 7.0, "attack_range": 3.5, "push_distance": 110.0,
		"color_main": Color(0.5, 0.8, 0.45), "color_accent": Color(0.42, 0.62, 0.32)})
	_plant("pepper_stinger", {"cost": 175, "recharge": 10.0, "max_hp": 300, "role": &"pierce", "script": "plant_shooter",
		"damage": 25, "attack_interval": 2.0, "pierce": 99, "projectile_speed": 720.0, "tags": ["fire"],
		"color_main": Color(0.86, 0.26, 0.2), "color_accent": Color(0.98, 0.85, 0.4)})
	_plant("hive_pod", {"cost": 125, "recharge": 10.0, "max_hp": 300, "role": &"summoner", "script": "plant_hive",
		"damage": 30, "attack_interval": 3.5, "summon_max": 3,
		"color_main": Color(0.95, 0.7, 0.25), "color_accent": Color(0.6, 0.4, 0.1)})
	_plant("dandelion_puff", {"cost": 75, "recharge": 7.5, "max_hp": 300, "role": &"aoe", "script": "plant_aoe",
		"damage": 14, "attack_interval": 2.5, "aoe_radius": 1.4,
		"color_main": Color(0.98, 0.98, 0.95), "color_accent": Color(0.95, 0.8, 0.3)})
	# 0-sun ice plant (inspired by the sequel's free freezer, original design here).
	_plant("rime_lettuce", {"cost": 0, "recharge": 20.0, "max_hp": 300, "role": &"freeze", "script": "plant_freeze",
		"freeze_time": 10.0, "fusion_ready_time": 99.0, "tags": ["frost"],
		"color_main": Color(0.62, 0.86, 0.72), "color_accent": Color(0.8, 0.95, 0.88)})
	# Pool platform: the only plant that grows on water; other plants stand on it.
	_plant("lily_raft", {"cost": 25, "recharge": 7.5, "max_hp": 300, "role": &"platform", "script": "plant_raft",
		"allowed_surfaces": [&"water"], "fusion_ready_time": 99.0, "tags": ["aquatic"],
		"color_main": Color(0.4, 0.7, 0.32), "color_accent": Color(0.95, 0.6, 0.75)})
	# Legendary plants: one copy on the board at a time, long start cooldown.
	_plant("sun_sovereign", {"cost": 250, "recharge": 45.0, "start_cooldown": 20.0, "max_hp": 600, "role": &"producer",
		"script": "plant_producer", "sun_amount": 50, "sun_interval": 20.0, "shots": 1, "buff_mult": 1.2, "tags": ["light"],
		"rarity": &"legendary", "max_on_board": 1, "fusion_ready_time": 99.0,
		"color_main": Color(1.0, 0.78, 0.2), "color_accent": Color(0.66, 0.38, 0.14)})
	_plant("storm_thistle", {"cost": 350, "recharge": 40.0, "start_cooldown": 25.0, "max_hp": 300, "role": &"chain",
		"script": "plant_storm", "damage": 70, "attack_interval": 2.4, "chain_count": 4, "chain_range": 1.8, "stun_time": 0.4,
		"tags": ["storm"], "rarity": &"legendary", "max_on_board": 1, "fusion_ready_time": 99.0,
		"color_main": Color(0.62, 0.5, 0.95), "color_accent": Color(0.85, 0.92, 1.0)})
	_plant("elder_oak", {"cost": 300, "recharge": 50.0, "start_cooldown": 20.0, "max_hp": 9000, "role": &"wall",
		"script": "plant_wall", "thorns_damage": 25, "regen_per_sec": 60.0, "tags": ["tall"],
		"rarity": &"legendary", "max_on_board": 1, "fusion_ready_time": 99.0,
		"color_main": Color(0.55, 0.4, 0.27), "color_accent": Color(0.38, 0.26, 0.16)})
	_plant("phoenix_lily", {"cost": 325, "recharge": 35.0, "start_cooldown": 20.0, "max_hp": 400, "role": &"shooter",
		"script": "plant_shooter", "damage": 35, "attack_interval": 1.6, "pierce": 2, "projectile_speed": 640.0,
		"burn_dps": 20.0, "burn_time": 3.0, "rebirths": 1, "tags": ["fire"],
		"rarity": &"legendary", "max_on_board": 1, "fusion_ready_time": 99.0,
		"color_main": Color(0.95, 0.32, 0.15), "color_accent": Color(1.0, 0.6, 0.18)})
	# Twin hybrids (same-plant graft results)
	_plant("twin_sunbud", {"cost": 150, "recharge": 7.5, "max_hp": 300, "role": &"producer", "script": "plant_producer",
		"sun_amount": 25, "sun_interval": 24.0, "shots": 2, "is_seed": false, "is_hybrid": true,
		"color_main": Color(1.0, 0.72, 0.18), "color_accent": Color(0.62, 0.4, 0.18)})
	_plant("ironbark_wall", {"cost": 175, "recharge": 30.0, "max_hp": 8000, "role": &"wall", "script": "plant_wall",
		"tags": ["tall"], "is_seed": false, "is_hybrid": true,
		"color_main": Color(0.52, 0.44, 0.38), "color_accent": Color(0.36, 0.28, 0.22)})
	# Hybrids (Graft results)
	_plant("glacier_shooter", {"cost": 300, "max_hp": 300, "role": &"slower", "script": "plant_shooter", "is_seed": false, "is_hybrid": true,
		"damage": 22, "attack_interval": 1.7, "pierce": 1, "slow_factor": 0.45, "slow_duration": 9.0, "tags": ["frost"],
		"color_main": Color(0.5, 0.78, 0.92), "color_accent": Color(0.8, 0.95, 1.0)})
	_plant("thornwall", {"cost": 175, "max_hp": 4000, "role": &"wall", "script": "plant_wall", "is_seed": false, "is_hybrid": true,
		"thorns_damage": 22,
		"color_main": Color(0.6, 0.45, 0.32), "color_accent": Color(0.45, 0.3, 0.2)})
	_plant("dawn_bloom", {"cost": 200, "max_hp": 300, "role": &"producer", "script": "plant_producer", "is_seed": false, "is_hybrid": true,
		"sun_amount": 40, "sun_interval": 26.0, "shots": 1, "buff_mult": 1.15, "tags": ["light"],
		"color_main": Color(1.0, 0.6, 0.45), "color_accent": Color(0.7, 0.35, 0.2)})
	_plant("volcano_mine", {"cost": 200, "max_hp": 300, "role": &"mine", "script": "plant_mine", "is_seed": false, "is_hybrid": true,
		"arm_time": 18.0, "damage": 1800, "aoe_radius": 1.5, "burn_dps": 40.0, "burn_time": 5.0, "tags": ["fire"],
		"color_main": Color(0.42, 0.34, 0.3), "color_accent": Color(1.0, 0.5, 0.1)})
	_plant("vortex_trap", {"cost": 275, "max_hp": 300, "role": &"trap", "script": "plant_trap", "is_seed": false, "is_hybrid": true,
		"chew_time": 32.0, "damage": 400, "pull_range": 1.5,
		"color_main": Color(0.3, 0.55, 0.6), "color_accent": Color(0.6, 0.95, 0.9)})
	_plant("needle_volley", {"cost": 400, "max_hp": 300, "role": &"pierce", "script": "plant_shooter", "is_seed": false, "is_hybrid": true,
		"damage": 20, "attack_interval": 2.6, "shots": 3, "pierce": 99, "projectile_speed": 720.0,
		"color_main": Color(0.42, 0.7, 0.3), "color_accent": Color(0.9, 0.4, 0.25)})

# --- zombies -----------------------------------------------------------------
func _zombie(id: String, cfg: Dictionary) -> void:
	var z := ZombieData.new()
	z.id = StringName(id)
	z.name_key = "ZOMBIE_%s_NAME" % id.to_upper()
	z.desc_key = "ZOMBIE_%s_DESC" % id.to_upper()
	z.behavior = load(Z + str(cfg.get("script", "zombie")) + ".gd")
	for k: String in cfg.keys():
		if k == "script":
			continue
		elif k == "immune":
			var im: Array[StringName] = []
			for t: String in cfg[k]:
				im.append(StringName(t))
			z.immune_to = im
		else:
			z.set(k, cfg[k])
	_save(z, "res://data/zombies/%s.tres" % id)

func _zombies() -> void:
	_zombie("shambler", {"hp": 270, "speed": 0.17, "threat_cost": 1.0, "weight": 10.0})
	_zombie("flagbearer", {"hp": 270, "speed": 0.28, "threat_cost": 1.0, "weight": 0.0, "color_cloth": Color(0.35, 0.3, 0.42)})
	_zombie("cone_head", {"hp": 270, "armor_hp": 370, "armor_kind": &"cone", "threat_cost": 2.0, "weight": 6.0})
	_zombie("bucket_head", {"hp": 270, "armor_hp": 1100, "armor_kind": &"bucket", "threat_cost": 4.0, "weight": 3.0,
		"color_cloth": Color(0.35, 0.4, 0.5)})
	_zombie("sprinter", {"hp": 230, "speed": 0.36, "threat_cost": 2.0, "weight": 4.0,
		"color_cloth": Color(0.85, 0.85, 0.82), "color_skin": Color(0.62, 0.75, 0.5)})
	_zombie("hurdler", {"script": "zombie_hurdler", "hp": 340, "speed": 0.34, "threat_cost": 3.0, "weight": 3.0,
		"color_cloth": Color(0.3, 0.45, 0.7)})
	_zombie("shield_carrier", {"script": "zombie_shield", "hp": 270, "armor_hp": 1100, "armor_kind": &"shield", "speed": 0.17,
		"threat_cost": 4.0, "weight": 3.0, "color_cloth": Color(0.5, 0.36, 0.3)})
	_zombie("burrower", {"script": "zombie_burrower", "hp": 300, "speed": 0.32, "threat_cost": 3.0, "weight": 2.0,
		"color_cloth": Color(0.45, 0.4, 0.3)})
	_zombie("brute", {"script": "zombie_brute", "hp": 3000, "speed": 0.13, "damage": 600.0, "eat_interval": 1.6,
		"threat_cost": 9.0, "weight": 1.5, "body_scale": 1.45, "immune": ["devour", "push", "pull"],
		"color_cloth": Color(0.45, 0.32, 0.25), "color_skin": Color(0.55, 0.66, 0.5)})

# --- graft recipes -------------------------------------------------------------
func _recipes() -> void:
	var list := [
		["pod_shooter", "frost_mint", "glacier_shooter", 25],
		["bark_wall", "bramble_vine", "thornwall", 25],
		["sunbud", "lantern_bloom", "dawn_bloom", 25],
		["thorn_mine", "ember_berry", "volcano_mine", 25],
		["snapper_trap", "gale_fern", "vortex_trap", 25],
		["twin_pod", "pepper_stinger", "needle_volley", 25],
		["sunbud", "sunbud", "twin_sunbud", 50],
		["pod_shooter", "pod_shooter", "twin_pod", 25],
		["bark_wall", "bark_wall", "ironbark_wall", 75],
		["pod_shooter", "rime_lettuce", "glacier_shooter", 75, "glacier_shooter_rime"],
	]
	for r: Array in list:
		var f := FusionRecipe.new()
		f.base_id = StringName(r[0])
		f.catalyst_id = StringName(r[1])
		f.result_id = StringName(r[2])
		f.fee = r[3]
		_save(f, "res://data/fusion/%s.tres" % (r[4] if r.size() > 4 else r[2]))

# --- difficulty --------------------------------------------------------------
func _difficulties() -> void:
	var list := [
		# id, order, speed, dps, damage taken, count, interval, coins
		["standard", 0, 1.00, 1.0, 1.00, 1.0, 1.00, 1.00],
		["hard", 1, 1.00, 1.15, 0.90, 1.15, 1.00, 1.25],
		["hard_plus", 2, 1.05, 1.30, 0.85, 1.25, 0.95, 1.50],
	]
	for r: Array in list:
		var d := DifficultyData.new()
		d.id = StringName(r[0])
		d.name_key = "DIFFICULTY_%s" % str(r[0]).to_upper()
		d.order = r[1]
		d.zombie_speed_mult = r[2]
		d.zombie_dps_mult = r[3]
		d.zombie_damage_taken_mult = r[4]
		d.zombie_count_mult = r[5]
		d.spawn_interval_mult = r[6]
		d.coin_reward_mult = r[7]
		_save(d, "res://data/difficulty/%s.tres" % r[0])

# --- levels ------------------------------------------------------------------
func _level(id: String, cfg: Dictionary) -> void:
	var l := LevelData.new()
	l.id = StringName(id)
	l.name_key = "LEVEL_%s_NAME" % id.to_upper()
	l.desc_key = "LEVEL_%s_DESC" % id.to_upper()
	for k: String in cfg.keys():
		var v: Variant = cfg[k]
		if k in ["zombie_pool", "fixed_seeds", "banned_plants"]:
			var arr: Array[StringName] = []
			for s: String in v:
				arr.append(StringName(s))
			l.set(k, arr)
		elif k == "water":
			l.water = PackedStringArray(v)
		else:
			l.set(k, v)
	if l.water.is_empty() and POOLS.has(id):
		l.water = PackedStringArray(POOLS[id])
	_save(l, "res://data/levels/%s.tres" % id)

## Pool layouts ('~' water, '.' lawn). Deliberately non-linear: ponds, islands,
## diagonal channels and meanders, so lanes mix lawn and water cells.
const POOLS := {
	"pool_01": [".........", "....~~~..", "...~~~~..", "....~~...", "........."],
	"pool_02": [".........", "..~~~~...", ".~~~~~~..", "..~~.~~..", "........."],
	"pool_03": ["......~~.", ".....~~..", "....~~...", "...~~....", "..~~....."],
	"pool_04": [".~~......", ".~~...~~.", "......~~.", "..~~.....", "..~~~...."],
	"pool_05": ["...~~~~..", "..~~~~~~.", "..~~..~~.", "..~~~~~~.", "...~~~~.."],
	"pool_06": ["...~~~~~~", "...~.....", "...~~~~..", "......~..", "..~~~~~.."],
	"pool_bonus_1": ["..~~~~~~.", "..~......", "..~~~~~~.", ".......~.", "..~~~~~~."],
}

func _levels() -> void:
	var a := ["shambler", "cone_head"]
	_level("lawn_01", {"waves": 4, "flag_every": 4, "zombie_pool": ["shambler"], "threat_base": 1.0, "threat_growth": 0.5,
		"start_sun": 150, "reward_plant": &"bark_wall", "reward_coins": 50, "hint_key": "HINT_LAWN_01"})
	_level("lawn_02", {"waves": 6, "flag_every": 6, "zombie_pool": a, "threat_base": 1.0, "threat_growth": 0.55,
		"reward_plant": &"thorn_mine", "reward_coins": 60, "hint_key": "HINT_LAWN_02"})
	_level("lawn_03", {"waves": 8, "flag_every": 4, "zombie_pool": a, "threat_base": 1.0, "threat_growth": 0.6,
		"reward_plant": &"frost_mint", "reward_coins": 70, "hint_key": "HINT_LAWN_03"})
	_level("lawn_04", {"waves": 8, "flag_every": 4, "zombie_pool": a + ["sprinter"], "threat_base": 1.0, "threat_growth": 0.65,
		"reward_plant": &"ember_berry", "reward_coins": 80, "hint_key": "HINT_LAWN_04"})
	_level("lawn_05", {"waves": 10, "flag_every": 5, "zombie_pool": a + ["bucket_head", "sprinter"], "threat_base": 1.0, "threat_growth": 0.7,
		"reward_plant": &"snapper_trap", "reward_feature": &"graft", "reward_coins": 90, "hint_key": "HINT_LAWN_05"})
	_level("lawn_06", {"waves": 10, "flag_every": 5, "zombie_pool": a + ["bucket_head"], "threat_base": 1.0, "threat_growth": 0.66,
		"hybrid_cap": 2, "reward_plant": &"", "reward_feature": &"", "reward_coins": 140, "hint_key": "HINT_LAWN_06"})
	_level("lawn_07", {"waves": 10, "flag_every": 5, "zombie_pool": a + ["bucket_head", "sprinter", "hurdler"], "threat_base": 1.0, "threat_growth": 0.75,
		"hybrid_cap": 3, "reward_plant": &"bramble_vine", "reward_coins": 110, "hint_key": "HINT_LAWN_07"})
	_level("lawn_08", {"waves": 12, "flag_every": 4, "zombie_pool": a + ["bucket_head", "hurdler", "shield_carrier"], "threat_base": 1.0, "threat_growth": 0.78,
		"hybrid_cap": 3, "reward_plant": &"lantern_bloom", "reward_coins": 120, "hint_key": "HINT_LAWN_08"})
	_level("lawn_09", {"waves": 12, "flag_every": 4, "zombie_pool": a + ["bucket_head", "sprinter", "hurdler", "shield_carrier"], "threat_base": 1.0, "threat_growth": 0.8,
		"hybrid_cap": 4, "reward_plant": &"gale_fern", "reward_coins": 130})
	_level("lawn_10", {"waves": 12, "flag_every": 4, "zombie_pool": a + ["bucket_head", "sprinter", "shield_carrier", "burrower"], "threat_base": 1.0, "threat_growth": 0.85,
		"hybrid_cap": 4, "reward_plant": &"pepper_stinger", "reward_coins": 140, "hint_key": "HINT_LAWN_10"})
	_level("lawn_11", {"waves": 14, "flag_every": 5, "zombie_pool": a + ["bucket_head", "sprinter", "hurdler", "shield_carrier", "burrower"], "threat_base": 1.0, "threat_growth": 0.84,
		"hybrid_cap": 5, "reward_plant": &"rime_lettuce", "reward_coins": 150})
	_level("lawn_12", {"waves": 14, "flag_every": 5, "zombie_pool": a + ["bucket_head", "hurdler", "shield_carrier", "brute"], "threat_base": 1.0, "threat_growth": 0.85,
		"hybrid_cap": 5, "reward_coins": 200, "hint_key": "HINT_LAWN_12"})
	_level("lawn_13", {"waves": 16, "flag_every": 4, "zombie_pool": a + ["bucket_head", "sprinter", "hurdler", "shield_carrier", "burrower", "brute"], "threat_base": 0.9, "threat_growth": 0.86,
		"hybrid_cap": 6, "reward_plant": &"elder_oak", "reward_coins": 400, "start_sun": 150})
	_level("lawn_bonus_1", {"waves": 8, "flag_every": 4, "zombie_pool": ["shambler", "sprinter"], "threat_base": 1.0, "threat_growth": 0.65,
		"wave_interval": 30.0, "first_wave_delay": 34.0, "allow_hybrids": false, "reward_plant": &"dandelion_puff", "reward_coins": 100, "hint_key": "HINT_LAWN_BONUS_1"})
	_level("lawn_bonus_2", {"waves": 12, "flag_every": 4, "zombie_pool": a + ["bucket_head", "shield_carrier"], "threat_base": 1.0, "threat_growth": 0.8,
		"allow_hybrids": false, "fixed_seeds": ["sunbud", "pod_shooter", "bark_wall", "frost_mint", "thorn_mine", "snapper_trap"],
		"reward_plant": &"hive_pod", "reward_coins": 150, "hint_key": "HINT_LAWN_BONUS_2"})
	_level("lawn_bonus_3", {"waves": 14, "flag_every": 5, "zombie_pool": a + ["bucket_head", "sprinter", "hurdler", "shield_carrier"], "threat_base": 1.0, "threat_growth": 0.88,
		"allow_hybrids": false, "reward_coins": 300, "hint_key": "HINT_LAWN_BONUS_3"})
	# Second campaign map. Water-lane rules remain a future milestone; these
	# levels use the polished core board with a distinct poolside route.
	_level("pool_01", {"waves": 8, "flag_every": 4, "zombie_pool": a + ["sprinter"], "threat_base": 1.0, "threat_growth": 0.62,
		"hybrid_cap": 3, "reward_plant": &"rime_lettuce", "reward_coins": 110, "hint_key": "HINT_POOL_01"})
	_level("pool_02", {"waves": 10, "flag_every": 5, "zombie_pool": a + ["bucket_head", "hurdler"], "threat_base": 1.0, "threat_growth": 0.66,
		"hybrid_cap": 3, "reward_coins": 130, "hint_key": "HINT_POOL_02"})
	_level("pool_03", {"waves": 10, "flag_every": 5, "zombie_pool": a + ["sprinter", "shield_carrier"], "threat_base": 1.0, "threat_growth": 0.7,
		"hybrid_cap": 4, "reward_coins": 150})
	_level("pool_04", {"waves": 12, "flag_every": 4, "zombie_pool": a + ["bucket_head", "hurdler", "burrower"], "threat_base": 1.0, "threat_growth": 0.72,
		"hybrid_cap": 4, "reward_coins": 170})
	_level("pool_05", {"waves": 12, "flag_every": 4, "zombie_pool": a + ["bucket_head", "sprinter", "shield_carrier", "brute"], "threat_base": 1.0, "threat_growth": 0.72,
		"hybrid_cap": 5, "reward_coins": 210, "start_sun": 100})
	_level("pool_06", {"waves": 14, "flag_every": 4, "zombie_pool": a + ["bucket_head", "sprinter", "hurdler", "shield_carrier", "burrower", "brute"], "threat_base": 1.0, "threat_growth": 0.8,
		"hybrid_cap": 6, "reward_plant": &"storm_thistle", "reward_coins": 350, "start_sun": 150})
	_level("pool_bonus_1", {"waves": 10, "flag_every": 5, "zombie_pool": ["shambler", "sprinter", "hurdler"], "threat_base": 1.0, "threat_growth": 0.72,
		"wave_interval": 30.0, "allow_hybrids": false, "reward_coins": 180})

# --- map ---------------------------------------------------------------------
func _node(id: String, type: MapNodeData.NodeType, pos: Vector2, level: String, next: Array, stars: int = 0, optional: bool = false) -> MapNodeData:
	var n := MapNodeData.new()
	n.id = StringName(id)
	n.type = type
	n.position = pos
	n.level_id = StringName(level)
	var nx: Array[StringName] = []
	for s: String in next:
		nx.append(StringName(s))
	n.next_ids = nx
	n.requires_stars = stars
	n.optional = optional
	return n

func _map() -> void:
	var L := MapNodeData.NodeType.LEVEL
	var B := MapNodeData.NodeType.BONUS
	var S := MapNodeData.NodeType.SHOP
	var G := MapNodeData.NodeType.GATE
	var m := MapData.new()
	m.id = &"lawn"
	m.name_key = "MAP_LAWN_NAME"
	m.available = true
	m.start_node = &"n_01"
	var nodes: Array[MapNodeData] = [
		_node("n_01", L, Vector2(230, 870), "lawn_01", ["n_02"]),
		_node("n_02", L, Vector2(420, 770), "lawn_02", ["n_03"]),
		_node("n_03", L, Vector2(610, 850), "lawn_03", ["n_04"]),
		_node("n_04", L, Vector2(790, 730), "lawn_04", ["n_05", "n_b1", "n_shop1"]),
		_node("n_shop1", S, Vector2(700, 960), "", [], 0, true),
		_node("n_05", L, Vector2(900, 570), "lawn_05", ["n_06"]),
		_node("n_06", L, Vector2(1080, 480), "lawn_06", ["n_07"]),
		_node("n_b1", B, Vector2(1020, 840), "lawn_bonus_1", ["n_07"], 0, true),
		_node("n_07", L, Vector2(1240, 610), "lawn_07", ["n_08"]),
		_node("n_08", L, Vector2(1390, 470), "lawn_08", ["n_09"]),
		_node("n_09", L, Vector2(1570, 380), "lawn_09", ["n_gate1", "n_b2"]),
		_node("n_b2", B, Vector2(1790, 520), "lawn_bonus_2", [], 0, true),
		_node("n_gate1", G, Vector2(1620, 230), "", ["n_10"], 8),
		_node("n_10", L, Vector2(1420, 200), "lawn_10", ["n_11"]),
		_node("n_11", L, Vector2(1230, 270), "lawn_11", ["n_gate2", "n_b3", "n_shop2"]),
		_node("n_shop2", S, Vector2(1190, 400), "", [], 0, true),
		_node("n_b3", B, Vector2(930, 410), "lawn_bonus_3", [], 0, true),
		_node("n_gate2", G, Vector2(1040, 220), "", ["n_12"], 12),
		_node("n_12", L, Vector2(840, 270), "lawn_12", ["n_13"]),
		_node("n_13", L, Vector2(620, 220), "lawn_13", []),
	]
	m.nodes = nodes
	_save(m, "res://data/maps/lawn.tres")
	var p := MapData.new()
	p.id = &"pool"
	p.name_key = "MAP_POOL_NAME"
	p.available = true
	p.tint = Color(0.23, 0.57, 0.78)
	p.start_node = &"p_01"
	p.nodes = [
		_node("p_01", L, Vector2(250, 770), "pool_01", ["p_02"]),
		_node("p_02", L, Vector2(510, 640), "pool_02", ["p_03", "p_shop"]),
		_node("p_shop", S, Vector2(510, 900), "", [], 0, true),
		_node("p_03", L, Vector2(800, 760), "pool_03", ["p_gate", "p_b1"]),
		_node("p_b1", B, Vector2(1030, 920), "pool_bonus_1", ["p_04"], 0, true),
		_node("p_gate", G, Vector2(1050, 540), "", ["p_04"], 10),
		_node("p_04", L, Vector2(1280, 680), "pool_04", ["p_05"]),
		_node("p_05", L, Vector2(1510, 480), "pool_05", ["p_06"]),
		_node("p_06", L, Vector2(1690, 260), "pool_06", []),
	]
	_save(p, "res://data/maps/pool.tres")

# --- quests ------------------------------------------------------------------
func _quests() -> void:
	var list := [
		["first_steps", "wins", 1, 50, false],
		["shambler_hunter", "kill_shambler", 60, 75, false],
		["cone_cracker", "kill_cone_head", 25, 75, false],
		["first_graft", "grafts", 1, 100, true],
		["twins", "twin_grafts", 3, 75, false],
		["clean_lawn", "clean_wins", 3, 100, true],
		["bucket_list", "kill_bucket_head", 25, 100, false],
		["sun_hoarder", "sun", 5000, 100, false],
		["gardener", "planted", 200, 100, false],
		["recipe_book", "recipes", 3, 150, true],
		["hard_soil", "hard_wins", 1, 150, false],
		["giant_slayer", "kill_brute", 5, 150, true],
	]
	for i: int in list.size():
		var r: Array = list[i]
		var q := QuestData.new()
		q.id = StringName(r[0])
		q.title_key = "QUEST_%s_TITLE" % str(r[0]).to_upper()
		q.desc_key = "QUEST_%s_DESC" % str(r[0]).to_upper()
		q.stat = StringName(r[1])
		q.amount = r[2]
		q.reward_coins = r[3]
		q.reward_hint = r[4]
		_save(q, "res://data/quests/%02d_%s.tres" % [i, r[0]])

# --- shop --------------------------------------------------------------------
func _shop() -> void:
	var list := [
		["extra_slot", "slot", 250, 250, 4, Color.WHITE],
		["start_sun", "start_sun", 200, 200, 4, Color.WHITE],
		["mower_kit", "mower_kit", 150, 0, 3, Color.WHITE],
		["recipe_hint", "hint", 200, 0, 0, Color.WHITE],
		["skin_azure", "skin", 300, 0, 1, Color(0.25, 0.5, 0.9)],
		["skin_moss", "skin", 300, 0, 1, Color(0.3, 0.62, 0.3)],
		["skin_gold", "skin", 800, 0, 1, Color(0.95, 0.75, 0.2)],
		["legend_sun_sovereign", "plant", 900, 0, 1, Color.WHITE, &"sun_sovereign"],
		["legend_phoenix_lily", "plant", 1200, 0, 1, Color.WHITE, &"phoenix_lily"],
		["legend_storm_thistle", "plant", 1500, 0, 1, Color.WHITE, &"storm_thistle"],
		["legend_elder_oak", "plant", 1500, 0, 1, Color.WHITE, &"elder_oak"],
	]
	for i: int in list.size():
		var r: Array = list[i]
		var s := ShopItemData.new()
		s.id = StringName(r[0])
		s.kind = StringName(r[1])
		s.name_key = "SHOP_%s_NAME" % str(r[0]).to_upper()
		s.desc_key = "SHOP_%s_DESC" % str(r[0]).to_upper()
		s.base_price = r[2]
		s.price_step = r[3]
		s.max_count = r[4]
		s.skin_color = r[5]
		if r.size() > 6:
			s.plant_id = r[6]
		_save(s, "res://data/shop/%02d_%s.tres" % [i, r[0]])
