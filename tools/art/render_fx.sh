#!/bin/sh
# Renders art_src/svg/*.svg -> assets/fx/*.png with the portable Inkscape from the toolset.
# Usage (from the project root):  . /data/tools/env.sh && sh tools/art/render_fx.sh
set -eu
cd "$(dirname "$0")/../.."
python3 tools/art/build_fx_svgs.py
command -v inkscape >/dev/null 2>&1 || { echo "inkscape not in PATH (source /data/tools/env.sh)"; exit 1; }
mkdir -p assets/fx
for f in art_src/svg/*.svg; do
    n=$(basename "$f" .svg)
    inkscape "$f" --export-type=png --export-background-opacity=0 --export-filename="assets/fx/$n.png" >/dev/null 2>&1
    echo "rendered assets/fx/$n.png"
done
