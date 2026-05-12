#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JMETER_PLAN="$SCRIPT_DIR/plans/ACCAC_DB_LIMITS.jmx"
DATA_DIR="$SCRIPT_DIR/data"
RESULTS_DIR="$SCRIPT_DIR/jmeter-results/db-limits"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-accac}"
DB_SCHEMA="${DB_SCHEMA:-sc_accac}"
DB_USER="${DB_USER:-accac_user}"
DB_PASS="${DB_PASS:-change_me}"

THREAD_STEPS="${THREAD_STEPS:-430 450 470 500 1000 2000 3000 5000 10000 15000 20000 25000 30000}"
RAMP="${RAMP:-10}"
DURATION="${DURATION:-60}"
LOOPS="${LOOPS:-100000000}"

if [ ! -f "$JMETER_PLAN" ]; then
  echo "ERROR: JMeter plan not found: $JMETER_PLAN"
  exit 1
fi

if [ ! -f "$DATA_DIR/cmp_ids.csv" ] || [ ! -f "$DATA_DIR/ant_ids.csv" ]; then
  echo "ERROR: CSV data files not found in $DATA_DIR"
  exit 1
fi

if ! command -v jmeter >/dev/null 2>&1; then
  echo "ERROR: jmeter command not found"
  exit 1
fi

mkdir -p "$RESULTS_DIR"

LAST_OK_THREADS=""
LIMIT_THREADS=""
LIMIT_DIR=""

for THREADS in $THREAD_STEPS; do
  RUN_DIR="$RESULTS_DIR/${THREADS}_threads"

  echo "========================================"
  echo "Starting DB limit test"
  echo "Threads:  $THREADS"
  echo "Ramp:     $RAMP"
  echo "Duration: $DURATION"
  echo "Plan:     $JMETER_PLAN"
  echo "Output:   $RUN_DIR"
  echo "========================================"

  rm -rf "$RUN_DIR"
  mkdir -p "$RUN_DIR"

  JMETER_EXIT_CODE=0

  jmeter -n \
    -t "$JMETER_PLAN" \
    -l "$RUN_DIR/result.jtl" \
    -j "$RUN_DIR/jmeter.log" \
    -Jthreads="$THREADS" \
    -Jpool="$THREADS" \
    -Jramp="$RAMP" \
    -Jduration="$DURATION" \
    -Jloops="$LOOPS" \
    -JDB_HOST="$DB_HOST" \
    -JDB_PORT="$DB_PORT" \
    -JDB_NAME="$DB_NAME" \
    -JDB_SCHEMA="$DB_SCHEMA" \
    -JDB_USER="$DB_USER" \
    -JDB_PASS="$DB_PASS" \
    -Jcmp_ids="$DATA_DIR/cmp_ids.csv" \
    -Jant_ids="$DATA_DIR/ant_ids.csv" || JMETER_EXIT_CODE=$?

  if [ ! -f "$RUN_DIR/result.jtl" ]; then
    SAMPLE_COUNT=0
    ERROR_COUNT=0
  else
    SAMPLE_COUNT="$(awk 'BEGIN { c=0 } /^[0-9]/ { c++ } END { print c }' "$RUN_DIR/result.jtl")"
    ERROR_COUNT="$(awk -F',' 'BEGIN { c=0 } /^[0-9]/ && $8 != "true" { c++ } END { print c }' "$RUN_DIR/result.jtl")"
  fi

  echo "Samples: $SAMPLE_COUNT"
  echo "Errors:  $ERROR_COUNT"
  echo "JMeter exit code: $JMETER_EXIT_CODE"

  if [ "$SAMPLE_COUNT" -eq 0 ]; then
    echo "LIMIT/PROBLEM DETECTED: no samples"
    LIMIT_THREADS="$THREADS"
    LIMIT_DIR="$RUN_DIR"
    break
  fi

  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "LIMIT DETECTED: errors appeared on $THREADS threads"
    LIMIT_THREADS="$THREADS"
    LIMIT_DIR="$RUN_DIR"
    break
  fi

  if [ "$JMETER_EXIT_CODE" -ne 0 ]; then
    echo "LIMIT/PROBLEM DETECTED: JMeter finished with error"
    LIMIT_THREADS="$THREADS"
    LIMIT_DIR="$RUN_DIR"
    break
  fi

  LAST_OK_THREADS="$THREADS"

  echo "OK: $THREADS threads passed without errors"
  echo
done

echo "========================================"

if [ -n "$LIMIT_THREADS" ]; then
  echo "Limit found on: $LIMIT_THREADS threads"

  if [ -n "$LAST_OK_THREADS" ]; then
    echo "Last stable load: $LAST_OK_THREADS threads"
  else
    echo "Last stable load: not found"
  fi

  echo "Generating HTML report only for limit step..."

  rm -rf "$LIMIT_DIR/report"

  jmeter -g "$LIMIT_DIR/result.jtl" \
    -o "$LIMIT_DIR/report" \
    -j "$LIMIT_DIR/report-generation.log"

  echo "HTML report:"
  echo "$LIMIT_DIR/report/index.html"
else
  echo "Limit was not found in selected thread steps."
  echo "No HTML report generated."
  echo "Try increasing THREAD_STEPS."
fi

echo "Results directory:"
echo "$RESULTS_DIR"
