# v0.6 — bug audit, balance and playability pass

v0.6 changes no artwork. It fixes defects found in a code audit, runs **full 200-level bot sweeps**
(v0.5 only tested 17 representative missions), and rebalances the campaign data with recorded,
reproducible tools. Test numbers: `docs/TESTING_v0.6.md`.

## Bugs fixed

| Area | Defect | Fix | File |
|---|---|---|---|
| Enemies | Split zombies and Granite Gargantuan imps in lane 5 spawned in lane 1 (`(row+1) % 5`) — a cross-board teleport | `Board.neighbor_row()` (below, or above from the bottom lane) | `zombie_adaptive.gd`, `gargantuan_granite.gd`, `board.gd` |
| Moon rule | Low-gravity pulse floated lane-5 zombies to lane 1 | same helper | `field_rules.gd` |
| Speed | Every explosion's hit-stop reset ×2 battle speed to ×1; overlapping hit-stops ended each other early | token-based restore to the HUD's chosen speed | `battle.gd` |
| Waves | A crowded lawn delayed the next wave forever ("bounded" comment, unbounded code) — could stall time-limit missions | crowd hold capped at 15 s per wave | `wave_director.gd` |
| Objectives | Bank/collect/graft missions whose waves were cleared but which could no longer earn sun waited forever | post-wave stall guard: hint toast, then clean failure after 60 s with no possible progress (never while sun tokens/producers still move the counters) | `objective_tracker.gd` |
| Objectives | Sun Flask (bought sun) counted toward "collect 4000 sun" goals | bought sun is bankable/spendable but not "collected" | `crafting_system.gd` |
| Objectives | Shoveling a **healthy** plant counted as a loss | only damaged plants count (no loss-limit dodging) | `battle.gd` |
| Objectives | Plant-limit error displayed the current count as if it were the limit | shows `n/limit` | `objective_tracker.gd` |
| Saves | Save written in place — a crash mid-write corrupted the only save; unreadable saves were silently overwritten | write-then-rename; unreadable file kept as `save.corrupt.json` | `save_manager.gd` |
| Economy | Recipes needed more crystal than the campaign could ever award (replays gave none) | milestone replays (every 5th level) give 1 crystal | `game_state.gd` |
| Text | All holdout briefings omitted their 5-plant loss limit; holdouts told players to "collect sun" (useless there); every gauntlet said "On the Moon…" in every world; 9 titles contradicted their numeric targets | corrected; validator now enforces briefing/title ↔ target agreement | campaign JSON, `validate_campaign.py` |
| UI | Field-pulse toast printed raw ids (`low_gravity`) | readable names | `field_rules.gd` |

## Playability and variety

- **Scenario remix:** worlds 2–8 order their mission types differently inside same-size slot groups, so
  "level 6 is always the plant cap" no longer holds. No enemy appears before its introduction level (checked by the remix script).
- **Per-world blocked layouts:** six new patterns (diagonal, dunes, chimneys, ice blocks, machinery, craters); 34 → 40 distinct fields.
- **Objective variety:** targets differ per world (bank 3,500–4,500, collect 4,000–5,000, plant caps 19–24),
  plus combined objectives in later worlds (bank + losses, collect + no breach, limit + losses, mowerless + losses, elite + cap, summons + no breach).
- **Real deadlines:** rush missions were 600 s (effectively no limit); now authored duration + crowd allowance + cleanup (330–370 s).

## Crafting

23 workshop recipes (was 14): two new tools (Sun Magnet, Glue Trap) and seven **tiered permanent upgrades**
(Sprinkler I–III, Seed Pouch I–II, Sun Lens I–II). The battle tool panel shows only owned tools. Details: `CRAFTING.md`.

## Balance process (reproducible)

1. `tools/balance/level_metrics.py` exposed per-slot spikes: armor (×2 HP), gauntlet (heavier than the finale), rush (double density, 25 s cadence).
2. `tools/balance/remix_v06.py` — remix + spike trim against each world's own fitted curve + objective variety (one-shot, refuses re-run).
3. Full sweep 1 (standard bot) → `tools/balance/retune_objectives_v06.py` relaxed over-tight objectives (caps of 16–17 lost with 800–1,200 sun unspent, loss limit 2, rush + loss combos, late mowerless).
4. Levels lost by **both** the standard and the new `--strategy strong` bot got one logged easing step (`tools/balance/ease.py`: −10–12% unprotected HP, +75 start sun). Bosses and flagbearers are never trimmed.
5. Every change is in `docs/testing/balance_log.json`.

## Not done / honest limits

- No human playtest. Bot results are a pacing proxy with a fixed, limited strategy; later-world losses are flagged for human review, not proven impossible.
- Hard / Hard+ difficulty, mobile input and performance profiling remain production QA.
- Graphics untouched (e.g. some later worlds still reuse earlier backdrops).
