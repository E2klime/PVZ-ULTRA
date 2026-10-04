# Garden Defense v0.7.1 — audit & bug-fix release

v0.7.1 is a maintenance release on top of v0.7: a full code audit (≈11k lines of GDScript), crash/logic fixes,
settings that previously did nothing, save hardening, and new automated tests. No content or balance data was changed
(`data/campaign/*.json` are untouched), so all v0.7 saves load as before.

## 1. Crashes and runtime errors

| Area | Problem | Fix |
|---|---|---|
| **Lawn mowers (all levels)** | Since the v0.7 HUD moved the board right (`Board.ORIGIN.x = 310`), mowers sit at x≈255 but zombies triggered them only at `HOUSE_X = 70`, i.e. after walking *past* the blade. The mower drove off without touching that zombie, which then breached the gate too: every lane cost its mower **and** gate integrity. This was the main cause of the v0.6 → v0.7 drop in bot win rate. | `Battle.mower_reached()` triggers an idle mower when a zombie reaches it (`Mower.TRIGGER_REACH`); the blade cuts everything between the house and its front edge (`BLADE_REACH`). Breach still happens at `HOUSE_X` once the mower is used. |
| Endless / Daily on Lawn, Night, Roof… | `objective_tracker.planting_error()` and `FieldRules._draw()` indexed `level.water[r][c]` although only pool levels have a water grid → *Out of bounds* error spam every hover/planting attempt. | New `LevelData.tile(r, c)` / `is_blocked(r, c)` with bounds checks; both call sites use them. |
| Pusher, Thorn Carpet, Chrono Clover, projectile pierce, fire puddle | Iterated the live lane array while killing zombies; removal shifted the array and the next zombie was skipped (or a freed one touched). | Iterate over `lane.duplicate()`. |
| Battle end | Win/lose during hit-stop or fast-forward left `Engine.time_scale` ≠ 1 (menus ran slowed/fast); a late hit-stop timer could restore battle speed after the battle ended. | `time_scale = 1` on win/lose; hit-stop only while PLAYING and not paused/reduced-motion; restore only while PLAYING. |
| Audio at exit | Players were never stopped/freed; headless dummy driver leaked playbacks (`ObjectDB instances leaked`, `resources still in use` on every test run). Music loop end was computed for mono 16-bit regardless of format. | `_exit_tree()` stops and releases players; loop end derived from format/stereo; SFX disabled on the headless display server. |
| HUD | Lambda connected to the global `EventBus.coins_changed` outlived the HUD (errors after leaving a battle). | Bound method `_on_coins_changed`. |

## 2. Gameplay logic

- **Daily Challenge bans** used the global RNG (`shuffle()`), so the banned seeds changed on every retry and could repeat. Now drawn from a sorted candidate list with the date-seeded RNG; starters and Lily Raft are never banned.
- **Glove cooldown sweep** used the normal 6 s maximum even in puzzle missions (different recharge) → wrong HUD fill. `glove_cd_max` is stored and used by the HUD.
- **Workshop tools** (Frost Bottle, Compost Tea, Repair Kit, Seed Clock, Pepper Bomb, Sun Magnet, Glue Trap) were consumed even when they had nothing to act on. They are now kept and a toast `TOAST_TOOL_NO_EFFECT` is shown (EN/RU/DE/ZH/JA).
- **Shield aura** (support zombie) raised armour above `max_armor` — the armour bar overflowed. `max_armor` is raised too.
- **Daily/Endless map art:** the map screen showed lawn art for every world; it now uses `map_<world>.jpg`, falling back to the dimmed battle backdrop.

## 3. Settings that were shown but not implemented

- **Drag to plant**: when off, seed packets/shovel no longer start a drag (tap-tap only).
- **Long-press info**: holding a plant for 0.45 s opens the plant info card (real time, not affected by game speed).
- **Colour-blind hints**: zombies draw shape glyphs for frozen (snowflake), slowed (double chevron) and burning (flame outline); invalid tiles under the cursor get a cross in addition to the red tint.
- **Reset to defaults** no longer switches the language back to English.

## 4. Save robustness (`autoload/save_manager.gd`)

- `_sanitized()` type-checks every field before migration: negative/garbage coins are clamped, lists drop nulls and duplicates, counter dictionaries keep only numeric values. A hand-edited or partially corrupted save no longer crashes the loader.
- `save_game()` checks the rename result; on platforms where rename-over-existing fails it removes the old file and retries, and logs a warning instead of silently losing progress.

## 5. Platform

- **Android back button** (`config/quit_on_go_back=false`): Back now navigates (hub → menu, map → hub, other screens → previous, battle → pause menu via the HUD, finished battle → previous screen) instead of killing the app.
- Version 0.7.1; Android `version/code=8`.

## 6. Performance

- `Battle.hybrid_count()` was recomputed (walking every plant) for each seed packet every frame; it is now cached per frame and invalidated on plant creation/removal.

## 7. Test tooling

- `tools/check_all.gd` counts failures and exits with code 1 (previously always 0).
- `tools/tests/fuzz_test.tscn -- <seconds>`: random taps, seeds, shovel, glove, pause and speed changes on 8 campaign missions + Endless Lawn/Pool/Roof + Daily. Fails on any script error.
- `tools/tests/regression_v071.tscn`: 33 targeted assertions for the fixes above (each verified to fail on v0.7 code where practical).
- `run_bots.py`: `--timeout`, flags `SCRIPT ERROR` / leak lines as errors; the bot was updated for v0.7 content (no graft-only seeds in the deck, Pea Bedding against Box Zombies, Spine Cactus against Balloon/Slingshot, never plants onto a zombie, frees the battle before quitting).

## 8. Known limitations

- Balance was **not** retuned. The v0.7 roster (Box, Balloon, Slingshot zombies) made several late Lawn/Pool missions noticeably harder for the simple bot than in v0.6 — see `docs/TESTING_v0.7.1.md` for the balance-watch list. These need a human playtest before changing data.
- Android export was not rebuilt in this release (no SDK in the audit environment); the preset changes are trivial.
