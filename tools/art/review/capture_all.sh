#!/usr/bin/env bash
# Capture review screenshots: every screen, map + seed select per world, battle per world,
# at 1920x1080, 1600x900 and a narrow phone aspect (2400x1080 -> stretch aspect "expand").
# usage: tools/art/review/capture_all.sh [out_root] [resolutions...]
# Needs godot on PATH (or $GODOT) and xvfb-run. Output is local-only (review/ is git-ignored).
set -euo pipefail
cd "$(dirname "$0")/../../.."
OUT="${1:-review/latest}"
shift || true
RESES=("$@")
[ ${#RESES[@]} -eq 0 ] && RESES=(1920x1080 1600x900 2400x1080)
GODOT="${GODOT:-godot}"
export HOME="${GD_TEST_HOME:-/tmp/gd_review_home}"
mkdir -p "$HOME"
run() {  # <res> <scene> <log>
  local W="${1%x*}" H="${1#*x}"
  xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path . --rendering-driver opengl3 \
    --resolution "$1" "$2" -- "$D" > "$3" 2>&1 || echo "FAILED $2 at $1"
}
for RES in "${RESES[@]}"; do
  D="$OUT/$RES"; mkdir -p "$D"
  run "$RES" res://tools/art/review/capture_screens.tscn "$D/screens.log" &
  run "$RES" res://tools/art/review/capture_battles.tscn "$D/battles.log" &
  wait
  echo "$RES: $(ls "$D"/*.png | wc -l) shots, $(cat "$D"/*.log | grep -cE '^(ERROR|SCRIPT ERROR)' || true) error lines"
done
