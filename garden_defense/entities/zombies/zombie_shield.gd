class_name ZombieShield
extends Zombie
## Carries a door-shield: blocks frontal projectiles and thorns.
## Explosions, area attacks, bees and bites hit the body directly.

const BLOCKED_KINDS: Array[StringName] = [&"projectile", &"thorns"]

func absorb(amount: float, kind: StringName) -> float:
	if armor <= 0.0 or not BLOCKED_KINDS.has(kind):
		return amount
	return super.absorb(amount, kind)
