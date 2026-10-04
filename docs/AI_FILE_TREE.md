# AI entry point — load only the relevant branch

This is the authoritative dependency map (updated for **v0.6**; see `docs/IMPLEMENTATION_v0.6.md` for the audit/balance changelog). Historical v0.2–v0.4 implementation documents describe earlier builds, not current campaign behavior. **Do not rewrite `ui/main.gd` to implement game features.** It is a 41-line screen router.

## Dependency tree

```text
project.godot
├── autoload/data_registry.gd                 resource catalog / startup
│   ├── core/campaign/campaign_loader.gd      JSON → LevelData / MapData
│   │   ├── data/campaign/lawn.json           levels 001–025
│   │   ├── data/campaign/pool.json           levels 026–050
│   │   ├── data/campaign/night.json          levels 051–075
│   │   ├── data/campaign/desert.json         levels 076–100
│   │   ├── data/campaign/roof.json           levels 101–125
│   │   ├── data/campaign/frost.json          levels 126–150
│   │   ├── data/campaign/factory.json        levels 151–175
│   │   ├── data/campaign/moon.json           levels 176–200
│   │   └── core/data/{level_data,map_data,map_node_data}.gd
│   ├── data/plants/*.tres → core/data/plant_data.gd
│   ├── data/zombies/*.tres → core/data/zombie_data.gd
│   └── data/fusion/*.tres → core/data/fusion_recipe.gd
├── autoload/save_manager.gd                  save v3 / inventory / upgrades / atomic write + corrupt backup
│   └── core/campaign/campaign_progress.gd    world & level unlock checks
├── autoload/game_state.gd                    navigation / victory rewards
│   ├── campaign_progress.gd                 rejects locked level starts
│   └── save_manager.gd                       stars, plants, coins, materials
└── ui/main.gd                               screen routing ONLY
    ├── ui/hub_screen.gd → campaign_progress.gd
    ├── ui/map_screen.gd → LevelData / campaign_progress.gd
    ├── ui/workshop_screen.gd
    │   └── core/systems/crafting_system.gd
    │       ├── data/crafting/workshop.json   23 recipes: 8 tools, 8 licenses, 7 tiered upgrades
    │       └── save_manager.gd               atomic costs / inventory
    └── core/battle.gd                        orchestration, existing input & FX
        ├── core/board.gd                     occupancy / grass-water geometry / neighbor_row()
        ├── core/wave_director.gd             explicit wave timing & queues (crowd hold ≤15 s/wave)
        │   └── LevelData.wave_specs          authored enemy/lane/delay records
        ├── core/systems/objective_tracker.gd battle-local objective counters + post-wave stall guard
        ├── core/systems/field_rules.gd       biome pulses / blocked-tile overlay
        ├── core/systems/mission_actions.gd   plant-free artillery / free holdout repairs
        ├── core/fusion_system.gd             graft/evolution evaluation
        ├── ui/hud.gd + ui/mission_panel.gd    normal HUD + objectives/tools
        ├── ui/seed_packet.gd + ui/wave_progress.gd   v0.7 PvZ2 seed bank / wave bar
        ├── ui/loading_screen.gd, main_menu.gd, help_screen.gd, stats_screen.gd, settings_screen.gd (v0.7)
        ├── core/fusion_system.gd               EVOLVE / GRAFT / STAR plans, glove fusion
        └── autoload/audio_manager.gd (Sfx)     buses, sfx, music
        ├── entities/plants/plant.gd          health / loss accounting / animation
        │   ├── plant_shooter.gd / plant_wall.gd / other existing behaviors
        │   └── plant_dual_{shooter,wall}.gd   hybrid production components
        └── entities/zombies/zombie.gd        FSM / status effects / lane membership
            ├── zombie_support.gd            heal / armor / haste / summons
            ├── zombie_trickster.gd          swim / phase / lane changes / vault
            ├── zombie_ranged.gd             lob / sun drain / seed chill
            ├── zombie_adaptive.gd           rage / revive / resist / split
            ├── zombie_bomber.gd             telegraphed contact fuse
            └── zombie_gargantuan.gd → zombie_brute.gd
                ├── gargantuan_granite.gd     half-health imp throw
                ├── gargantuan_furnace.gd     short-range heat pulses
                └── gargantuan_storm.gd       EMP + adjacent-lane attacks
```

