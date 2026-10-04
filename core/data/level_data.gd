class_name LevelData
extends Resource

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var waves: int = 8
## Every N-th wave is a flag (big) wave. The last wave is always a flag wave.
@export var flag_every: int = 4
@export var zombie_pool: Array[StringName] = [&"shambler"]
@export var threat_base: float = 1.0
@export var threat_growth: float = 0.9
@export var first_wave_delay: float = 40.0
@export var wave_interval: float = 34.0
@export var start_sun: int = 50
@export var sky_sun: bool = true
@export var sky_sun_interval: float = 8.0
@export var hybrid_cap: int = 0
@export var allow_hybrids: bool = true
## Non-empty: seed selection is locked to this set.
@export var fixed_seeds: Array[StringName] = []
@export var banned_plants: Array[StringName] = []
@export var mowers: bool = true
@export var reward_plant: StringName = &""
## Gameplay feature unlocked on first win: &"graft", &"evolve".
@export var reward_feature: StringName = &""
@export var reward_coins: int = 50
@export var hint_key: String = ""
## Pool layout: ROWS strings of COLS chars ('~' = water, '.' = lawn). Empty = all lawn.
@export var water: PackedStringArray = PackedStringArray()

## Layout character of a cell ('.' when the layout is empty or a row is short).
## Endless / Daily levels on grass worlds have no layout at all.
func tile(row: int, col: int) -> String:
	if row < 0 or row >= water.size() or col < 0:
		return "."
	var line := water[row]
	return line[col] if col < line.length() else "."

## '#' cells are blocked: nothing can be planted there.
func is_blocked(row: int, col: int) -> bool:
	return tile(row, col) == "#"

@export_group("Campaign")
@export var world_id: StringName = &"lawn"
@export var ordinal: int = 1
@export var mode: StringName = &"defense"
@export var field_rule: StringName = &"normal"
@export var objectives: Array[Dictionary] = []
@export var wave_specs: Array[Dictionary] = []
@export var preplants: Array[Dictionary] = []
@export var material_rewards: Dictionary = {}
@export var sky_sun_value: int = 25
@export var artillery_damage: float = 550.0
@export var artillery_cooldown: float = 2.0
