class_name SeedState
extends RefCounted
## Runtime state of one seed slot during a battle.

var data: PlantData
var cooldown: float = 0.0

func _init(d: PlantData) -> void:
	data = d
	cooldown = d.start_cooldown * SaveManager.opening_cooldown_mult()

func is_ready() -> bool:
	return cooldown <= 0.0

func progress() -> float:
	if recharge() <= 0.0:
		return 1.0
	return 1.0 - clampf(cooldown / recharge(), 0.0, 1.0)

func recharge() -> float:
	return data.recharge * SaveManager.recharge_mult()

func trigger() -> void:
	cooldown = recharge()
