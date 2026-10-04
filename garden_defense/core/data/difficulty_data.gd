class_name DifficultyData
extends Resource

@export var id: StringName
@export var name_key: String
@export var order: int = 0
@export var zombie_speed_mult: float = 1.0
## Applied to zombie bite damage (their DPS).
@export var zombie_dps_mult: float = 1.0
## Damage zombies receive from plants.
@export var zombie_damage_taken_mult: float = 1.0
## Threat budget per wave (how many zombies).
@export var zombie_count_mult: float = 1.0
## < 1.0 means waves come faster (higher spawn rate).
@export var spawn_interval_mult: float = 1.0
@export var coin_reward_mult: float = 1.0
