# Garden Defense — Core v1 (Lawn)

Godot **4.4** (compatible with 4.3), GDScript with strict typing, renderer: Compatibility (GL).

## Run
1. Open `project.godot` in Godot 4.4 → the editor imports assets.
2. Main scene: `res://ui/main.tscn` (F5).

## Controls (battle)
- Click a seed card (or keys `1`–`0`), then click a cell; drag & drop also works.
- `Q` / `S` — shovel; right click — cancel selection; `Esc`/`P` — pause.
- Use the HUD speed control to switch between ×1 and ×2.
- Drop a plant onto a compatible plant → **Graft** (hybrid) or **Evolve** (same plant), costs sun + fee.
- Debug: `F2` +500 sun, `F3` skip wave, `F4` instant win.

## Difficulty (`data/difficulties/*.tres`)
| | Standard | Hard | Hard+ |
|---|---|---|---|
| Zombie speed | 100% | 110% | 115% |
| Zombie DPS | 100% | 120% | 140% |
| Damage taken by zombies | 100% | 80% | 75% |
| Wave budget (spawn count) | ×1.0 | ×1.3 | ×1.6 |
| Spawn interval | ×1.0 | ×0.85 | ×0.75 |
| Coins | ×1.0 | ×1.15 | ×1.30 |

## Structure
- `autoload/` — EventBus, DB (data registry), SaveManager (`user://save.json`), Settings, GameState.
- `core/` — battle controller, board, wave director, fusion system, data classes (`core/data`).
- `entities/` — plants, zombies, projectiles, effects (procedural cel-style drawing).
- `ui/` — all screens (menu, hub, map, seed select, HUD, almanac, quests, shop, settings) + theme.
- `data/` — all content as `.tres` (plants, zombies, recipes, levels, map, quests, shop).
- `localization/translations.csv` — keys + EN (columns: keys,en,ru,zh_CN,ja,de — only EN filled).

## Regenerating data
Content tables live in `tools/build_data.gd`:
```
godot --headless --path . -s res://tools/build_data.gd
python3 tools/strings_en.py      # rebuild translations.csv
godot --headless --path . --import
```
Bot test: `godot --headless --path . --fixed-fps 60 res://tools/autotest.tscn -- lawn_03 standard`

## Notes / placeholders
- Battle entities use procedural vector drawing; the menu uses an original generated illustration plus code-driven ambience.
- No music/sound (per request).
- Only Lawn biome is playable; other hub biomes are locked placeholders.

## 2026-10-03 update
- Two playable route maps: Lawn and Poolside.
- Rebuilt pressure-based waves with fairer lane/elite distribution and escalating tempo.
- Gate integrity replaces one-hit loss: 3 points, with heavy escapes costing 2.
- Added ×2 speed, dedicated pause UI, illustrated/animated main menu, and per-map route saves.
- The imported v0.2 GDD has since been replaced by the English `docs/DESIGN.md`.

Poolside currently uses the core grass-board combat rules; water-row mechanics remain future work.
