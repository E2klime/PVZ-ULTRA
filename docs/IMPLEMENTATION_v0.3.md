# Implementation snapshot — v0.3 (animation update)

## Added
- **Animation**: AnimationPlayer-driven pose rigs for all plants and zombies (see `ANIMATION.md`).
  Gameplay events are tied to key frames: shots, sun, bites, footsteps.
- **Rime Lettuce** (`plant_freeze.gd`): costs 0 sun, 20 s recharge. Zombies walk over it; the first to touch it is frozen
  for 10 s (5 s for push-immune heavies), then thaws with a shatter and a 4 s slow. The lettuce is used up.
  Rewards: Lawn 11, Poolside 1.
- **Legendary rarity** (new PlantData fields: `rarity`, `max_on_board`, `freeze_time`, `chain_count`,
  `chain_range`, `stun_time`, `regen_per_sec`, `rebirths`). Max 1 of each on the board (`MSG_LEGENDARY_LIMIT`).
  Gold seed cards, almanac tiles, an aura and a shimmer.
  | Plant | Cost | Effect | Source |
  |---|---|---|---|
  | Sun Sovereign | 250 | 50 sun every 20 s, buffs neighbours ×1.2 | Shop 900 |
  | Phoenix Lily | 325 | piercing fire bolts (pierce 2, burn 20 dps for 3 s), reborn once | Shop 1200 |
  | Storm Thistle | 350 | chain lightning: 4 extra jumps, 70 % falloff, 0.4 s stun | Pool 6 / Shop 1500 |
  | Elder Oak | 300 | 9000 HP wall, thorns 25, regenerates 60 HP/s after 4 s unbitten, tall | Lawn 13 / Shop 1500 |
- Shop items can now sell plants (`kind = "plant"`, `plant_id`).
- Generated battle backdrops (lawn/pool), seamless grass tile, map and greenhouse-hub art; Inkscape FX sheets.
- New tools: `tools/build_anims.gd`, `tools/art/*`, `tools/showcase.tscn`, hub screenshot,
  `autotest -- mech` mechanics suite (bot disabled).

## Fixed
- `tools/strings_en.py` is the source of truth again. It now includes 23 strings that only
  existed in `translations.csv` in v0.2, so regenerating no longer drops them.
- `build_data` runs as a scene (`build_data.tscn`) because it needs autoloads.

## Verified
- `autotest -- mech`: all checks pass (freeze/thaw, legendary limit, regen, rebirth, chain, death clip, anim speeds).
- Bot runs complete without script errors. With a starter roster the bot wins Lawn 3 Standard and loses
  the late Pool 5 Hard and Lawn 13 Hard+ stages, which is expected.

## Still open
- Water lanes for Poolside (unchanged from v0.2).
- Krita isn't usable on glibc < 2.35 (see `ANIMATION.md`).
