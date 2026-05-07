#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

JMETER_PLAN="$SCRIPT_DIR/ACCAC_DB_LIMITS.jmx"
RESULTS_DIR="$SCRIPT_DIR/jmeter-db-limits"

THREAD_STEPS="${THREAD_STEPS:-10 25 50 100 200 300 500 750 1000}"
RAMP="${RAMP:-60}"
DURATION="${DURATION:-300}"
LOOPS="${LOOPS:-100000000}"

if [ ! -f "$JMETER_PLAN" ]; then
  echo "ERROR: JMeter plan not found: $JMETER_PLAN"
  exit 1
fi

if ! command -v jmeter >/dev/null 2>&1; then
  echo "ERROR: jmeter command not found"
  exit 1
fi

mkdir -p "$RESULTS_DIR"

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

  jmeter -n \
    -t "$JMETER_PLAN" \
    -l "$RUN_DIR/result.jtl" \
    -j "$RUN_DIR/jmeter.log" \
    -Jthreads="$THREADS" \
    -Jpool="$THREADS" \
    -Jramp="$RAMP" \
    -Jduration="$DURATION" \
    -Jloops="$LOOPS"

  SAMPLE_COUNT=$(grep -c "^[0-9]" "$RUN_DIR/result.jtl" || true)

  if [ "$SAMPLE_COUNT" -gt 0 ]; then
    echo "Samples: $SAMPLE_COUNT"
    echo "Generating HTML report..."

    jmeter -g "$RUN_DIR/result.jtl" -o "$RUN_DIR/report"

    echo "Report created:"
    echo "$RUN_DIR/report/index.html"
  else
    echo "WARNING: result.jtl has 0 samples"
    echo "HTML report skipped"
    echo "Check log:"
    echo "$RUN_DIR/jmeter.log"
  fi

  echo
done

echo "All tests finished"
echo "Results directory:"
echo "$RESULTS_DIR"