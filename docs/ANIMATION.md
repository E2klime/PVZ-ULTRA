# Animation & art pipeline (v0.4)

v0.4 replaces the flat procedural `_draw()` shapes with **painted cut-out rigs**.
The motion system from v0.3 (pose properties driven by `AnimationPlayer`) stays the same;
it now moves painted parts instead of vector shapes.

## 0. Painted rigs (new in v0.4)
All character and tile art is painted by Python scripts (pycairo + numpy + OpenCV). The
image-generation tool wasn't available for this update, so everything is reproducible from source:

```
python3 tools/art/paint/plants.py    # 29 plants -> assets/sprites/plants/<id>/{part}.png + rig.json
python3 tools/art/paint/zombies.py   # 9 zombies -> assets/sprites/zombies/<id>/{part}.png + rig.json
python3 tools/art/paint/tiles.py     # lawn cells, water, caustics, modular pool coping
python3 tools/fix_imports.py         # turn on mipmaps for sprites/tiles/ui, then re-import
```

**Painter kit (`tools/art/paint/kit.py`).** Each part starts as a cairo shape mask. A distance
transform turns the mask into a height field, which gives normals. Those feed toon/half-Lambert
banding, a rim light, a soft specular and ambient occlusion. Parts get a coloured outline, a
darker shade of the fill, never black. Layers composite with alpha. `export_rig` writes the
part PNGs (painted at 2×) and `rig.json`.
`tools/art/paint/parts.py` has the shared pieces: leaves, stems, eyes with lids and brows,
mouths, petal rings, seed discs, spikes, glows and wood texture.

**Plant part conventions.**
| Template | Parts |
|---|---|
| stem plants | `back` (leaves), `stem`, `head` (child of stem), `lids` (blink), `front`, optional `jaw` (traps) |
| walls | `body`, `body_1`, `body_2` (damage stages), `lids` |
| mines | `buried`, `body`, `light` (armed blink), `lids` |
| Elder Oak | `body`, `canopy`, `lids` |
| Lily Raft | `body` (also drawn under any plant that stands on a raft) |
Meta in `rig.json` holds `muzzle`/`muzzles` (shooters, in plant-local px from the feet) and `platform`.

**Zombie parts.** `thigh, shin, arm_upper, arm_fore, arm_stub, torso, head, jaw`, headgear
`hat_0..2` (cone/bucket damage stages, band, helmet), `shield_0/1`, `flag`, `club` (Brute),
`pole` (Hurdler), `pick` (Burrower) and `tube` (swim ring). Limbs are painted hanging down
from their pivot, so the kinematics only rotate them.

**Runtime (`core/rig.gd`).** `Rig.plant(id)` and `Rig.zombie(id)` load and cache a rig.
`draw(ci, part, xf, modulate)` draws one part with its pivot at `xf`.
- Plants: `Plant.draw_rig(pose_transform())` walks the parent chain and asks the subclass hooks
  `rig_local(part)`, `rig_visible(part)`, `rig_modulate(part)`, `draw_rig_extras()` and
  `rig_point(key)` (muzzle positions). Blinking, recoil, jaw snaps, damage stages and mine
  lights are all done in these hooks.
- Zombies: `_draw_rig_humanoid()` uses two-bone legs and arms (`_rig_leg`, `_rig_arm`, `_bone`),
  upper-body lean, head tilt and pop-off. Hooks: `hat_part()`, `rig_back_items()`,
  `rig_front_items()` (Brute club, Hurdler pole, Burrower pick, flags, shields).
- **Swimming:** `submerge` (0–1) follows whether the zombie's cell is water. The body sinks
  46 px, the legs fade out, the `tube` part is drawn, and ripple rings are drawn behind and in
  front of the body.

## 1. Pose properties + AnimationLibrary
Clips are generated as data, not hand-keyed in the editor:
```
godot --headless --path . -s res://tools/build_anims.gd
```
This writes `anim/plant_anims.tres` and `anim/zombie_anims.tres`. Keys snap to 1/30 s.

### Plants (`entities/plants/plant.gd`)
Pose properties: `pose_squash`, `pose_lean`, `pose_bob`, `pose_grow`,
`pose_alpha`, `pose_glow`. `pose_transform()` turns them (plus the idle
sway, pop and hit wobble) into a `Transform2D` applied with
`draw_set_transform_matrix`, origin at the plant's feet.

| Clip | Length | Use |
|---|---|---|
| idle_stem / idle_ground / idle_wall / idle_float / idle_legend | 1.8–3.2 s loop | per-role idle (`idle_clip()` override) |
| action | 0.4 s | shooters/traps: wind-up → recoil, `_on_action_frame` event |
| action_heavy | 0.7 s | AoE, hive, storm: bigger wind-up |
| produce | 0.6 s | producers: puff, sun spawns on the event |
| spawn | 0.47 s | grow out of the ground when planted |
| chew | 0.5 s loop | Snapper Trap digesting |
| die | 0.5 s | wilt + fade, `_on_die_finished` frees the node |

