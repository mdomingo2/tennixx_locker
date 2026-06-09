#!/usr/bin/env bash
# Export every printable tile (and whole-panel references) to ./stl as STL.
# Usage: ./export_stls.sh
set -euo pipefail
SCAD="src/locker.scad"
OUT="stl"
mkdir -p "$OUT"

# OpenSCAD is headless-friendly via xvfb-run if no display is present.
RUN="openscad"
command -v xvfb-run >/dev/null 2>&1 && [ -z "${DISPLAY:-}" ] && RUN="xvfb-run -a openscad"

# tile grid per panel (must match ntiles() in the .scad; printed by --info below)
declare -A NU=( [bottom]=2 [top]=2 [back]=2 [left]=3 [right]=3 )
declare -A NV=( [bottom]=3 [top]=3 [back]=3 [left]=3 [right]=3 )

fail=0
for p in bottom top back left right; do
  for ((i=0;i<${NU[$p]};i++)); do
    for ((j=0;j<${NV[$p]};j++)); do
      f="$OUT/${p}_${i}_${j}.stl"
      if $RUN -o "$f" -D "mode=\"tile\"" -D "which=\"$p\"" -D "ti=$i" -D "tj=$j" "$SCAD" 2>err.log; then
        if [ ! -s "$f" ]; then echo "EMPTY  $f"; fail=1; fi
      else
        echo "ERROR  $f"; cat err.log; fail=1
      fi
    done
  done
done
rm -f err.log
echo "------------------------------------------------"
[ "$fail" -eq 0 ] && echo "All tiles exported OK -> $OUT/" || { echo "Some exports failed"; exit 1; }
ls -1 "$OUT" | wc -l | xargs echo "STL files:"
