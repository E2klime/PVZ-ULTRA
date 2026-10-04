class_name ZombieSupport
extends Zombie
## Healers, shield repairers, squad leaders and limited summoners.
var _timer: float = 6.0
var _uses: int = 0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if preview or not is_alive() or is_frozen() or stun_t > 0.0: return
	_timer -= delta
	if _timer > 0.0: return
	_timer = data.ability_interval
	match data.ability_kind:
		&"heal", &"repair", &"haste", &"shield_aura":
			for rr: int in range(maxi(0, row - 1), mini(Board.ROWS, row + 2)):
				for z: Zombie in battle.zombies_in_row(rr):
					if not z.is_alive() or absf(z.position.x - position.x) > 220: continue
					match data.ability_kind:
						&"heal": z.hp = minf(z.max_hp, z.hp + data.ability_power)
						&"repair": z.armor = minf(z.max_armor, z.armor + data.ability_power)
						&"shield_aura":
							z.max_armor = maxf(z.max_armor, 100.0)  # keeps the armour bar and HP maths consistent
							z.armor = minf(z.max_armor, z.armor + data.ability_power)
						&"haste": z._push_left -= data.ability_power
		&"summon":
			if _uses < data.ability_limit and position.x < Board.SPAWN_X - 100 and position.x > Board.ORIGIN.x + 200:
				_uses += 1
				var child := battle.spawn_zombie(data.summon_id, row)
				if child: child.position.x = position.x + 65
	battle.fx_puff(position + Vector2(0, -90), 20)
