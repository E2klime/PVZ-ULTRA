# Art pipeline

Status: **stage 0–1 done (recon, before shots, style bible). Waiting for style approval before mass generation.**
Rules: see `art_src/style_bible/STYLE_BIBLE.md`. Values: `art_src/style_bible/palettes.json`.

## Folder structure

| Path | What | Git |
|---|---|---|
| `assets/art/garden_kit/{lawn,overlays,foreground,decor}/` | runtime: shared lawn kit (stage 2) | yes |
| `assets/art/worlds/<world>/` | runtime: environment plate + `world_art.tres` (stage 2–3) | yes |
| `assets/ui/garden/{panels,buttons,cards,icons,bars,cursors}/` | runtime: UI textures (stage 4) | yes |
| `art_src/style_bible/` | style bible, palettes.json, reference frames | yes |
| `art_src/prompts/` | every generation prompt + output path (no seed exposed by the model) | yes |
| `art_src/references/` | rig line-up and scale/light crops (read-only reference) | yes |
| `art_src/{krita,material_maker,blender,gimp,inkscape}/` | editable sources (.kra, .ptex, .blend, .xcf, logo .svg) | yes |
| `tools/art/common/` | shared helpers (palette, sheets) | yes |
| `tools/art/{generate,process,assemble,export}/` | pipeline steps | yes |
| `tools/art/review/` | capture, contact sheets, `validate_assets.py` | yes |
| `tools/art/build_all.py` | single orchestrator (stage 2) | yes |
| `art_build/` | intermediates | **ignored** |
| `review/shots/before/` | baseline screenshots (JPG) | yes |
| `review/shots/latest/`, `review/contact_sheets/`, `review/reports/` | review output | **ignored** (copied to `after/` on release) |

Godot code (stage 2):
- `core/art/{world_art_config.gd, world_art_loader.gd, lawn_renderer.gd, lawn_edge_overlay.gd, lawn_lighting.gd}`
- `ui/theme/{theme_builder.gd, panels.gd, buttons.gd, bars.gd, cards.gd}`

## Commands (so far)

```bash
# baseline/after screenshots at 1920x1080, 1600x900, 2400x1080 (needs Godot 4.7 + xvfb)
GODOT=~/bin/godot tools/art/review/capture_all.sh review/shots/latest
# rig line-up used for readability metrics
xvfb-run -a godot --path . --rendering-driver opengl3 tools/art/review/render_entities.tscn
# style bible sheets
python3 tools/art/review/make_style_sheet.py --entities art_src/references/entities_lineup.png
# lawn tone normalization of any frame
python3 tools/art/process/normalize_tone.py in.png out.png --world lawn
```

## Tools: what each is for, or why it is skipped

| Tool | Use | Status |
|---|---|---|
| Image model (gpt-image-2.5-flare) | ingredients, plates, UI materials. Never text. | used |
| Pillow / numpy | compositing, tone normalization, sheets | used |
| OpenCV / scikit-image | masks, Lab metrics, SSIM, seam check | used |
| ImageMagick | batch resize/convert/montage | used |
| Krita (headless `--export`, needs xvfb) | manual paint-over sources `.kra` | available |
| Material Maker 1.7 | tileable ground `.ptex` → albedo/normal. CLI export works but hangs on exit, so it runs under a timeout | available |
| Real-ESRGAN ncnn | 2x upscale of small generations. CPU-Vulkan only: ~19 s per 128 px, `realesr-animevideov3` only, used sparingly | slow but usable |
| ComfyUI | **skipped**: no GPU in the build environment. CPU diffusion is impractical and unnecessary next to the image model. | skipped |
| Blender headless | contact-shadow / AO bakes for props | available |
| GIMP (gimp-console batch) | fallback for manual retouch `.xcf` | available |
| Inkscape | **logo lettering outlines only** | reserved |
