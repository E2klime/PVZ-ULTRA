extends Node
## Loads every data resource (.tres) from res://data at startup.

const PLANTS_DIR := "res://data/plants"
const ZOMBIES_DIR := "res://data/zombies"
const FUSION_DIR := "res://data/fusion"
const LEVELS_DIR := "res://data/levels"
const MAPS_DIR := "res://data/maps"
const DIFFICULTY_DIR := "res://data/difficulty"
const QUESTS_DIR := "res://data/quests"
const SHOP_DIR := "res://data/shop"

## Order used in almanac and seed selection.
var PLANT_ORDER: Array[StringName] = [
	&"sunbud", &"pod_shooter", &"bark_wall", &"thorn_mine", &"ember_berry",
	&"frost_mint", &"snapper_trap", &"bramble_vine", &"lantern_bloom", &"gale_fern",
	&"pepper_stinger", &"hive_pod", &"dandelion_puff", &"rime_lettuce", &"lily_raft",
	&"sun_sovereign", &"phoenix_lily", &"storm_thistle", &"elder_oak",
	&"twin_sunbud", &"twin_pod", &"ironbark_wall",
	&"glacier_shooter", &"thornwall", &"dawn_bloom", &"volcano_mine", &"vortex_trap", &"needle_volley",
]
var ZOMBIE_ORDER: Array[StringName] = [
	&"shambler", &"flagbearer", &"cone_head", &"bucket_head", &"sprinter",
	&"hurdler", &"shield_carrier", &"burrower", &"brute",
]

var plants: Dictionary = {}       # StringName -> PlantData
var zombies: Dictionary = {}      # StringName -> ZombieData
var recipes: Array[FusionRecipe] = []
var levels: Dictionary = {}       # StringName -> LevelData
var maps: Array[MapData] = []
var difficulties: Array[DifficultyData] = []
var quests: Array[QuestData] = []
var shop_items: Array[ShopItemData] = []

func _ready() -> void:
	for r: Resource in _load_dir(PLANTS_DIR):
		var p := r as PlantData
		if p: plants[p.id] = p
	for r: Resource in _load_dir(ZOMBIES_DIR):
		var z := r as ZombieData
		if z: zombies[z.id] = z
	for r: Resource in _load_dir(FUSION_DIR):
		var f := r as FusionRecipe
		if f: recipes.append(f)
	for r: Resource in _load_dir(DIFFICULTY_DIR):
		var d := r as DifficultyData
		if d: difficulties.append(d)
	difficulties.sort_custom(func(a: DifficultyData, b: DifficultyData) -> bool: return a.order < b.order)
	for r: Resource in _load_dir(QUESTS_DIR):
		var q := r as QuestData
		if q: quests.append(q)
	for r: Resource in _load_dir(SHOP_DIR):
		var s := r as ShopItemData
		if s: shop_items.append(s)

	CampaignLoader.populate(self)
	for id: StringName in plants:
		if not PLANT_ORDER.has(id): PLANT_ORDER.append(id)
	for id: StringName in zombies:
		if not ZOMBIE_ORDER.has(id): ZOMBIE_ORDER.append(id)

func _load_dir(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var files := DirAccess.get_files_at(path)
	var names: Array[String] = []
	for f: String in files:
		# Exported builds list "x.tres.remap" instead of "x.tres".
		var clean := f.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			if not clean in names:
				names.append(clean)
	names.sort()
	for n: String in names:
		var res := load(path.path_join(n))
		if res:
			out.append(res)
	return out

func plant(id: StringName) -> PlantData:
	return plants.get(id) as PlantData

func zombie(id: StringName) -> ZombieData:
	return zombies.get(id) as ZombieData

func level(id: StringName) -> LevelData:
	return levels.get(id) as LevelData

func map(id: StringName) -> MapData:
	for m: MapData in maps:
		if m.id == id:
			return m
	return null

func difficulty(id: StringName) -> DifficultyData:
	for d: DifficultyData in difficulties:
		if d.id == id:
			return d
	return difficulties[0] if not difficulties.is_empty() else DifficultyData.new()

func find_recipe(base_id: StringName, catalyst_id: StringName) -> FusionRecipe:
	for r: FusionRecipe in recipes:
		if r.base_id == base_id and r.catalyst_id == catalyst_id:
			return r
	# Order-independent: catalyst planted onto base or base onto catalyst.
	for r: FusionRecipe in recipes:
		if r.base_id == catalyst_id and r.catalyst_id == base_id:
			return r
	return null

func recipe_by_id(recipe_id: StringName) -> FusionRecipe:
	for r: FusionRecipe in recipes:
		if r.recipe_id() == recipe_id:
			return r
	return null

func recipes_with_result(result_id: StringName) -> Array[FusionRecipe]:
	var out: Array[FusionRecipe] = []
	for r: FusionRecipe in recipes:
		if r.result_id == result_id:
			out.append(r)
	return out

func quest(id: StringName) -> QuestData:
	for q: QuestData in quests:
		if q.id == id:
			return q
	return null

func shop_item(id: StringName) -> ShopItemData:
	for s: ShopItemData in shop_items:
		if s.id == id:
			return s
	return null
