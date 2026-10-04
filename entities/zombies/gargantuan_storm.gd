class_name GargantuanStorm
extends ZombieGargantuan
## Telegraphs a nearby-lane EMP. No permanent disabling of seeds.
func special() -> void:
	battle.hud.banner(tr("BANNER_GARGANTUAN_STORM"), 2.0)
	for seed: SeedState in battle.seeds: seed.cooldown = maxf(seed.cooldown, 4.0)
	pulse()

func pulse() -> void:
	for rr: int in [row - 1, row, row + 1]:
		var nearest: Plant
		for p: Plant in battle.board.all_plants():
			if p.row == rr and not p.is_air() and absf(p.position.x - position.x) < 350:
				if nearest == null or p.col > nearest.col: nearest = p
		if nearest:
			nearest.take_damage(70.0, self)
			battle.fx_hit(nearest.position, Color.CYAN)
