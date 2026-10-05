# Art wiring report (Part 0 + Part A)

Branch `art/wiring-and-plants`. Engine Godot 4.7.2, GL Compatibility, 1920×1080 design size.
Screenshots: `tools/art/review/capture_all.sh review/{before,after}` (35 shots per resolution;
`review/` is git-ignored). Contact sheets are in `docs/art_wiring/`.

## 1. Symptom → cause → fix

| # | Symptom | Root cause | Fix |
|---|---------|------------|-----|
| 1 | New painted kit never showed, menus were flat brown boxes | A stale baked `ui/theme.tres` (StyleBoxFlat) was set as the project theme and won over the kit | Theme is built at runtime (`UITheme.build()`). `theme.tres` was deleted and `validate_assets.py` fails if anything references it |
| 2 | After fix 1, Play / Test sound / tab buttons were still Godot grey | `get_tree().root.theme` only propagates through **Control** parents. Screens hang under plain `Node`s, so most controls fell back to the engine default theme | `autoload/ui_boot.gd` merges the built theme into `ThemeDB.get_default_theme()`. `art_wiring_test` builds real controls under a `Node` and asserts that the *resolved* stylebox is painted |
| 3 | Grey slabs behind the settings content, grey disabled tabs, flat mirrored option buttons | Theme types the kit never set (ScrollContainer panel/focus, TabContainer tabbar_background, tab_disabled, OptionButton *_mirrored, PopupMenu labeled separators, LineEdit read_only, RichTextLabel) kept engine StyleBoxFlat | `ui/theme/fill_ins.gd` covers every remaining stylebox. The test loops over all styleboxes of every used type and fails on StyleBoxFlat |
| 4 | WoodButton had no focus ring; CheckBox had no disabled state | Missing states in `buttons.gd` | Added. The test checks every state of every button type |
| 5 | Screens used `keyart.jpg` / `assets/art/bg/*` / hard-coded paths, with silent fallbacks | No single owner for screen backgrounds | One entry point: `ScreenArt` resources in `assets/art/screens/<id>.tres`, built from the table in `tools/art/ui/build_screens.py`. A missing file logs `push_error` and draws a magenta "MISSING ART" placeholder |
| 6 | Desert / frost / roof grounds looked the same | `snow.png` and `tile.png` were byte-identical copies of `sand.png` | New painted swatches per world. `validate_assets.py` enforces distinct md5 and mean-colour distance ≥ 12 |
| 7 | Factory floor was muddy and low detail | It used the generic soil swatch | New `concrete` swatch. `soil.webp` was retired |
| 8 | Non-grass worlds had grass/soil edges or none at all | `lawn_edges.py` used lawn soil everywhere; fringe was grass-only | Per-world `fringe_styles.py` (snow drifts, sand ripples, tile grout, rivets…); the world .tres carries fringe, tuft and blocked |
| 9 | Missing world art fell back silently to lawn | `WorldArtLoader` / `KitStyles` defaulted quietly | Both now log loud errors and show placeholders. The test asserts every world loads non-placeholder art |
| 10 | Settings switch was a procedural rectangle | Drawn in code | Painted switch from the widget sheet |
| 11 | Hub world cards were flat colour stripes; the pool card had no pool | Thumbs were crops of the battle ground | Thumbs are cut from the painted world maps (`build_thumbs.py`) |
| 12 | **Phone aspect (20:9)**: battle drawn at 1920 px, flat green bar on the right | `aspect.mobile="expand"` widens the viewport, but the battle stage and HUD use absolute 1920×1080 coordinates. The review capture used `keep`, so it never showed this | `core/art/battle_frame.gd` centres the stage and HUD; `LawnRenderer` mirrors the surround into the margins; HUD overlays still dim the whole screen. The capture now switches to `expand` for non-16:9 windows. Also checked at 4:3 (1920×1440) |

## 2. Verification

