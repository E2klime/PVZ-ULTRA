# Garden Defense v0.7 — implementation notes

## 1. Phone build bug (blank seed cards, missing backdrop, dark tiles)
`core/rig.gd` checks `FileAccess.file_exists(".../rig.json")` before loading a painted rig. JSON is not a Godot
resource, so a preset without `include_filter="*.json"` silently dropped all rigs and campaign files; every plant
fell back to a flat placeholder. Fixes:
- Both export presets include `*.json`; the Android preset excludes `docs/ tools/ art_src/ exports/`.
- Battle backdrops are chosen per world (`assets/art/bg/battle_<world>.jpg`) and the old dark board tint was removed.
- Verified: the debug APK contains 113/113 `rig.json`; an exported `.pck` run with `--main-pack` renders all portraits.

## 2. Data model
- `PlantData`: `layer` (under/main/shell/air), `attack_kind` (straight/lob/low/air/anti_air), `speed_aura`, `aura_radius`, `badge`.
- `ZombieData`: `tier`, `profile` (ground/low/air), `follow_leader`, `targets_air`.
- `Board` stores one plant per layer per tile (`get_layer/set_layer/cell_plants`). Zombies eat shell → main → under; air plants
  are only reachable by `targets_air` zombies.
- `Zombie.hittable_by(kind)` implements profiles: low (box) ignores straight/anti-air; air (balloon) is hit only by
  anti-air, air, wind, chain, explosions, bees, freeze, burn, thorns.

## 3. Fusion & glove (`core/fusion_system.gd`, `core/battle.gd`)
- Plan kinds: EVOLVE, GRAFT, STAR. Recipes are order-independent (`DB.find_recipe`).
- Same seed → evolution (after the feature unlocks) or a star (max 3; +damage/HP/attack speed).
- Seeds only fuse with the same-layer occupant; cross-layer grafts (e.g. Pumpkin Shell + Bramble Vine → Thorn Pumpkin) use the glove.
- Glove: pick the top plant, drop on an empty layer (move), on a raft, or on a plant (fuse, fee only). 6 s recharge (3 s in puzzles).

## 4. Content
- 18 new plants (`tools/gen_v07_data.py`), 3 new zombies + tiers (`tools/gen_v07_zombies.py`), campaign rewards/spawns
  (`tools/campaign_v07.py`). Painted rigs: `tools/art/paint/plants_v07.py`, `zombies_v07.py`. UI icons/logo: `tools/art/ui_icons.py`.
- Audio: `tools/audio/gen_audio.py` → `audio/sfx/*.wav`, `audio/music/*.wav`; `Sfx` autoload.

## 5. UI
`ui/hud.gd` (PvZ2 layout), `ui/seed_packet.gd`, `ui/wave_progress.gd`, `ui/loading_screen.gd`, `ui/main_menu.gd`,
`ui/settings_screen.gd` (7 tabs, `Switch` widget), `ui/help_screen.gd`, `ui/stats_screen.gd`, `ui/mission_panel.gd`
(status under the wave bar, tools along the bottom). UI text sources now live in `tools/localization/src/` (see `docs/LOCALIZATION.md`).

## 6. Tests run for this release
- `tools/tests/validate_campaign.py`: PASS (200 levels, 64 plants, 49 zombies, 32 grafts).
- `tools/check_all.tscn`: all 102 scripts compile.
- `autotest -- mech`: layers (4 plants on one tile), star-up, glove move, glove cross-layer graft, box zombie follows its
  leader and ignores straight shots, ground zombies ignore air plants, balloon zombie destroys a Garlic Drone.
- Bot playthrough of pool_17 (balloons, slingshots, boxes) runs without script errors.
- Screenshots of every screen reviewed (`tools/screenshot.tscn`).

## 7. Known limitations (need humans)
- APK is **debug-signed** and was not tested on a physical device. For Play Store use a release keystore.
- No human playtest / balance pass of the new plants and zombies across 200 levels.
- Art and audio are procedural/AI placeholders. Only English text is complete (other languages fall back to English).

## 7. Hybrids-only + localization update
- Same-seed upgrades (stars) and evolutions were removed. Combining plants only makes hybrids from recipes in
  `data/grafts/` (32 recipes, incl. twin hybrids: Sunflower+Sunflower = Twin Sunflower, Pea Shooter+Pea Shooter =
  Repeater, Iceberg Lettuce+Pea Shooter = Ice Peashooter). Old saves migrate via `SAVE_VERSION` 5.
- Full localization in en/ru/zh_CN/ja/de with CJK fonts - see `docs/LOCALIZATION.md`.
