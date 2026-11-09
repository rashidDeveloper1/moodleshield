#!/usr/bin/env bash
# Performance test: PDF streaming latency for a 300-page document.
# Target: first-byte response under 2 seconds on a tablet-class connection.
# Requires: curl, a valid borrow token
# Usage: MOODLE_HOST=lms.example.com PDF_TOKEN=<token> ./tests/performance/pdf_perf_test.sh

set -euo pipefail

HOST="${MOODLE_HOST:-lms.example.com}"
TOKEN="${PDF_TOKEN:?Set PDF_TOKEN to a valid borrow session token}"
TARGET_TTFB=2.0   # seconds — tablet performance target
ITERATIONS=5
PASS=0
FAIL=0

echo "==> PDF streaming performance test ($ITERATIONS iterations)"
echo "    Target TTFB: ${TARGET_TTFB}s"

for i in $(seq 1 "$ITERATIONS"); do
    TTFB=$(curl -so /dev/null \
        -w "%{time_starttransfer}" \
        "https://$HOST/mod/readinglibrary/view_pdf.php?token=$TOKEN")

    # bc comparison: returns 1 if TTFB <= TARGET
    if echo "$TTFB <= $TARGET_TTFB" | bc -l | grep -q "^1$"; then
        echo "  [PASS] Run $i: TTFB ${TTFB}s"
        ((PASS++))
    else
        echo "  [FAIL] Run $i: TTFB ${TTFB}s (exceeded ${TARGET_TTFB}s)"
        ((FAIL++))
    fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed out of $ITERATIONS runs"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
