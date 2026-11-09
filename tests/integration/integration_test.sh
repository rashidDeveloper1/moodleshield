#!/usr/bin/env bash
# Integration tests: Moodle reachability, login, SCORM, and Reading Library flow.
# Requires: curl
# Usage: MOODLE_HOST=lms.example.com MOODLE_PASS=secret ./tests/integration/integration_test.sh

set -euo pipefail

HOST="${MOODLE_HOST:-lms.example.com}"
USER="${MOODLE_USER:-admin}"
PASS="${MOODLE_PASS:?Set MOODLE_PASS}"
BASE="https://$HOST"
COOKIE_JAR="/tmp/moodle-test-cookies.txt"
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  [PASS] $1"; ((PASS_COUNT++)); }
fail() { echo "  [FAIL] $1"; ((FAIL_COUNT++)); }

echo "==> Integration tests against $BASE"

echo "--- Reachability"
STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE/")
if [[ "$STATUS" == "200" ]]; then
    pass "Home page returns 200"
else
    fail "Home page returned $STATUS"
fi

echo "--- Login"
LOGIN_TOKEN=$(curl -sc "$COOKIE_JAR" "$BASE/login/index.php" | \
    grep -oP 'name="logintoken" value="\K[^"]+' || true)

LOGIN_STATUS=$(curl -sb "$COOKIE_JAR" -c "$COOKIE_JAR" -so /dev/null -w "%{http_code}" \
    --data-urlencode "username=$USER" \
    --data-urlencode "password=$PASS" \
    --data-urlencode "logintoken=$LOGIN_TOKEN" \
    "$BASE/login/index.php")

if [[ "$LOGIN_STATUS" == "303" || "$LOGIN_STATUS" == "200" ]]; then
    pass "Login succeeded"
else
    fail "Login returned $LOGIN_STATUS"
fi

DASH_STATUS=$(curl -sb "$COOKIE_JAR" -so /dev/null -w "%{http_code}" "$BASE/my/")
if [[ "$DASH_STATUS" == "200" ]]; then
    pass "Dashboard accessible after login"
else
    fail "Dashboard returned $DASH_STATUS after login"
fi

echo "--- SCORM"
SCORM_STATUS=$(curl -sb "$COOKIE_JAR" -so /dev/null -w "%{http_code}" "$BASE/mod/scorm/")
if [[ "$SCORM_STATUS" != "404" ]]; then
    pass "SCORM module endpoint reachable"
else
    fail "SCORM module returned 404"
fi

echo "--- Reading Library plugin"
RL_STATUS=$(curl -sb "$COOKIE_JAR" -so /dev/null -w "%{http_code}" "$BASE/mod/readinglibrary/")
if [[ "$RL_STATUS" != "404" ]]; then
    pass "Reading Library module endpoint reachable"
else
    fail "Reading Library module returned 404"
fi

echo "--- PDF token security"
PDF_STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE/mod/readinglibrary/view_pdf.php?token=invalid")
if [[ "$PDF_STATUS" == "403" || "$PDF_STATUS" == "302" ]]; then
    pass "Invalid PDF token correctly rejected"
else
    fail "Invalid PDF token returned $PDF_STATUS (expected 403)"
fi

rm -f "$COOKIE_JAR"

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[[ "$FAIL_COUNT" -eq 0 ]] && exit 0 || exit 1
