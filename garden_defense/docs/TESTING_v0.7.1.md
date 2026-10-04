# Testing — v0.7.1

Run every scene with an isolated `HOME` (tests replace the in-memory save and may write test inventory).

```bash
python3 tools/tests/validate_campaign.py
godot --headless --path . res://tools/check_all.tscn                                  # exits 1 on any failure
godot --headless --path . --fixed-fps 60 res://tools/autotest.tscn -- mech
godot --headless --path . --fixed-fps 60 res://tools/tests/campaign_test.tscn
godot --headless --path . -s res://tools/tests/loc_test.gd
godot --headless --path . --fixed-fps 60 res://tools/tests/regression_v071.tscn
godot --headless --path . --fixed-fps 60 res://tools/tests/fuzz_test.tscn -- 60       # seconds per level
python3 tools/tests/run_bots.py --godot $(command -v godot) --all --jobs 2 --timeout 900 --out /tmp/bots
python3 tools/tests/run_bots.py --godot $(command -v godot) --levels moon_24 --strategy strong
```

## Results on the release tree

| Suite | v0.7 (as received) | v0.7.1 |
|---|---|---|
| Static validator | PASS | PASS (data unchanged) |
| `check_all` | 104 scripts, exit 0 even on failure | 106 scripts, 0 failures, real exit code |
| Mechanics autotest | OK | OK (same output) |
| Contract suite | 16,954 checks / 0 failures | 16,954 / 0 |
| Localisation | PASS | PASS (+ `TOAST_TOOL_NO_EFFECT` in 5 languages) |
| Regression (new) | — | 33 checks / 0 failures |
| Fuzz (new; 12 levels incl. Endless Lawn/Pool/Roof and Daily) | ≈ 8,700 `SCRIPT ERROR`s, leaks at exit | 0 errors, clean exit |
| Bot sweeps | every run flagged errors (exit leaks); soft-lock timeouts on lawn_22, pool_01, pool_09 | 0 errors, 0 timeouts in 200 + 46 runs |

## Bot sweep (Standard difficulty, frozen snapshot)

Standard bot on all 200 missions, then the `strong` reference bot on each loss (same method as the v0.6 record).
Per-level results: `docs/testing/bot_sweep_v071.json`.

| World | v0.6 final | v0.7.1 standard | v0.7.1 standard + strong |
|---|---:|---:|---:|
| Lawn | 25 | 25 | **25** |
| Pool | 25 | 24 | **24** |
| Night | 23 | 19 | **19** |
| Desert | 25 | 19 | **20** |
| Roof | 24 | 20 | **21** |
| Frost | 23 | 18 | **21** |
| Factory | 20 | 15 | **15** |
| Moon | 18 | 14 | **15** |
| **Total** | **183** | **154** | **160 (80 %)** |

For comparison, the standard bot on the code as received (before the mower fix) won 112/200; on the 73 missions
the original bot could finish, the original bot won 39 and the updated bot 56, both still without the mower fix.

## Balance-watch list (needs human playtest — no data was changed)

The remaining gap to v0.6 comes from v0.7 content: Box, Balloon and Slingshot zombies were added to many v0.6 waves,
and several missions have a *no breach* or tight *plants lost* limit. One balloon or glider that slips past the
anti-air loses such a mission outright; the bot never heals, grafts for power or uses tools.

- Lost by a single breach (Balloon / Glider): `night_06`, `desert_07`, `roof_07`, `frost_06`, `factory_10`, `moon_07`, `moon_20`, `moon_25`.
- Plants-lost limit: `pool_06`, `night_07`, `night_12`, `desert_10`, `frost_17`, `factory_07`, `factory_11`, `factory_17`, `moon_06`, `moon_10`, `moon_12`.
- Endgame combat: `night_18`, `night_23`, `night_24`, `desert_17`, `desert_24`, `desert_25`, `roof_14`, `roof_18`, `roof_24`, `frost_23`, `frost_24`, `factory_12`, `factory_13`, `factory_19`, `factory_23`–`25`, `moon_14`, `moon_18`, `moon_19`, `moon_23`.

Suggested first step for a designer: in the *plant-limit* and *no-breach* missions, either keep Balloon zombies out of
the first two worlds' early waves or add Spine Cactus / Garlic Drone to the suggested seeds and mention anti-air in the
briefing.

## Not covered

Hard/Hard+, real touch devices (back button, long-press and drag settings were tested only through code paths),
audio on real hardware, native export (Godot export templates are not part of the supplied toolset).
