class_name ZombieAdaptive
extends Zombie
## Newspaper rage, single resurrection, reactive armor and death splitting.
var _reborn: bool = false

func base_speed() -> float:
	return data.speed * (2.0 if data.ability_kind == &"rage" and hp < max_hp * 0.55 else 1.0)

func absorb(amount: float, kind: StringName) -> float:
	if data.ability_kind == &"resist" and kind == &"projectile" and armor > 0:
		amount *= 0.65
	return super.absorb(amount, kind)

func die(kind: StringName = &"normal") -> void:
	if not is_alive(): return
	if data.ability_kind == &"revive" and not _reborn and kind != &"mower":
		_reborn = true
		hp = max_hp * 0.35
		stun_t = 2.0
		battle.fx_puff(position, 35)
		return
	if data.ability_kind == &"split" and kind != &"mower":
		for rr: int in [row, Board.neighbor_row(row)]:
			var child := battle.spawn_zombie(data.summon_id, rr)
			if child: child.position.x = position.x + 55
	super.die(kind)