## Balance tooling (offline Python, never loaded by the game)

```text
tools/balance/level_metrics.py   per-level HP / spawns / sun / objectives table (read-only)
tools/balance/remix_v06.py       one-shot v0.6 data pass (scenario remix, spike trim, objective variety); refuses re-run
tools/balance/ease.py            targeted, logged easing step -> docs/testing/balance_log.json
tools/tests/run_bots.py          --strategy standard|strong  (strong = v0.6 reference for worlds 3-8), --timeout, flags script errors
tools/tests/fuzz_test.tscn       random-input fuzzer over campaign/endless/daily (-- seconds per level)
tools/tests/regression_v071.tscn assertions for the v0.7.1 audit fixes
core/seed_state.gd               recharge() applies Sprinkler / Seed Pouch upgrades
```

## Minimal reading sets by task

| Task | Read first | Edit boundary | Test |
|---|---|---|---|
| Tune one level | `docs/CAMPAIGN_FORMAT.md`, that world's JSON, `docs/testing/balance_log.json` | One `levels[]` entry or `tools/balance/ease.py`, not the loader | `validate_campaign.py` (briefing must state every target); strong bot x2 for that ID |
| Add a world mechanic | `field_rules.gd`, `level_data.gd`, target manifest | Field rule module + data | Contract suite and biome bot |
| Add an objective | `objective_tracker.gd`, `battle.gd` hooks, `mission_panel.gd` | Objective module; add only necessary event hooks | Objective boundary assertions |
| Change progression | `campaign_progress.gd`, `game_state.gd`, save migration | No star-based shortcut gates | Progression assertions |
| Add a zombie | `zombie_data.gd`, one behavior family, one `.tres` | New behavior only for a genuinely new mechanism | Enemy instantiation / ability tests |
| Add a Gargantuan | Shared giant module + one variant | Do not duplicate base FSM | Half-health and status tests |
| Add a graft | Ingredient resources, `fusion_system.gd`, result behavior | One recipe + one result resource | Ingredient references / combat test |
| Change workshop recipe | `workshop.json`, `crafting_system.gd` | Recipe data, not UI transaction logic | Cost / unlock / inventory tests |
| Change battle UI | `mission_panel.gd` or `hud.gd` | Keep counters owned by tracker | Screens and offscreen UI capture |
| Graphics later | `docs/ANIMATION.md`, `core/rig.gd` | Existing fallback works without new rigs | Visual capture, no combat rewrite |

## Ownership and invariants

- JSON manifests are the shipped campaign source of truth. No procedural content is created during play.
- `tools/generate_campaign.py` reproduces the initial authored baseline and **overwrites** manifests and new content only with explicit `--overwrite`. It is not a migration or everyday balance editor.
- World order is `lawn → pool → night → desert → roof → frost → factory → moon`.
- Each world has 25 mandatory levels. Clearing every level, not collecting a shortcut star threshold, unlocks the next world.
- Boss spawns are explicit; difficulty cannot randomly double bosses.
- Use battle-local counters for objectives. Never use lifetime SaveManager statistics.
- Every objective target number must appear in the level briefing (validator-enforced since v0.6).
- Lane-changing effects (splits, imp throws, low gravity) use `Board.neighbor_row()`; never `% ROWS`.
- Bought sun (Sun Flask) never counts toward `collect_sun`. Workshop upgrades are optional and never assumed by mission balance.
- Keep replacements, normal planting, and deliberate consumptions distinct. Silent transformations and single-use triggers do not count as losses.
- Mission supply decks and prepared gardens do not require prior plant unlocks. No mission requires purchased consumables.
- Do not run legacy `tools/build_data.gd` unless deliberately rebuilding the historical prototype.
- Re-run Godot import after adding global classes; run the contract suite after schema changes.
