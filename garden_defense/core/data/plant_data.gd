class_name PlantData
extends Resource
## Static description of a plant. All balance numbers live here (data-driven).

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var cost: int = 100
@export var recharge: float = 7.5
## Cooldown the seed starts with when a level begins.
@export var start_cooldown: float = 0.0
@export var max_hp: int = 300
@export var role: StringName = &"shooter"
@export var tags: Array[StringName] = []
## Behaviour script (extends Plant). Replaces a PackedScene: visuals are procedural for now.
@export var behavior: Script
@export var allowed_surfaces: Array[StringName] = [&"grass"]
@export var requires_support: bool = false
@export var sleeps_in_day: bool = false
@export var fusion_ready_time: float = 3.0
## False for hybrids: they cannot be put in a seed slot.
@export var is_seed: bool = true
@export var is_hybrid: bool = false
## &"common" or &"legendary". Legendary plants get a gold card, aura and shimmer.
@export var rarity: StringName = &"common"
## How many copies may grow on the board at once (0 = unlimited).
@export var max_on_board: int = 0

## Cell layer: &"main" (normal), &"under" (planted beneath: Thorn Carpet,
## Pea Bedding, Thunder Root), &"shell" (worn on top: Pumpkin Shell) or &"air"
## (flying: Garlic Drone, Turbo Bean). One plant per layer per cell.
@export var layer: StringName = &"main"
## Short gameplay tags shown on cards/almanac (e.g. "Lob", "Anti-air").
@export var badge: String = ""

@export_group("Combat")
## How its shots travel: &"straight" (blocked by nothing, flies over boxed and
## airborne zombies), &"lob" (catapult arc, hits boxed), &"low" (skims the
## ground, hits boxed), &"air" (fired from above, hits everything),
## &"anti_air" (also hits balloons).
@export var attack_kind: StringName = &"straight"
## Turbo Bean / Bean Patriarch: attack & production speed multiplier for plants in range.
@export var speed_aura: float = 1.0
## Cells for speed_aura / legendary effects (1 = 3x3).
@export var aura_radius: int = 1
@export var damage: int = 0
@export var attack_interval: float = 1.5
## Range in cells (0 = whole lane).
@export var attack_range: float = 0.0
@export var shots: int = 1
@export var pierce: int = 0
@export var projectile_speed: float = 560.0
@export var slow_factor: float = 1.0
@export var slow_duration: float = 0.0
@export var aoe_radius: float = 0.0
@export var thorns_damage: int = 0
@export var push_distance: float = 0.0
@export var burn_dps: float = 0.0
@export var burn_time: float = 0.0
@export var pull_range: float = 0.0
## Rime Lettuce: seconds a touching zombie is frozen solid (halved for push-immune giants).
@export var freeze_time: float = 0.0
## Storm Thistle: extra zombies hit by a chain bolt and jump range in cells.
@export var chain_count: int = 0
@export var chain_range: float = 0.0
@export var stun_time: float = 0.0
## Elder Oak: health restored per second after a few seconds without being bitten.
@export var regen_per_sec: float = 0.0
## Phoenix Lily: times the plant is reborn from its ashes instead of dying.
@export var rebirths: int = 0

@export_group("Utility")
@export var sun_amount: int = 0
@export var sun_interval: float = 24.0
@export var arm_time: float = 0.0
@export var chew_time: float = 0.0
## Multiplier given to neighbouring plants (1.0 = no buff).
@export var buff_mult: float = 1.0
@export var summon_max: int = 0

@export_group("Look")
@export var color_main: Color = Color(0.35, 0.75, 0.3)
@export var color_accent: Color = Color(0.2, 0.45, 0.15)
