class_name ZombieRanged
extends Zombie
## Lobbers pressure a visible front plant; economy thieves have bounded drains.
var _timer: float = 5.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if preview or not is_alive() or is_frozen() or stun_t > 0.0: return
	_timer -= delta
	if _timer > 0.0 or position.x > Board.SPAWN_X - 80: return
	_timer = data.ability_interval
	if data.ability_kind == &"drain":
		battle.sun = maxi(0, battle.sun - int(data.ability_power))
		battle.hud.update_sun()
		battle.hud.toast(tr("TOAST_SUN_STOLEN"))
		return
	var victim: Plant
	for p: Plant in battle.board.all_plants():
		if p.row == row and not p.is_air() and p.data.layer != &"under" and p.position.x < position.x and position.x - p.position.x < 650:
			if victim == null or p.col > victim.col: victim = p
	if victim:
		victim.take_damage(data.ability_power, self)
		battle.fx_hit(victim.position + Vector2(0, -50), data.color_cloth)
		if data.ability_kind == &"freeze_seed":
			for seed: SeedState in battle.seeds:
				if seed.data.id == victim.data.id: seed.cooldown = maxf(seed.cooldown, 3.0)
