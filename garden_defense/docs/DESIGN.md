# Garden Defense — Design (v0.4)

This document replaces the archived v0.2 GDD. It keeps every decision that still holds,
updates the ones the build has since changed, and states the current rules of the game.
Numbers quoted here come from `tools/build_data.gd`, the single source of balance data.

**Genre:** lane defense with plant grafting and evolution.
**Engine:** Godot 4.7 (Compatibility renderer), strictly typed GDScript.
**Platforms:** PC (Windows/Linux) now, Android (landscape) later.
**Status:** non-commercial solo fan project. No monetisation and no paid currency.
**Languages:** the CSV carries `en, ru, zh_CN, ja, de` columns. Only English is filled in.

> **IP.** The genre is inspired by *Plants vs. Zombies* (PopCap/EA). Every name, silhouette,
> sprite, sound and UI element in this project is original. Don't copy assets, names or
> layouts from the original games.

---

## 1. Decision log

| # | Decision | State |
|---|---|---|
| 1 | Solo, non-commercial fan project | fixed |
| 2 | 2D only. Characters are painted cut-out rigs; backdrops are illustrations | fixed (v0.4: rigs are painted procedurally, see §7) |
| 3 | First goal: a complete, polished core (Lawn + Poolside) before more maps | fixed |
| 4 | Long-term scope: 8 maps, ~72 plants, ~40 zombies | far goal, quality before quantity |
| 5 | Board is 9 columns × 5 rows on every map shipped so far | fixed |
| 6 | Resource is sun; coins are the meta currency; stars open gates | fixed |
| 7 | Evolve (same plant) and Graft (base + catalyst → hybrid) | fixed (§4) |
| 8 | 1 star per level on first clear, at any difficulty; no ranks | fixed |
| 9 | Non-linear world map: branches, optional bonus nodes, shops, star gates | fixed |
| 10 | No story or NPCs; no voice acting; no dynamic music | fixed |
| 11 | Roof and Oasis use pots. No slope and no lobbed projectiles | fixed for future maps |
| 12 | Three difficulties: Standard, Hard, Hard+ | fixed. **Chosen in Settings only** (v0.4) |
| 13 | "Damage taken" on difficulties means damage dealt *to zombies* (they take less) | fixed |
| 14 | Animation is keyed at 30 fps, the game runs at 60 fps | fixed |
| 15 | The Almanac shows everything with full stats, with no "???" placeholders | fixed (v0.4) |
| 16 | Pool water is a per-level free-form cell mask, not fixed lanes | fixed (v0.4) |
| 17 | Mowers are on by default, one per row | fixed |
| 18 | Anti-slop: every asset passes the quality checklist (§7.4) before it ships | fixed |

## 2. Pillars

1. **Readability.** Each plant and zombie is recognisable at 64 px from its silhouette and main colour.
2. **Living characters.** Everything has idle, action, hurt and death motion. Nothing is a static sticker.
3. **Every plant matters.** Hybrids and legendaries must not make basic plants obsolete (§4.4).
4. **Maps are mechanics.** A new map has to change how you play, not just the background.
5. **Data-driven.** Plants, zombies, levels, recipes, maps, difficulty and shop are `.tres` resources generated from tables.
6. **Localisation-ready.** Code and scenes contain keys only. English text lives in `tools/strings_en.py`.
7. **Quality over quantity.** Thirty good characters beat seventy-two forgettable ones.

## 3. Core loop and rules

1. World map → pick a node.
2. Seed select: choose up to the slot limit. The starting limit is 6, and the shop raises it to 10. Pool levels add a free **Lily Raft** slot.
3. Battle: collect sun → plant → graft/evolve → survive every wave. The last wave is a flag wave.
4. Reward: first clear gives 1 star, coins and maybe a plant or feature unlock. Repeat clears give coins.

**Losing.** Each row has a one-shot mower. A zombie that passes an empty mower slot damages the gate. The gate has 3 integrity points: a normal zombie costs 1 point and a high-threat zombie costs 2. Losing all 3 points loses the level.

**Controls.** Click a seed (or press 1–0), then click a cell; drag and drop also works. Q/S selects the shovel, right-click cancels, and Esc/P pauses. The HUD has ×1/×2 speed buttons. Debug keys: F2 gives +500 sun, F3 skips a wave, F4 wins instantly.

