# Plant style bible (v2, pilot)

Plants are read first by **silhouette at 96 px**, then by colour, then by face.

## Look
- **Painted**: soft gouache/digital-paint rendering with visible brush texture and the same
  storybook finish as the world surrounds (`art_src/finals/env/env_garden_v3.webp`). No vector
  gradients and no plastic gloss.
- **Light**: warm key light from the top-left (#ffe6b0), cool violet-blue shadows (#4a4a78
  multiplied), a thin warm rim on the light side and a faint cool bounce on the right.
- **No baked ground shadow.** The game draws contact shadows (`LawnLighting`).
- **Outline**: no black ink line. Edges come from value contrast; a darker local-colour edge
  of 1–2 px at 96 px is allowed.
- **Palette**: at most 5 colours + 1 accent per plant (see the brief). The accent is the single
  most saturated hue and marks the gameplay "business end" (muzzle, glow, jaw, sun).
- **Faces**: never a generic round blob with two googly eyes. Faces are made of botanical parts:
  knot holes, seed dots, a split in a husk, a petal lip. Small eyes, set by the anatomy, with
  personality in the brows and lids. Some plants have no face.
- **Proportion**: each plant fits its cell (130×140 on screen). Feet sit at the rig root and
  nothing reaches more than 8 px below it. Height follows the role: producers and support are
  medium, shooters medium-low, walls wide, legendaries tall.

## Production
- Painted by the environment's image model at 1024 px on flat #FF00FF, one full figure per
  image, then keyed, despilled, cut into rig parts by `tools/art/plants/` and downscaled to the
  2× rig size with an unsharp mask. Runtime draws parts at 0.5.
- Gameplay anchors (muzzle, platform, hang point, hinge) come from the existing rig meta and
  never move. The art is fitted to the anchor, not the other way round.
- Budget: ≤ 400 KB per plant (all parts). Target is ≤ 120 KB.

## Checks (`tools/art/plants/check_plants.py`)
96 px silhouette sheet; pairwise silhouette IoU < 0.80; mean palette distance ≥ 18 (ΔE76)
between plants of the same role; readability (silhouette contrast against every world ground);
checklist per brief.

## Status (v2 roster)
- Redone (34): pod_shooter sunbud bark_wall dandelion_puff snapper_trap lantern_bloom lily_raft elder_oak,
  ironbark_wall frost_barrier pepper_wall solar_barricade thornwall bramble_vine pumpkin_shell thorn_pumpkin,
  twin_pod ember_pod gale_pod pepper_stinger frost_mint glacier_shooter spine_cactus needle_volley hail_volley,
  solar_turret phoenix_lily storm_thistle storm_pod needle_storm healing_lantern thorn_lantern twin_sunbud dawn_bloom.
- Still v1 art (30): briefs ready in briefs.json; generate a 5x3 sheet, then
  `split_sheet.py sheet.png 3 <ids...>` and `ingest.py --rebuild`.
- Rebuild: `python3 tools/art/plants/ingest.py --rebuild` (re-cuts every stored concept onto the frozen
  label maps in labels/), `python3 tools/art/plants/preview_sheet.py out.jpg` (96 px silhouettes + IoU).
