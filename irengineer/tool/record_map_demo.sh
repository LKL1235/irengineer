#!/usr/bin/env bash
# GUI demo: import sample laps, analyze, click map to move shared cursor.
set -euo pipefail

export DISPLAY="${DISPLAY:-:1}"
export PATH="/home/ubuntu/flutter/bin:${PATH}"
export LIBRARY_PATH="/usr/lib/gcc/x86_64-linux-gnu/13:${LIBRARY_PATH:-}"
export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/x86_64-linux-gnu/c++/13"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DATA_DIR="$REPO_ROOT/data"
REF="$DATA_DIR/Garage 61 - Arnar Kristjansson - FIA F4 - WeatherTech Raceway at Laguna Seca (Full Course) - 01.20.019 - 01KKCBKSYPMGB5JRJ73XE8ASZX.csv"
CAND="$DATA_DIR/Garage 61 - Huang Nan - FIA F4 - WeatherTech Raceway at Laguna Seca (Full Course) - 01.23.328 - 01KT9Y27MSDCBKV0C8FAFEQC45.csv"
BUNDLE="$REPO_ROOT/irengineer/build/linux/x64/debug/bundle/irengineer"
OUT_DIR="${1:-/opt/cursor/artifacts}"
VIDEO="$OUT_DIR/map_tap_demo.mp4"

mkdir -p "$OUT_DIR"
pkill -f 'bundle/irengineer' 2>/dev/null || true
sleep 1

export IRENGINEER_REPO_ROOT="$REPO_ROOT"
export IRENGINEER_FIXTURE_PATHS="$REF,$CAND"
export IRENGINEER_AUTO_ANALYZE=1

cd "$REPO_ROOT/irengineer"
"$BUNDLE" &
APP_PID=$!
sleep 14

WID=""
for _ in $(seq 1 20); do
  WID=$(xdotool search --onlyvisible --name "irengineer" 2>/dev/null | tail -1 || true)
  if [[ -n "$WID" ]]; then
  GEO=$(xdotool getwindowgeometry "$WID" 2>/dev/null || true)
  if echo "$GEO" | grep -q 'Geometry: 12'; then
    break
  fi
  fi
  sleep 0.5
done

if [[ -z "$WID" ]]; then
  echo "Could not find irengineer window" >&2
  kill "$APP_PID" 2>/dev/null || true
  exit 1
fi

xdotool windowactivate --sync "$WID"
xdotool windowmove "$WID" 80 40
xdotool windowsize "$WID" 1320 1000
sleep 1

ffmpeg -y -video_size 1920x1200 -framerate 15 -f x11grab -i "$DISPLAY" \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p "$VIDEO" &
REC_PID=$!
sleep 1

# Scroll the charts panel (Down key works reliably on Flutter ScrollView).
xdotool mousemove --window "$WID" 950 400 click 1
sleep 0.3
xdotool key --repeat 47 Down
sleep 1

# Click map (stay above bottom nav ~y<700).
for XY in "750 720" "1050 680" "650 700" "950 740" "820 660"; do
  set -- $XY
  xdotool mousemove --window "$WID" "$1" "$2" click 1
  sleep 1.6
done

sleep 1
kill "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true

ffmpeg -y -i "$VIDEO" -frames:v 1 "$OUT_DIR/map_tap_demo_poster.png" 2>/dev/null || true
echo "Wrote $VIDEO"
