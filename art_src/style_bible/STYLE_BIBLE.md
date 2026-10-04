# Garden Defense — Style Bible v1 (awaiting approval)

Reference sheet: `reference_sheet.jpg`. Lawn value options: `lawn_band_options.jpg`.
Machine-readable values: `palettes.json`, the single source for every script and for the Godot `WorldArtConfig` resources.
Rebuild both sheets with:
`python3 tools/art/review/make_style_sheet.py --entities art_src/references/entities_lineup.png`

## 1. Direction in one line
Cozy, hand-painted gouache garden. Soft rounded shapes, visible brush texture, warm key light from top-left, cool soft shadows. The plants and zombies are fixed; everything else is built to sit under them.

## 2. Light
- Key light comes from the top-left (135°), warm `#ffe2a8`. Shadows are cool `#3a4a78`, soft, and fall down-right.
- Contact shadows are their own layer under fences, hedges, the house and the lawn edge. They are never baked into a tileable texture.
- Ambient occlusion only where objects meet the ground. No full-screen vignette, and no "dim the art so the UI reads".

## 3. Value and colour (measured, not guessed)
I measured the real rigs (`tools/art/review/render_entities.gd`):
- Plant pixels: median L\* 49, saturation 0.57.
- Outlines: L\* ≈ 20.
- Old lawn: L\* 67, saturation 0.66.
- Raw generated lawn: L\* 69, saturation 0.77.

Green plant bodies disappear against bright yellow-green grass. The worst case is the pod shooter, at body-vs-lawn ΔE 20.9.

I ran a grid search over lawn L\*, saturation and hue, scored on the worst green plant (`make_style_sheet.py`, `lawn_band_options.jpg`):

| Lawn band | Worst green-plant ΔE | Look |
|---|---|---|
| raw generation | 20.9 | lush, plants blend |
| sat ≤ 0.40 | 24.7 | lush, slightly better |
| **sat ≤ 0.36 (proposed)** | **27.3** | lively, clearly readable |
| sat ≤ 0.32 | 30.2 | most readable, a bit dull |

**Proposal:** playfield lawn L\* 40–48, HSV saturation ≤ 0.36, hue 96–106°. The field is the calm "stage". Saturation and brightness belong to the characters, the sun and the UI. Life comes from texture, mow stripes and light, not from neon green.

## 4. Grid readability (9×5) without a checkerboard
- **Mow stripes per column:** ΔL\* ≈ 5. These carry the column read. Rows are read from the lane spacing and the character feet line.
- **Per-cell variation:** ΔL\* ≈ 2.5, with a soft-edged random offset per cell. It should be barely visible.
- **Forbidden:** cell borders, alternating tiles, `draw_rect` overlays.
- The hover/placement highlight stays as the explicit cell indicator, drawn as a soft painted cursor rather than a rectangle.

## 5. Edges and composition
- The lawn layer is exactly `Board.board_rect()` = (310, 200, 1170×700) at 1080p. Cells are 130×140.
- The edge goes from grass to soil/curb through a painted mask plus tuft overlays that overhang the border by 10–30 px. The silhouette is irregular and never a rectangle.
- **Environment plate:** house/porch on the left (where the mowers live, x < 310) and fence/hedge on top (y < 200). The street/path on the right (x > 1480) is where zombies enter. The plate has no lawn in the middle; that area is soil or a clean cut-out.
- **Foreground** (branches, leaves) sits only in the margins (y > 900 or x < 250). It never covers a playable cell.
- **Characters:** plants are about 1 cell tall, zombies about 1.6 cells. The prop scale must match, e.g. fence pickets around 0.6 cell.

## 6. Line and brush
- Outlines are coloured, never black: `#2c2418`, about 3 px at 1080p, on props only. Ground textures have no outlines.
- Gouache strokes stay visible at 1:1. Upscaled pieces (Real-ESRGAN) get grain and sharpness matched back to native pieces.
- No airbrush gradients, no flat vector fills, no photo textures.

## 7. Worlds: less emphasis, one kit
The game has 8 world ids (data, unchanged). Instead of 8 bespoke art sets, there is **one shared garden kit**: lawn ingredients, edges, tufts, fence, hedge and foreground. Each world adds:
- a **light grade** (`grade` in `palettes.json`: gain, lift, saturation, exposure),
- a **ground ramp**: grass, sand, tile, snow, soil or gravel,
- one environment plate and at most 3 world-specific props (pool water mask plus the existing shader, roof pots, frost snow caps…).

Section C of the reference sheet is a palette proof done with a gradient map. It is not final art.

## 8. UI: one material set for the whole game
- Honey wood frame, parchment surface, leaf-green interactive faces, brass details.
- The world only tints the accent colour, so there is no per-world UI material.
- **Button states:**
  - normal `#6fae3e`
  - hover `#82c24c`
  - pressed `#4f8a2c` (inset)
  - disabled `#8c9484`
  - focus: ring `#ffd45a`
- **Rarity trims:** common = wood, rare = teal-silver, epic = violet, legendary = gold.
- All panels are 9-slice `StyleBoxTexture`. Text uses real fonts, never generated text. The logo lettering is font plus Inkscape outline.

## 9. Generation rules
- Generate ingredients, never "a lawn with a grid".
- Prompts never contain text, numbers, logos, people or PvZ characters. Prompts and outputs are logged in `art_src/prompts/`.
- The image tool exposes no seed. Generated PNGs are therefore committed as sources, and every later step is deterministic.
- Overlays and sprites: the model's transparency is unreliable, so alpha is cut deterministically (`tools/art/process`) and checked by `validate_assets.py`.

## 10. Self-review checklist (every screen)
Consistent light · no seams or visible repetition · no rectangular frame around the field · every plant/zombie readable on every cell (worst green ΔE ≥ 25) · column read without a checkerboard · no generation artifacts or stray text · palette within `palettes.json` · UI legible on any background.
