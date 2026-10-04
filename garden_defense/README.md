# Garden Defense v0.7.1 — Layers, Glove & PvZ2-style interface

A Godot **4.7.2** lane-defense game with **200 missions in 8 worlds**, grafting, crafting and modular mission rules. v0.7 is the "phone-ready" release: a working **Android APK**, a rebuilt PvZ2-style interface, layered/flying plants, new zombie profiles and audio.

## New in v0.7.1 (audit & bug-fix release)

- **Fixed lawn mowers:** since v0.7 the zombie that triggered a mower survived it and breached the gate anyway (the board had moved right of the trigger line). Mowers now trigger on contact and clear the lane as designed.
- Fixed out-of-bounds error spam in Endless/Daily on non-pool worlds, zombies skipped by multi-kill plants, `Engine.time_scale` stuck after a battle ended during hit-stop/fast-forward, HUD/audio leaks at exit.
- Daily Challenge bans are now stable per date; workshop tools are not wasted when they would have no effect; glove cooldown bar correct in puzzle missions.
- Settings that did nothing now work: Drag to plant, Long-press info, Colour-blind hints; Reset keeps the language.
- Hardened save loading (type validation) and saving (rename fallback). Android Back navigates instead of quitting.
- New fuzz and regression test scenes; `check_all` and `run_bots.py` now report failures properly.

See `docs/IMPLEMENTATION_v0.7.1.md` and `docs/TESTING_v0.7.1.md`.

## New in v0.7

- **Android fix:** the v0.6 phone build showed blank seed cards and no backdrop because the sprite rigs (`rig.json`) and campaign JSON were not exported. Both presets now include `*.json`; the APK was verified to contain all 113 rigs.
- **Android preset** (arm64-v8a + armeabi-v7a, sensor landscape, immersive, app icon). Debug APK: `exports/garden_defense_v0.7_debug.apk`.
- **PvZ2-style battle HUD:** vertical seed bank with plant portraits and red cost tags, sun counter top-left, wave bar + level name top-centre, coins / fast-forward / pause top-right, glove + shovel bottom-right, tap-a-plant info, pause menu with quick settings & help.
- **Loading screen** (logo, loading bar, tips), new **main menu** (Adventure, Endless Zone, Daily Challenge, dock), **Help** (8 topics) and **Statistics** screens.
- **Settings:** 7 tabs — Audio, Video, Gameplay, Controls, Accessibility, Language, Data (volumes, FPS, V-Sync, particles, screen shake, health bars, default speed, sticky tools, hints, haptics, drag-to-plant, reduce motion, high-contrast HP, colour-blind hints...).
- **Tile layers:** under (Pea Bedding, Thorn Carpet, Frost Bedding), main, shell (Pumpkin Shell, Thorn Pumpkin, Aegis Pumpkin), air (Garlic Drone, Turbo Bean, Sky Dragon, Chili Drone). Flying plants can only be hurt by Balloon and Slingshot zombies.
- **Zombie profiles & tiers:** Cardboard Box Zombie (follows a leader; only low shots, catapults, thorns, explosions hit it), Balloon Zombie (air), Slingshot Zombie (targets flying plants). All 49 zombies have a tier.
- **18 new plants** incl. 6 legendaries (Aegis Pumpkin, Thunder Root, Sky Dragon Fruit, Chrono Clover, Bean Patriarch, Starfall Melon) and 4 new hybrids; 64 plants and 28 graft recipes total.
- **Fusion:** order-independent recipes, star-ups (same seed, up to 3 stars), evolutions, cross-layer grafts through the **Glove**, which also moves plants (keeps stars/HP, 6 s recharge).
- **Endless Zone** and **Daily Challenge** modes; save v4 migration.
- Procedural **sound effects and music** with Master/Music/SFX buses.

See `docs/IMPLEMENTATION_v0.7.md` for details and known limitations.

## Controls

- Seeds: tap a packet or press `1`–`0`, then tap a tile; drag-and-drop also works.
- `Q` / `S`: shovel. `G` / `W`: glove. Right click: cancel. `Esc` / `P`: pause.
- Same seed on a plant: star-up (or evolution once unlocked). Seed on a compatible plant of the same layer: graft. Different layers: use the glove.
- Holdout missions: tap a damaged plant for a free repair. Artillery missions: tap a tile to fire the cannon.
- Workshop tools: buttons along the bottom of the battle screen (only owned tools are shown).
- QA shortcut: `godot --path . -- --goto=pool_17` opens a level's seed selection directly.

## Start here for AI-assisted development

**`docs/AI_FILE_TREE.md`** is the dependency tree and task-to-file reading guide. The main screen router remains only 41 lines; objectives, field rules, mission actions, crafting, progression, and enemy families are separate files.

- `docs/CAMPAIGN_FORMAT.md`: manifest schema and objective contracts.
- `docs/campaign/*.md`: all 200 level briefings, conditions, rewards, and opening lines.
- `docs/CRAFTING.md`: workshop and grafting rules.
- `docs/ENEMIES_v0.5.md`: expanded roster and counters.
- `docs/TESTING_v0.6.md`: v0.6 test commands, full-sweep results, and limitations (v0.5 version kept for history).
- `docs/IMPLEMENTATION_v0.6.md`: v0.6 audit fixes, balance pass, and remaining production work.
- `docs/IMPLEMENTATION_v0.7.md`: v0.7 layers, glove, HUD, Android export, and limitations.
- `docs/IMPLEMENTATION_v0.7.1.md` / `docs/TESTING_v0.7.1.md`: audit fixes, new tests, bot sweep and balance-watch list.

## Tests

```bash
python3 tools/tests/validate_campaign.py
godot --headless --path . res://tools/check_all.tscn          # compiles every script
godot --headless --path . --fixed-fps 60 res://tools/autotest.tscn -- mech   # mechanics incl. v0.7 layers/glove/box/balloon
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 res://tools/tests/campaign_test.tscn
godot --headless --path . --fixed-fps 60 res://tools/tests/regression_v071.tscn   # v0.7.1 fix assertions
godot --headless --path . --fixed-fps 60 res://tools/tests/fuzz_test.tscn -- 60    # random input, fails on any script error
godot --headless --path . -s res://tools/tests/loc_test.gd
python3 tools/tests/run_bots.py --godot /path/to/godot --all --jobs 2 --timeout 900
```

Use an isolated HOME/user-data directory for tests: test scenes replace their in-memory save and may write test inventory. Do not run them against a real player's save. See `docs/TESTING_v0.7.1.md`.

## Authoring / export

`data/campaign/*.json` are the campaign source of truth. Tune a single mission directly there. `tools/generate_campaign.py --overwrite` deliberately restores the initial v0.5 baseline; it is not an everyday balance editor. The old `tools/build_data.gd` is guarded because it overwrites historical resources.

The Linux and Android export presets include **`*.json`** in their non-resource export filter. Keep that filter in any additional preset (missing it caused the blank cards on phones). Android export needs the Godot 4.7.2 Android templates, an Android SDK with `platform-tools` and `build-tools`, a JDK and a keystore configured in Editor Settings. The campaign, workshop, and sprite rigs rely on JSON files. This archive contains source and assets, not a native platform executable or the 700 MB external toolset. A separately supplied `.pck` can be launched with the matching Godot 4.7.2 engine: `godot --main-pack garden_defense_v0.7.pck`.

**Validation is not a promise of perfect balance:** all 200 missions receive static and instantiation coverage; representative combat bots and offscreen UI checks cover the main systems. A full human playthrough of every mission and every difficulty remains future QA.
