class_name ZombieData
extends Resource

@export var id: StringName
@export var name_key: String
@export var desc_key: String
@export var hp: int = 270
@export var armor_hp: int = 0
## &"none", &"cone", &"bucket", &"shield", &"box", &"balloon"
@export var armor_kind: StringName = &"none"
## Cells per second.
@export var speed: float = 0.18
## Damage per second while eating.
@export var damage: float = 100.0
@export var eat_interval: float = 0.5
## Behaviour script (extends Zombie).
@export var behavior: Script
@export var spawn_surfaces: Array[StringName] = [&"grass"]
## &"devour", &"push", &"slow", &"pull"
@export var immune_to: Array[StringName] = []
@export var threat_cost: float = 1.0
@export var weight: float = 10.0
@export var body_scale: float = 1.0
@export var color_skin: Color = Color(0.6, 0.72, 0.55)
@export var color_cloth: Color = Color(0.42, 0.33, 0.5)

## Hierarchy: 1 basic, 2 armored, 3 specialist, 4 elite, 5 giant/boss.
@export var tier: int = 1
## &"ground" (normal), &"low" (Box: only lobbed, low and from-below attacks
## reach it), &"air" (Balloon: only anti-air and flying plants reach it).
@export var profile: StringName = &"ground"
## Formation follower: tucks in right behind the nearest zombie ahead in its lane.
@export var follow_leader: bool = false
## Slingshot: shoots flying plants from range.
@export var targets_air: bool = false

@export_group("Abilities")
@export var ability_kind: StringName = &""
@export var ability_interval: float = 9.0
@export var ability_power: float = 40.0
@export var summon_id: StringName = &""
@export var ability_limit: int = 3