### 3.1 Surfaces and the pool
- Every cell has a surface: `grass` or `water` today. `roof`, `sand`, `ice` and `dirt` are reserved.
- `LevelData.water` is 5 strings of 9 characters. `~` marks water and `.` marks lawn, for example:
  `[".........", "..~~~~...", ".~~~~~~..", "..~~.~~..", "........."]` (Poolside 2, a pool with an island).
  Any shape works: ponds, islands, diagonal channels, meanders. The renderer builds the coping from modular pieces (§7.3).
- Land plants can't grow on water. First plant a **Lily Raft** (25 sun, water only), then plant any lawn plant on top of it.
  If the top plant is eaten or shovelled, the raft stays with the HP it had. Grafting and evolving work normally on a raft.
- Zombies swim through water cells. They sink to the waist, get a swim ring and leave ripples. Speed and eating are unchanged for now.
  Diving and water-only zombies are planned (see ROADMAP M3).

## 4. Evolve and Graft

- **Evolve:** play the same seed on a grown plant to upgrade it in place: Pod Shooter → Twin Pod, Sunbud → Twin Sunbud, Bark Wall → Ironbark Wall.
  Costs `evolve_cost`. Unlocked by clearing Lawn 6.
- **Graft:** play a catalyst seed on a grown base plant that has a recipe. Costs `catalyst cost + fee`. Unlocked by clearing Lawn 5.
  The hybrid keeps the base plant's HP ratio. Hybrids aren't seeds, so both ingredients must be in the seed set. Each level has a `hybrid_cap`.
- A base is "grown" after `fusion_ready_time` seconds. Bonus levels can switch grafting off.

| Base | Catalyst | Hybrid | Idea |
|---|---|---|---|
| Pod Shooter | Frost Mint | Glacier Shooter | Slowing shots that pierce 1 |
| Bark Wall | Bramble Vine | Thornwall | A wall that bites back |
| Sunbud | Lantern Bloom | Dawn Bloom | More sun and a neighbour buff |
| Thorn Mine | Ember Berry | Volcano Mine | Bigger blast that leaves fire |
| Snapper Trap | Gale Fern | Vortex Trap | Pulls zombies from nearby cells |
| Twin Pod | Pepper Stinger | Needle Volley | Piercing triple volleys |

### 4.4 Balance rules
1. A hybrid has at most 1.3× the value-per-sun of its best parent.
2. Every hybrid has a cost: a long recharge, a narrow niche, or a counter.
3. `hybrid_cap` stops a level from being filled with hybrids.
4. Each role (wall, producer, area, control, single target) has at least 3 viable plants.
5. Levels push variety with fixed seed sets, graft bans and counter-zombies.
6. The headless bot (`tools/autotest.gd`) is the regression check for balance (§9.4).

## 5. Plants (29)

| Plant | Role | Cost | Notes |
|---|---|---|---|
| Sunbud | producer | 50 | 25 sun / 24 s, evolves to Twin Sunbud |
| Pod Shooter | shooter | 100 | 20 dmg / 1.45 s, evolves to Twin Pod |
| Bark Wall | wall | 50 | 4000 HP, 3 damage stages |
| Thorn Mine | mine | 25 | arms in 14 s, 1800 dmg |
| Ember Berry | instant | 150 | 1800 dmg in 1.5 cells |
| Frost Mint | slower | 175 | slows by 50% for 8 s |
| Snapper Trap | trap | 150 | swallows a zombie, chews for 40 s |
| Bramble Vine | blocker | 100 | 800 HP, thorns |
| Lantern Bloom | support | 125 | +25% to neighbours |
| Gale Fern | control | 100 | pushes zombies back |
| Pepper Stinger | pierce | 175 | piercing fire shots |
| Hive Pod | summoner | 125 | up to 3 bees |
| Dandelion Puff | area | 75 | cheap area damage |
| **Rime Lettuce** | freezer | **0** | freezes the first zombie for 10 s (Brute 5 s), single use |
| **Lily Raft** | water platform | 25 | the only plant that grows on water |
| Sun Sovereign ★ | producer | 250 | legendary: 50 sun / 20 s, +20% buff |
| Phoenix Lily ★ | shooter | 325 | legendary: burning piercing shots, revives once |
| Storm Thistle ★ | chain | 350 | legendary: lightning that chains 4 times and stuns |
| Elder Oak ★ | wall | 300 | legendary: 9000 HP, 60 HP/s regeneration, thorns |
| + Twin Pod, Twin Sunbud, Ironbark Wall (evolutions) and 6 hybrids (§4) | | | |

Legendary plants (★) have gold cards and a `max_on_board` of 1. They also have long first and repeat recharges. They come from the shop or from campaign rewards.

