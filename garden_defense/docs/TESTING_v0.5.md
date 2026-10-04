# v0.5 validation and QA

## Reproduce safely

Tests replace the in-memory save and some tests write inventory. Use a throwaway HOME (Linux) or an isolated Godot user-data directory, never your real player save.

```bash
export HOME="$(mktemp -d)"
python3 tools/tests/validate_campaign.py
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 res://tools/tests/campaign_test.tscn
python3 tools/tests/run_bots.py --godot /path/to/godot --jobs 2
# One level or a targeted group:
python3 tools/tests/run_bots.py --godot /path/to/godot --levels lawn_09 lawn_14
# Optional long-running, broad balance diagnostic:
python3 tools/tests/run_bots.py --godot /path/to/godot --all --jobs 2
```

The static validator checks all level IDs, world order, 5×9 layouts, every spawn/seed/reward/recipe reference, objective feasibility contracts, preplant coordinates, 200 unique titles, and 200 unique opening joke combinations. Scraplings are created by Scrapbot's death split, not scheduled directly.

The Godot contract suite loads every mission, starts its first authored wave, checks plant-free modes, tests artillery damage and free holdout repairs, runs all 46 zombie behaviors/status/death paths, verifies objective boundaries, tests workshop cost/persistence, walks all 200 progression unlocks, checks legacy-save migration, and opens the major UI screens.

## Coverage boundaries

- Instantiating a mission is **not** a complete playthrough.
- The bot does not cheat sun, health or cooldowns, but unlocks all seed forms and uses a small fixed strategy to isolate combat pacing.
- A bot defeat is a balance/strategy diagnostic, not automatically proof that a level is impossible or that a script failed. Exit 2 means the bot lost; exit 3 means simulated-time timeout. Runtime script errors are recorded separately.
- The contract suite's progression walk injects clears to test unlock rules; it does not claim to have beaten 200 levels.
- Only representative Standard missions were combat-tested. All 200 human playthroughs, Hard/Hard+ balance, mobile inputs and performance remain production QA work.
- Graphics are intentionally not a new-art deliverable. Offscreen captures verify the world hub, workshop, 25-node map, seed selection, and final-world battle HUD.

## Export check

The Linux preset explicitly includes `*.json`, so campaign/workshop data and sprite rigs are packaged. A `.pck` was exported and loaded with the supplied Godot 4.7.2 engine in a clean user directory. This verifies runtime data inclusion; a native platform executable was not built.

```bash
godot --headless --path . --export-pack "Linux Desktop" game.pck
godot --headless --main-pack game.pck --quit-after 30
```

Visual tests run under Xvfb using software OpenGL and the Dummy audio driver. Missing audio hardware in the sandbox is not treated as game audio QA.

## Recorded results

See `docs/testing/` for the static-validation output, final contract-suite output, representative bot outcomes, and export-smoke log. The outcomes intentionally distinguish wins, defeats, timeouts, and script errors rather than hiding failed runs.


### Final recorded summary

- Static content validation passed for all 200 missions, 8 worlds, 46 plants, 46 zombies, 24 grafts, and 14 workshop recipes.
- Final Godot contract suite: **16,117 checks, 0 failures**; all 200 missions loaded and started.
- Representative Standard bot runs: **13/17 wins**, 4 gameplay defeats, **0 runtime-script errors**. All tested objective categories have at least one successful representative except the deadline/rush category; its loss was from combat, not the 600-second deadline.
- Remaining balance-watch missions from this diagnostic: `lawn_11`, `factory_25`, `moon_24`, `moon_25`. The current bot does not exploit the full late-game plant/recipe roster or consumables; these need stronger-strategy and human playtests, not a false claim of verified perfect balance.
- Both repaired holdout diagnostics (`night_21`, `frost_21`) won with no planting and no consumables.
- Five final offscreen UI captures completed. Exported `.pck` startup completed without missing-data or script errors.
