# Implementation snapshot — v0.4

## Art (all painted procedurally; the image-generation tool wasn't available)
- `tools/art/paint/kit.py`: shape masks → height field → normals → toon/half-Lambert shading, rim, specular, AO, coloured outline.
- `plants.py`: 29 plant rigs, including the new Lily Raft. `zombies.py`: 9 zombie part sets with headgear stages, shields, props and a swim ring.
- `core/rig.gd` loads and caches the rigs. All per-plant procedural `draw_body()` code is gone; subclasses only override rig hooks.
- Plants blink, shooters alternate muzzles, and walls and armour show damage stages. Zombies use two-bone limbs.
- Fixes: shooters no longer get stuck as tiny sprouts (grow/alpha are reset outside spawn/die clips, and action clips restart from frame 0).
  Wobble and recoil springs are substepped and clamped.

## Board
- The semi-transparent grass overlay is gone. Every land cell is an opaque painted tile (light/dark checker, 4 variants each).
- Water cells come from `LevelData.water` (free-form mask) and are drawn with `shaders/water.gdshader`.
- Modular coping (edge, outer corner, convex corner) is laid out automatically for any mask. The hover highlight is now its own layer.

## Pool mechanics
- **Lily Raft** (25 sun, water only) is added for free to the seeds on pool levels. Any lawn plant can be planted on it.
  The raft comes back with its old HP when the plant on it dies. Grafting and evolving on a raft keep the raft.
- New error message: `MSG_NEEDS_RAFT`.
- Zombies swim: `submerge` follows the cell surface, the body sinks, the legs fade, and the swim ring and ripples are drawn.
- Layouts: Poolside 1 (pond), 2 (pool with island), 3 (diagonal channel), 4 (two pools), 5 (lagoon with island), 6 (meander), bonus (S-channel).

## Balance
- Defaults: `first_wave_delay` 28 → 40 s, `wave_interval` 28 → 34 s. The gap curve changes from ×1.08→0.72 to ×1.10→0.85, and the minimum gap from 7 to 14 s.
  Clearing the lawn skips ahead to 12 s, not 4 s. Waves spread over 6–20 s instead of 4–13 s, and the crowd limit is lower.
- Speeds (cells/s): Shambler 0.19→0.17, default/Cone/Bucket 0.21→0.18, Flagbearer 0.32→0.28, Sprinter 0.45→0.36,
  Hurdler 0.42→0.34, Burrower 0.40→0.32, Shield Carrier 0.19→0.17, Brute 0.14→0.13.
- Difficulty: Hard ×1.15 count, ×1.0 speed, ×1.15 bite, ×0.90 damage taken, ×1.0 gap, ×1.25 coins.
  Hard+ ×1.25 count, ×1.05 speed, ×1.30 bite, ×0.85 damage taken, ×0.95 gap, ×1.5 coins.
- Wave growth is lower on Poolside 1–6 and the bonus level (0.62–0.80) and on Lawn 11–13 (0.84–0.86).
  Poolside 5 starts with 100 sun and Poolside 6 with 150.
- Non-basic zombies unlock later in a level: from wave `2 + floor(cost × 0.8)` instead of `1 + floor(cost × 0.7)`.
  Cones and Sprinters now first appear in wave 3, and Brutes in wave 9.
- The bot now floats rafts on water cells before planting and prefers lawn cells.

### Bot results (basic roster, no legendaries, no Rime Lettuce)
Final configuration, last batch: Poolside 3 Hard+ won, Poolside 4 Hard+ won, Poolside 5 Hard+ 1 of 2 won,
Poolside 6 Hard+ won, Lawn 13 Hard+ won, Lawn Bonus 2 Hard won, Lawn 1 Standard won (7 of 8 overall).
Earlier tuning batches won every Standard run (Lawn 3, 5, 10; Poolside 1, 2, 3, 4) and every Hard run (Lawn 8, Poolside 5, Poolside 6).
They also won Lawn 12 Hard+ twice.
In v0.3 the same bot lost Poolside 5 on Hard and Lawn 13 on Hard+.

## UI
- The map panel no longer has difficulty buttons. It shows "Difficulty: X (change it in Settings)".
- Almanac: every entry is visible, with no "???". The stat sheets cover cost, recharge, first-seed delay, HP and surface;
  damage, rate, DPS, range, pierce, slow, area, burn, freeze, chain, stun, thorns, push, pull, regeneration and rebirths;
  sun per minute, arming and chewing times, buffs, summons, graft-ready time, board limit, evolution and recipes.
  Zombie sheets cover HP, armour, toughness, speed in cells/s and px/s, time to cross the lawn, bite, eating DPS,
  wave cost, Pod Shooter hits to kill and immunities. The Grafts tab lists every recipe with its full cost.

## Docs
- The Russian v0.2 GDD was deleted. Its decisions are carried over and updated in English in `docs/DESIGN.md`.
- New `docs/ROADMAP.md` with milestones, tasks, dependencies and acceptance checks. README and ANIMATION docs are updated.
- The repository has no Cyrillic left. The language picker label "Russian" is in English.
