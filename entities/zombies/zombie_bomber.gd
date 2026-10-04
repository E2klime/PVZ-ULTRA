class_name ZombieBomber
extends Zombie
## Fuse is visibly telegraphed; killing from range safely disarms the bomb.
var _fuse: float = -1.0

func _on_plant_blocking(p: Plant) -> bool:
	if _fuse < 0.0:
		_fuse = 3.0
		battle.hud.toast(tr("TOAST_BOMB_FUSE"))
	return super._on_plant_blocking(p)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if preview or not is_alive() or is_frozen() or stun_t > 0.0: return
	if _fuse >= 0:
		_fuse -= delta
		if _fuse <= 0:
			for p: Plant in battle.board.all_plants().duplicate():
				if abs(p.row - row) <= 1 and not p.is_air() and absf(p.position.x - position.x) < 180:
					p.take_damage(data.ability_power, self)
			battle.fx_explosion(position + Vector2(0, -50), 90, Color.ORANGE)
			die(&"explosion")
