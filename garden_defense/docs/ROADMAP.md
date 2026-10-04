# Garden Defense — Roadmap

Each milestone ends in a playable build with a short changelog, fresh screenshots and a clip.
A milestone is **done** only when every acceptance check in its table passes. "Nice to have"
items move to the next milestone; they never block a release.

Status key: ✅ done · 🟡 in progress · ⬜ not started
Current build: **v0.4**. Next target: **M1 (v0.5) Feel & Feedback**.

---

## M0 — Painted art and pools (v0.4) ✅

| Deliverable | Acceptance check | State |
|---|---|---|
| Painter kit + 29 plant rigs + 9 zombie part sets | Contact sheets `plants_sheet`/`zombies_sheet` pass the DESIGN §7.4 checklist; no SVG-flat placeholders left in battle | ✅ |
| Rig runtime (`core/rig.gd`), plants/zombies drawn from parts | `autotest -- mech` passes; walk cycle shows no foot sliding | ✅ |
| Modular board: painted lawn cells, no translucent grass overlay | Screenshot: every lawn cell is an opaque painted tile, checker readable | ✅ |
| Free-form water + modular coping (edge, outer, convex corner) + water shader | Pool levels 1–6 + bonus each use a different non-linear mask; no seams or missing corners in screenshots | ✅ |
| Lily Raft + stacking + raft survives its passenger | mech: `NEEDS_RAFT`, stack ok, raft restored, raft on lawn rejected | ✅ |
| Swimming zombies (submerge, ring, ripples) | mech: `submerge=1.00` in water | ✅ |
| Slower pace + Hard/Hard+ rebalance | Bot wins Standard levels; bot wins most Hard+ runs on Lawn 12–13 / Pool 5–6 (see §Balance gate) | ✅ |
| Difficulty in Settings only, almanac full stats, English-only docs | No difficulty buttons on the map; no "???" anywhere; `grep` finds no Cyrillic in the repo | ✅ |

---

## M1 — Feel & Feedback (v0.5) ⬜  *(est. 2 weeks)*

Goal: every action has audible and visible feedback; the first 3 levels teach without text walls.

| # | Task | Depends on | Acceptance check |
|---|---|---|---|
| 1.1 | SFX set (plant, shoot, hit, armour hit, bite, death, sun pickup, graft, mower, wave horn) from a CC0 pack; `AudioManager` autoload with Master/Music/SFX/UI buses | — | Every listed event plays a sound; volume sliders in Settings change the buses; licence file in `audio/LICENSES.md` |
| 1.2 | Music: menu, Lawn, Poolside, win/lose stingers | 1.1 | Loops seamlessly; ducked under the wave horn |
| 1.3 | Hit-stop (40 ms) on big hits, camera shake budget, damage numbers option | — | Toggle in Settings; no shake when "reduce motion" is on |
| 1.4 | Painted UI kit: 9-patch panels, buttons, seed cards, sun counter, wave bar (painter kit, not generated screens) | — | All screens use the kit; no default Godot theme visible in screenshots |
| 1.5 | Tutorial beats for Lawn 1–3 (pointer + one-line hints, skippable) | 1.4 | New save: player plants a Sunbud and a Pod Shooter within 20 s without reading the almanac |
| 1.6 | Seed-card tooltips show the almanac stat lines | — | Hover any card → cost, DPS/sun-per-min, special |
| 1.7 | Wave preview: next wave's zombie icons 4 s before it starts | — | Visible on the HUD bar; matches the spawned set |

**Exit gate:** 10-minute playtest with a new player records no "what just happened?" moments on Lawn 1–5.

---

## M2 — Poolside 2.0 (v0.6) ⬜  *(est. 3 weeks)*

Goal: water changes the strategy, not just where you plant.

| # | Task | Depends on | Acceptance check |
|---|---|---|---|
| 2.1 | 3 aquatic plants (e.g. Reed Lancer: water-only piercing shooter; Kelp Snare: drags a swimmer under; Bubble Buoy: cheap water wall) | M0 | Each has rig + almanac stats; bot uses each in at least one win |
| 2.2 | 3 water zombies: Snorkeler (dives, immune to straight shots while submerged), Duck-ring Brute, Dolphin-style vaulter | 2.1 | Divers can only be hit by aquatic/area plants while under; telegraphed by bubbles |
| 2.3 | Ripple/splash FX, wet footprints when a zombie leaves water, raft bob reacting to bites | — | Visible in showcase clip |
| 2.4 | Level authoring: water masks + hazard notes in a CSV → `build_data` | — | Designers edit `data_src/levels.csv`; rebuild reproduces all `.tres` |
| 2.5 | 6 new Poolside levels (7–12) using islands/channels; 1 fixed-seed puzzle | 2.1–2.4 | Bot wins Standard and Hard; Hard+ win rate ≥ 50 % across 4 seeds |
| 2.6 | Pool mowers become pool cleaners on water rows (same rules) | — | Correct sprite per row surface |

