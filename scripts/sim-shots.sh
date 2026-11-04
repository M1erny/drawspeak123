#!/bin/bash
# Captures simulator screenshots of Drawspeak states for UI review.
# Usage: scripts/sim-shots.sh <out-dir> [light|dark] [state...]
set -euo pipefail
OUT=${1:?out dir}; APPEARANCE=${2:-light}; shift 2 || true
STATES=${*:-"canvas inspector feedback settings history notes addRegion threads canvases"}
UDID=$(cat /tmp/ds-sim-udid)
mkdir -p "$OUT"
xcrun simctl ui "$UDID" appearance "$APPEARANCE"
for state in $STATES; do
  xcrun simctl terminate "$UDID" com.wydrox.drawspeak 2>/dev/null || true
  if [ "$state" = canvas ]; then
    xcrun simctl launch "$UDID" com.wydrox.drawspeak -DrawspeakSeedDemo >/dev/null
  else
    xcrun simctl launch "$UDID" com.wydrox.drawspeak -DrawspeakSeedDemo -DrawspeakOpen "$state" >/dev/null
  fi
  sleep 5
  xcrun simctl io "$UDID" screenshot "$OUT/$APPEARANCE-$state.png" >/dev/null 2>&1
  sips -Z 1400 "$OUT/$APPEARANCE-$state.png" >/dev/null
done
ls "$OUT"
