# v0.6 validation and QA

Commands are unchanged from `TESTING_v0.5.md` (always use a throwaway HOME). New in v0.6:

```bash
python3 tools/tests/run_bots.py --godot /path/to/godot --all --jobs 2                     # full 200-level sweep
python3 tools/tests/run_bots.py --godot /path/to/godot --levels moon_24 --strategy strong # stronger reference bot
python3 tools/balance/level_metrics.py --csv metrics.csv                                  # static per-level metrics
python3 tools/balance/write_world_guides.py                                               # regenerate docs/campaign/*.md
```

**Run sweeps from a frozen copy of the project.** A sweep reads scripts from disk at each launch; editing
the working tree mid-sweep produced false parse errors during v0.6 development.

## What the suites check

- **Static validator** (+v0.6): every positive objective target appears verbatim in its briefing; titles that lead
  with a number match a real target; upgrade tiers are contiguous.
- **Contract suite** (+v0.6 `_v06()`): lane splits never wrap; upgrade tier gating, effect on seed recharge and
  persistence; atomic save leaves no temp file; Sun Flask does not count as collected; Glue Trap and Sun Magnet work;
  the stall guard fails a cleared, income-less economy mission instead of soft-locking; crowd hold releases the next wave.
- **Bot sweeps:** all 200 missions played to completion on Standard, no sun/HP/cooldown cheats, all seeds unlocked, no workshop upgrades or tools.

## Recorded results (Standard difficulty)

| World | v0.6 sweep 1 (after remix) | **v0.6 final** |
|---|---:|---:|
| 1 Lawn | 25/25 | **25/25** |
| 2 Pool | 24/25 | **25/25** |
| 3 Night | 19/25 | **23/25** |
| 4 Desert | 18/25 | **25/25** |
| 5 Roof | 21/25 | **24/25** |
| 6 Frost | 17/25 | **23/25** |
| 7 Factory | 13/25 | **20/25** |
| 8 Moon | 16/25 | **18/25** |
| **Total** | **153/200** | **183/200 (91.5%)** |

- **0 runtime script errors in every sweep run from a frozen snapshot** (≈ 520 full mission playthroughs). The only errors seen were from an early sweep that read a half-edited working tree.
- v0.5 baseline for comparison: 17 representative missions, 13 wins; lawn_11, lawn_19 and lawn_24 lost in the pre-v0.6 lawn sweep and all now win.
- Contract suite: **15,397 checks, 0 failures** (lower than v0.5's 16,117 only because trimmed waves have fewer per-spawn checks).
- Static validator: PASS — 200 levels, 23 workshop recipes, 40 distinct field layouts, 200 unique titles and jokes, all briefings/titles consistent with targets.
- UI capture under Xvfb: hub, workshop (stocked, with upgrade tiers), map, Moon seed select and battle with the owned-tools panel.

**Balance-watch list (lost the latest bot run; for human playtest):**
`night_20`, `roof_18`, `frost_23`, `moon_23` (fixed five-seed deck + cap — the bot reaches the final wave at the cap with spare sun; a human can graft/evolve for more power per action),
`frost_10`, `moon_10` (tight loss limits; the bot never heals), `factory_11` (rush + loss limit),
and endgame combat `night_24`, `factory_13`, `factory_23–25`, `moon_05`, `moon_18`, `moon_19`, `moon_24`, `moon_25`.
The Factory/Moon finales are intentionally the hardest content.

Per-level outcomes: `docs/testing/bot_sweep_v06_final.json`. Every data change: `docs/testing/balance_log.json`.

## Interpreting the bot

- Single runs are noisy (spawn jitter, sky-sun positions): unchanged levels flipped between sweeps in both directions.
  Treat one loss as a flag; a level that loses repeatedly is a balance signal.
- The bot uses a small fixed strategy (basic shooters, walls, sunbuds, emergency explosives). It does not graft for power,
  heal, use tools, or plan around special enemies. Losses in Factory/Moon endgame levels are flagged for **human** review,
  not claimed impossible; a human with grafts, legendaries and tools has a much higher ceiling.
- Not covered: Hard/Hard+, human playtests, mobile input, performance profiling, audio.
