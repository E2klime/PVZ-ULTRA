class_name ZombieTrickster
extends Zombie
## Lane changers, phase walkers, divers and single-use vaults.
var _timer: float = 5.0
var _phase_left: float = 0.0
var _vaulted: bool = false

func base_speed() -> float:
	if data.ability_kind == &"swimmer" and submerge > 0.5: return data.speed * 1.7
	if data.ability_kind == &"skater" and slow_t <= 0.0: return data.speed * 1.35
	return data.speed

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if preview or not is_alive() or is_frozen() or stun_t > 0.0: return
	if _phase_left > 0.0:
		_phase_left -= delta
		if _phase_left <= 0.0:
			underground = false
			modulate.a = 1.0
	hop = move_toward(hop, 0.0, delta * 180.0)
	_timer -= delta
	if _timer > 0.0: return
	_timer = data.ability_interval
	if position.x < Board.ORIGIN.x + 220: return
	match data.ability_kind:
		&"sidestep":
			var next_row := row + (1 if row == 0 else (-1 if row == 4 else (1 if randi() % 2 else -1)))
			move_to_row(next_row)
		&"phase", &"dive":
			if data.ability_kind != &"dive" or submerge > 0.5:
				underground = true
				_phase_left = 2.0
				modulate.a = 0.45

func _on_plant_blocking(p: Plant) -> bool:
	if data.ability_kind == &"vault" and not _vaulted and not p.data.tags.has(&"tall"):
		_vaulted = true
		position.x -= Board.CELL.x * 1.1
		hop = 65.0
		return true
	if underground: return false
	return super._on_plant_blocking(p)