**Exit gate:** Poolside 12 cleared on Hard+ by a human tester with a custom deck in ≤ 3 tries.

---

## M3 — Night Graveyard (v0.7) ⬜  *(est. 4 weeks)*

| # | Task | Depends on | Acceptance check |
|---|---|---|---|
| 3.1 | Night mode: no sky sun, darker grade + light sources (shader) | M1 | Readability check: every unit's silhouette visible at night |
| 3.2 | Graves: block cells, spawn on final wave, can be removed by a Grave Gnawer plant | 3.1 | Grave layout per level in data |
| 3.3 | Mushroom family (cheap, strong at night, sleep in day): 5 plants | 3.1 | Each passes checklist + almanac stats |
| 3.4 | 5 night zombies (incl. a lantern-carrier that dispels darkness) | 3.2 | Each has a counter in the roster |
| 3.5 | 16 levels + map graph with 2 optional branches and a shop node | 3.1–3.4 | Star gates reachable; bot balance gate passes |

---

## M4 — Meta & retention (v0.8) ⬜  *(est. 2 weeks)*

| # | Task | Acceptance check |
|---|---|---|
| 4.1 | Quest log v2: daily rotating goals, map-specific challenges | 3 quests always available; rewards scale with difficulty |
| 4.2 | Plant mastery (cosmetic + small stat perks capped at +10 %) | Perks visible in almanac; bot balance gate still passes |
| 4.3 | Endless "Zen Survival" mode on Lawn and Poolside | Runs 30+ waves without memory growth > 5 % |
| 4.4 | Statistics screen (kills by plant, grafts, best waves) | Matches `SaveManager` counters |
| 4.5 | Save migration tests (v0.3 → current) | Old saves load with unlocks intact |

---

## M5 — Android & performance (v0.9) ⬜  *(est. 3 weeks)*

| # | Task | Acceptance check |
|---|---|---|
| 5.1 | Touch: tap-tap and drag planting, 48 dp hit areas, safe areas | Playable on a 6" phone without mis-taps in a 10-min session |
| 5.2 | Texture atlases per map, ETC2/ASTC import presets | APK < 150 MB; VRAM < 400 MB |
| 5.3 | Performance: 150 entities at 60 fps (mid PC), 30 fps floor on a budget phone | Profiler capture committed in `docs/perf/` |
| 5.4 | 30 fps battery option, pause on focus loss | Works on device |

---

## M6 — Core release (v1.0) ⬜

| Check | Target |
|---|---|
| Content | Lawn 16, Poolside 12, Graveyard 16 levels; ≥ 40 plants; ≥ 20 zombies |
| Quality | Every asset passes DESIGN §7.4; no placeholder art or text |
| Balance | Balance gate passes on every level and difficulty |
| Stability | 0 known crashes; 2-hour soak test without errors |
| Localisation | EN complete; RU/DE/ZH/JA columns filled by reviewed translations or hidden from the language picker |
| Builds | Windows, Linux, Android exported from CI |

---

## After v1.0
Beach (tides) → Roof (pots) → Night Jungle (vines, fog) → Oasis (heat, pots on sand) → Tundra (ice, warmth).
Each map repeats the M2/M3 template: mechanic prototype → 5–8 plants → 4–5 zombies → 16–30 levels → balance gate.

---

## Balance gate (used by every milestone)
Run from the project root (headless, ~1 min per level):
```
godot --headless --path . --fixed-fps 60 res://tools/autotest.tscn -- mech
godot --headless --path . --fixed-fps 60 res://tools/autotest.tscn -- <level_id> <standard|hard|hard_plus>
```
- `mech` prints no `false`/error lines.
- The bot (basic roster, no legendaries) **wins every Standard level**, wins Hard on the last level of each map,
  and wins **≥ 50 % of Hard+ runs** (4 runs) on the last two levels of each map.
- If a level fails: lower `threat_growth` by 0.04 or raise `wave_interval` by 2 s; never raise zombie stats to fix pacing.

## Working rules
- One milestone at a time; a task is done when its acceptance check is met in the build, not in a doc.
- Every merge: rebuild data/anims/strings, run `mech` + one bot run, update screenshots if visuals changed.
- Docs are English only.