`trigger_action(clip, callable)` plays the clip and runs the gameplay callable
on the key frame, so projectiles, sun and bites line up with the motion
(0.5 s fallback timer if no event fires). Hit wobble is a damped spring added
on top of the clip (substepped so slow frames can't blow it up).

### Zombies (`entities/zombies/zombie.gd`)
Two-segment legs (hip, knee, foot) and arms (shoulder, elbow, hand), upper-body
lean around the hip, head tilt, recoil spring.

| Clip | Notes |
|---|---|
| walk (1.0 s loop) | linear `pose_cycle`; `speed_scale` = ground speed / (stride 56 px × body scale), so feet don't slide; `_on_footstep` puts dust down and makes brutes shake the screen |
| eat (1.0 s loop) | speed follows `eat_interval`; `_on_bite_frame` drops crumbs |
| idle (2.0 s loop) | street preview before the battle starts |
| spawn (0.6 s) | rise and shake off |
| die (1.3 s) | head pops off, body falls and fades, `_on_die_finished` |

Frozen or stunned zombies get `speed_scale = 0`, so they freeze mid-pose.

### Status shader
`shaders/entity_fx.gdshader` (replaces the old hit-flash shader) has these
uniforms: `flash`, `tint`, `frozen` (icy desaturation and rim), `burn`
(flickering ember glow), `shimmer` (gold sweep on legendaries) and `seed`.

## 2. FX sprites (Inkscape)
```
python3 tools/art/build_fx_svgs.py   # writes art_src/svg/*.svg
tools/art/render_fx.sh               # inkscape --export-type=png -> assets/fx/
```
Sheets: sparkle (8×64), flame (6×64×96), frost_burst (6×128), lightning
(4×64×256), leaf (4×32), plus ice_block, snowflake and legend_aura.
`core/fx_sheet.gd` (`FxSheet`) slices them into one-shot or looping Sprite2Ds;
`Battle._tex_burst()` uses them as CPUParticles2D textures.

## 3. Backdrops and the modular board
- Each world's surround and playfield ground come from `assets/art/worlds/<world>/`
  (`world_art.tres`: `environment.jpg` 1920×1080, `ground.webp` exactly 1170×700 = the board
  rect, edge overlay, per-lane fringe strips, tufts, blocked prop). They are built by
  `python3 tools/art/build_all.py --only worlds` and loaded by `WorldArtLoader`. Missing art logs
  a loud error and shows a magenta placeholder. `BattleFrame` centres the 1920×1080 stage on
  wider/taller screens and `LawnRenderer` mirrors the surround into the margins.
- `assets/tiles/pool/`:
  - `water.png` and `caustics.png`: 512 px tileable textures, animated by `shaders/water.gdshader`
    with world-space UVs, two caustic layers, wobble and sparkle.
  - `coping_edge.png` (horizontal) and `coping_edge_v.png` (vertical): straight stone coping.
    The land side is at the top of the texture, with a baked shadow on the water side.
  - `coping_corner_outer.png`: concave pool corner, used where two edges meet.
  - `coping_corner_inner.png`: quarter-disc wrapped round a convex land corner, used where only
    the diagonal neighbour is land.
  - `stone_tile.png`: tileable deck stone.
  - `variants/water_*.png`: pre-baked previews (full, enclosed, left+right, left, right, top+bottom).
    The game doesn't need them, because it assembles any layout from the modular pieces.
- `Board` layers, bottom to top: backdrop and lawn cells → `WaterLayer` (shader) → `EdgeLayer`
  (rotated coping pieces; the board border counts as land) → `HoverLayer`.
  The layout comes from `LevelData.water` (5 strings of 9 chars, `~` = water).
- `map_lawn.jpg`, `map_pool.jpg` and `hub_greenhouse.jpg` are used through `ScreenBg.with_art(path, dim)`.

## 4. Krita
The toolset's Krita 6.0.4 AppImage needs glibc ≥ 2.35. It doesn't start on
glibc 2.34 hosts (the build machine), so no asset depends on Krita. Inkscape
covers the vector FX, and the Python painters produce the raster art.

## 5. Preview capture
`tools/showcase.tscn` sets up a staged battle (all legendaries, frozen and
burning zombies) and saves 30 fps frames:
```
Xvfb :99 &; export DISPLAY=:99
godot --path . --rendering-driver opengl3 res://tools/showcase.tscn -- /tmp/sc lawn 90   # or: pool
ffmpeg -framerate 30 -i /tmp/sc/f_%03d.png -vf scale=960:540,format=yuv420p showcase.mp4
```