## 6. Zombies (9)

| Zombie | HP + armour | Speed (cells/s) | Feature |
|---|---|---|---|
| Shambler | 270 | 0.17 | basic |
| Flagbearer | 270 | 0.28 | marks a flag wave |
| Cone Head | 270 + 370 cone | 0.18 | armour with 3 visual stages |
| Bucket Head | 270 + 1100 bucket | 0.18 | heavy armour |
| Sprinter | 230 | 0.36 | fast |
| Hurdler | 340 | 0.34 | vaults the first plant |
| Shield Carrier | 270 + 1100 shield | 0.17 | the shield blocks shots from the front |
| Burrower | 300 | 0.32 | tunnels under the defence and surfaces behind it |
| Brute | 3000 | 0.13 | smashes; can't be swallowed, pushed or pulled |

FSM: `SPAWN → WALK → EAT → ABILITY → DIE`. Statuses are slowed, frozen, burning, stunned and swimming (submerge 0–1).

## 7. Art and animation

### 7.1 Style
Flat cel shading with a **coloured outline** (never pure black). Light comes from the top left. Toon shading uses 2–3 bands, plus a rim light and a soft specular. Plants have round, friendly shapes; zombies are angular and asymmetric.

### 7.2 Characters: painted cut-out rigs
- `tools/art/paint/kit.py` is the painter kit. It turns cairo shape masks into a distance-field height map, then normals. From those it builds toon/half-Lambert shading, rim, specular, ambient occlusion and a coloured outline. It also composites layers and exports the rig.
- `tools/art/paint/plants.py` and `zombies.py` paint every part at 2× (one cell is about 260 px). They write `assets/sprites/<kind>/<id>/<part>.png` and `rig.json`, which holds pivots, parents, z order and meta such as muzzle points.
- `core/rig.gd` loads and caches rigs. Plants place parts through `rig_local()` hooks; zombies use limb kinematics with thigh/shin and upper arm/forearm chains.
- `anim/plant_anims.tres` and `anim/zombie_anims.tres` are shared AnimationPlayer libraries built by `tools/build_anims.gd`. Gameplay fires on key frames: the shot frame, the bite frame and the footstep frame.

### 7.3 Board and tiles
- `tools/art/paint/tiles.py` paints 4 light and 4 dark lawn cells, tileable water and caustics, and modular pool coping. The coping set has a straight edge, an outer corner and a convex corner. It also bakes preview variants: full water, enclosed, left+right, left, right and top+bottom.
- `core/board.gd` draws the backdrop, then one painted lawn cell per land cell. There is no semi-transparent grass overlay. Water cells use `shaders/water.gdshader`, which scrolls in world space and adds caustics, wobble and sparkle. An edge pass puts coping wherever water meets land (the board border counts as land). Outer corners go where two edges meet, and convex corners go where only the diagonal neighbour is land.

### 7.4 Quality checklist (every asset)
- [ ] Silhouette reads at 64 px and differs from every other character.
- [ ] No extra limbs, stray details, text or symbol noise.
- [ ] Outline colour, light direction and eye style match the style rules above.
- [ ] Clean alpha with no halos; mipmaps are on (`tools/fix_imports.py`).
- [ ] Motion: idle, action, hurt and death all read clearly at ×1 and ×2 speed.

### 7.5 Resolution
The game renders at 1920×1080 with the `canvas_items` stretch mode. A cell is 130×140 px. Sprites are painted at 2× and drawn at 0.5 with mipmaps.

## 8. Maps

| # | Map | State | Mechanic |
|---|---|---|---|
| 1 | Lawn | shipped (13 levels + 3 bonus) | pure lane defense, introduces the roster |
| 2 | Poolside | shipped (6 levels + 1 bonus) | free-form water cells, Lily Raft, swimming zombies |
| 3 | Night Graveyard | planned | no sky sun, graves block cells and spawn zombies, mushrooms |
| 4 | Beach | planned | timed tides flood columns from the right |
| 5 | Roof | planned | every plant needs a pot, which is a platform with its own HP |
| 6 | Night Jungle | planned | vines grab plants, fog, fireflies give light |
| 7 | Oasis | planned | pots on sand, heat slows recharge, sandstorms |
| 8 | Tundra | planned | ice cells, cold, fire thaws |

The world map is a graph of `MapNodeData` with types LEVEL, SHOP, GATE, BONUS and HUB_LINK. It supports forks, merges, optional branches, loops back to the shop, and star gates (`requires_stars`).

## 9. Waves, pace and difficulty

