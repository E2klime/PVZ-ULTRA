#!/usr/bin/env bash
# Capture review screenshots (all screens + battle per world) at several resolutions.
# usage: tools/art/review/capture_all.sh <out_root>   (needs godot on PATH, xvfb-run)
set -euo pipefail
cd "$(dirname "$0")/../../.."
OUT="${1:-review/shots/latest}"
GODOT="${GODOT:-godot}"
export HOME="${GD_TEST_HOME:-/tmp/gd_review_home}"
mkdir -p "$HOME"
for RES in 1920x1080 1600x900 2400x1080; do
  W="${RES%x*}"; H="${RES#*x}"
  D="$OUT/$RES"; mkdir -p "$D"
  xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path . --rendering-driver opengl3 \
    --resolution "$RES" res://tools/screenshot.tscn -- "$D" > "$D/screens.log" 2>&1 || echo "screens failed $RES"
  xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path . --rendering-driver opengl3 \
    --resolution "$RES" res://tools/art/review/capture_battles.tscn -- "$D" > "$D/battles.log" 2>&1 || echo "battles failed $RES"
  echo "$RES: $(ls "$D"/*.png | wc -l) shots"
done
