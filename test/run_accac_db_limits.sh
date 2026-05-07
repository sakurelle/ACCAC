#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

JMX="${JMX:-$SCRIPT_DIR/ACCAC_DB_LIMITS.jmx}"
OUT="${OUT:-$SCRIPT_DIR/jmeter-db-limits}"

CMP_IDS="${CMP_IDS:-$REPO_DIR/test/cmp_ids.csv}"
ANT_IDS="${ANT_IDS:-$REPO_DIR/test/ant_ids.csv}"

DURATION="${DURATION:-300}"
RAMP="${RAMP:-60}"

if [ ! -f "$JMX" ]; then
  echo "ERROR: JMX file not found: $JMX"
  exit 1
fi

if [ ! -f "$CMP_IDS" ]; then
  echo "ERROR: CMP IDS file not found: $CMP_IDS"
  exit 1
fi

if [ ! -f "$ANT_IDS" ]; then
  echo "ERROR: ANT IDS file not found: $ANT_IDS"
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"

for THREADS in 10 25 50 100 200 300 500 750 1000; do
  STEP_DIR="$OUT/${THREADS}threads"
  mkdir -p "$STEP_DIR"

  echo "Running limit test: threads=$THREADS"

  jmeter -n \
    -t "$JMX" \
    -l "$STEP_DIR/result.jtl" \
    -j "$STEP_DIR/jmeter.log" \
    -Jthreads="$THREADS" \
    -Jpool="$THREADS" \
    -Jramp="$RAMP" \
    -Jduration="$DURATION" \
    -Jloops="-1" \
    -Jcmp_ids="$CMP_IDS" \
    -Jant_ids="$ANT_IDS"

  if [ ! -s "$STEP_DIR/result.jtl" ] || [ "$(wc -l < "$STEP_DIR/result.jtl")" -le 1 ]; then
    echo "ERROR: result.jtl is empty for ${THREADS} threads"
    echo "See log: $STEP_DIR/jmeter.log"
    exit 1
  fi

  jmeter -g "$STEP_DIR/result.jtl" -o "$STEP_DIR/report"
done

echo "Done. Reports are in: $OUT"
