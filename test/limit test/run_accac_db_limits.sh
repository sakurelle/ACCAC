#!/usr/bin/env bash
set -euo pipefail

JMX=${JMX:-/home/sakurelle/ACCAC/test/ACCAC_DB_LIMITS.jmx}
OUT=${OUT:-/home/sakurelle/ACCAC/test/jmeter-db-limits}
CMP_IDS=${CMP_IDS:-/home/sakurelle/ACCAC/test/cmp_ids.csv}
ANT_IDS=${ANT_IDS:-/home/sakurelle/ACCAC/test/ant_ids.csv}
DURATION=${DURATION:-300}
RAMP=${RAMP:-60}

rm -rf "$OUT"
mkdir -p "$OUT"

for THREADS in 10 25 50 100 200 300 500 750 1000; do
  STEP_DIR="$OUT/${THREADS}threads"
  mkdir -p "$STEP_DIR"

  jmeter -n \
    -t "$JMX" \
    -l "$STEP_DIR/result.jtl" \
    -j "$STEP_DIR/jmeter.log" \
    -e -o "$STEP_DIR/report" \
    -Jthreads="$THREADS" \
    -Jpool="$THREADS" \
    -Jramp="$RAMP" \
    -Jduration="$DURATION" \
    -Jcmp_ids="$CMP_IDS" \
    -Jant_ids="$ANT_IDS"
done
