class_name ZombieGargantuan
extends ZombieBrute
## Shared giant stages. One special at half HP; variants own the special action.
var _special_used: bool = false
var _cooldown: float = 12.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if preview or not is_alive() or is_frozen() or stun_t > 0.0: return
	if not _special_used and hp <= max_hp * 0.5:
		_special_used = true
		special()
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = data.ability_interval
		pulse()

func special() -> void:
	pass

func pulse() -> void:
	pass