- **Resolutions:** 1920×1080, 1600×900 and 2400×1080 (phone, `expand`), plus 1920×1440 (tablet).
  Results: no seams, the board ground sits exactly on `Board.board_rect()`, the pool's water and
  coping sit on the right cells, z-order is correct (ground → edge → board → shadows → y-sorted
  entities/fringe), and there is no checkerboard.
- **Worlds:** the 8 worlds differ in ground, edge, fringe, tuft, blocked prop, shadow tint and light tint.
- **Map screens:** all 8 are painted.
- **Other screens:** menu, loading, hub, workshop, almanac, quests, shop, settings, help and stats
  each have a painted background, with dim/tint from data.
- **Re-import:** `.godot/` was deleted and the project re-imported twice. Both passes: 0 errors, 0 warnings.
- **Export:** `export_presets.cfg` uses `all_resources`, so `assets/art/worlds` and `assets/ui/kit`
  are included. `review/*` was added to the exclude filter.

## 3. Tests (HOME isolated)

| Test | Result |
|------|--------|
| `godot --headless --path . res://tools/check_all.tscn` (compile 128 scripts + repo_budget + validate_assets + art_wiring_test) | PASS, 0 failures |
| `python3 tools/tests/validate_campaign.py` | PASS (200 levels, 8 worlds, 64 plants, 49 zombies) |
| `autotest.tscn -- mech` | PASS |
| `tests/campaign_test.tscn` | 16954 checks, 0 failures |
| `tests/regression_v071.tscn` | 33 checks, 0 failures |
| `-s tests/loc_test.gd` | PASS |
| `tests/fuzz_test.tscn -- 5` | 12 levels, 780 actions, no script errors |

New gates:
- `tools/art/review/validate_assets.py`: res:// refs resolve; no retired art referenced; world
  files, size and distinctness; screen art at 1920×1080; kit PNGs RGBA with no key or checkerboard residue.
- `tools/tests/art_wiring_test.tscn`: every themed state is painted and resolved through real
  controls; every screen and world loads real art.
- `tools/art/review/repo_budget.py`: 60 MB total and 3 MB per file, audio excluded.

## 4. Dead art removed (after the after-shots proved the new path)

Removed: `assets/art/bg/`, `assets/art/source_generated/`, `assets/art/keyart.jpg`,
`assets/art/menu_garden.jpg`, `assets/tiles/lawn/`, the lawn-cell painter in
`tools/art/paint/tiles.py`, `art_src/finals/ground/soil.webp`.

Kept: `assets/tiles/pool/` (used by `Board.POOL_DIR`) and `art_src/svg/` (FX sheet sources
from `build_fx_svgs.py`).

UI and prop source sheets in `art_src/finals` were re-encoded from lossless WebP to WebP q94.
The rebuilt kit differs by ≤ 1 px in crop and ≤ 2.2/255 mean per pixel.

## 5. Sizes (tracked files)

| Directory | Before (working tree) | After |
|-----------|----------------------:|------:|
| garden_defense/ (duplicate project) | 47.0 MB | 0 |
| art_src | 59.7 MB | 17.5 MB (finals 14.5) |
| assets | 50.2 MB | 32.1 MB (art 14.2, sprites 13.7, ui 1.5, tiles 1.1) |
| review/ (now ignored) | 13.3 MB | 0 |
| docs | 7.4 MB | 1.8 MB |
| audio | 3.7 MB | 3.7 MB |
| **Total** | **182 MB** | **58.0 MB** incl. audio; repo_budget metric (MiB, audio excluded) **55.3 / 60** |

Git history still holds the old blobs: the pack is 144 MiB, mostly two 18 MB archive zips and
raw ~3 MB PNG generations. Shrinking the clone needs a history rewrite
(`git filter-repo --strip-blobs-bigger-than 1M` plus path filters) or a fresh repo. **This has not
been done; it is waiting for the owner's OK.**