### 9.1 Wave director (`core/wave_director.gd`)
- Wave budget: `(threat_base + (n-1)·threat_growth) × difficulty count × ramp(0.94→1.12)`. Every third wave gets +8%, and flag waves get ×1.55.
- Zombies are bought from the level pool by `threat_cost`. Elites (cost ≥ 3) are capped at 42% of a wave and unlock gradually.
- Pace (v0.4, slower than v0.3): the first wave comes after 40 s by default, and waves are 34 s apart.
  The gap shrinks only from ×1.10 to ×0.85 over the level, with a 14 s minimum. A wave spreads over 6–20 s, plus 3 s on flag waves.
  Clearing the lawn cuts the wait to 12 s at most, never to 4 s. A crowded lawn (6 + 2·count zombies) holds the next wave back.
- Rows are balanced: a new zombie goes to one of the least loaded rows, avoiding the last two rows used.

### 9.2 Difficulty (chosen in Settings → Default difficulty)
| | Standard | Hard | Hard+ |
|---|---|---|---|
| Zombie count (budget) | ×1.00 | ×1.15 | ×1.25 |
| Zombie speed | ×1.00 | ×1.00 | ×1.05 |
| Bite damage | ×1.00 | ×1.15 | ×1.30 |
| Damage zombies take | ×1.00 | ×0.90 | ×0.85 |
| Wave gap | ×1.00 | ×1.00 | ×0.95 |
| Coins | ×1.00 | ×1.25 | ×1.50 |

v0.3 used up to ×1.6 count, ×0.75 damage taken and ×0.75 wave gap, which made Hard and Hard+ unwinnable.

### 9.3 Stars
You earn 1 star on the first clear at any difficulty. The best difficulty cleared is saved per level and shown on the map.

### 9.4 Balance targets
- The headless bot uses a fixed basic roster: no legendaries and no Rime Lettuce. It must win every Standard level and Hard levels, and most Hard+ runs.
- A human with a sensible deck should clear Hard+ on the final levels on the first or second try.

## 10. Technical design

- **Autoloads:** EventBus, DB (data registry), SaveManager (`user://save.json` with `save_version`), Settings, GameState.
- **Folders:** `core/` (battle, board, wave director, fusion, rig, data classes), `entities/` (plants, zombies, projectiles, effects),
  `ui/`, `data/`, `anim/`, `assets/`, `shaders/`, `localization/` and `tools/` (builders, painters, bot and screenshots).
- **Rendering:** Compatibility renderer everywhere. Projectiles are pooled. Rig parts are atlas candidates for Android (ROADMAP M5).
- **Tools:** the data builder, animation builder, string builder, import fixer, painters, autotest (mechanics + bot), screenshot and showcase tools.

## 11. Localisation rules
1. Keys are `UPPER_SNAKE_CASE`, for example `PLANT_<ID>_NAME`. Use `tr()` in code and `.format({...})` for placeholders.
2. Don't glue strings together and avoid plurals. Use "Zombies: 5" style. Move to `.po` files if plural forms are ever needed.
3. Leave 40% spare width for German and allow line wrapping for CJK. The fallback font is Noto Sans, subset for CJK.
4. Don't put text inside images. Machine translation is a draft only and needs human review.

## 12. UI and meta
- **Screens:** Main menu → Hub → Map → Seed select → Battle → Result. Also the Almanac, Shop, Quest log and Settings.
- **Almanac:** lists every plant, zombie and graft. Each entry has a full stat sheet with cost, recharge, HP, damage, DPS, rate, range, special effects, sun per minute, speed in px/s, time to cross the lawn, eating DPS, wave cost and immunities.
- **Shop (coins only):** seed slots, starting sun, spare mowers, cosmetics, recipe hints and legendary seeds.
- **Quests:** objectives such as "clear without losing a mower", "graft N times" or "defeat X zombies". Rewards are coins.

## 13. Audio
No voice acting and no dynamic music. Each map gets one track, plus menu, win and lose stingers. SFX cover planting, shooting, hits, eating, deaths, sun pickup and fusion. The source must be CC0 or licensed before release.

## 14. Risks
| Risk | Mitigation |
|---|---|
| Art consistency | One painter kit, shared palette and outline rules, checklist, contact-sheet review |
| Scope (8 maps) | Ship map by map; each map passes its milestone gate (ROADMAP) |
| Graft balance | Power budget, hybrid cap, bot regression runs |
| IP | Original names and designs only |
| Android performance | Compatibility renderer, atlases, pooling, 30 fps option |
