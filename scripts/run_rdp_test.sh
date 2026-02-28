#!/bin/bash
# scripts/run_rdp_test.sh
#
# Runs rdp_test for N connect/disconnect cycles.
# Usage: run_rdp_test.sh [cycles] [duration_per_cycle]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN="$PROJECT_DIR/tools/rdp_test/rdp_test"

CYCLES="${1:-10}"
DURATION="${2:-3}"
HOST="192.168.64.2"
USER="iyaps"
PASS="P@ssw0rd"

echo "=== RDP Rapid Connect/Disconnect Test ==="
echo "Cycles: $CYCLES, Duration per cycle: ${DURATION}s"
echo ""

FAILURES=0
for i in $(seq 1 "$CYCLES"); do
    echo "--- Cycle $i/$CYCLES ---"
    if "$BIN" --host "$HOST" --user "$USER" --pass "$PASS" --duration "$DURATION" 2>&1 | grep -E "(CONNECTED|Event loop ended|Clean shutdown|ERROR)"; then
        echo "  ✅ Cycle $i passed"
    else
        echo "  ❌ Cycle $i FAILED"
        FAILURES=$((FAILURES + 1))
    fi
    echo ""
done

echo "=== Results: $((CYCLES - FAILURES))/$CYCLES passed, $FAILURES failures ==="
exit "$FAILURES"
