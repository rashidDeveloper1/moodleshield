#!/usr/bin/env bash
# Security acceptance tests.
# Requires: curl, nmap, openssl
# Usage: MOODLE_HOST=lms.example.com ./tests/security/security_test.sh

set -euo pipefail

HOST="${MOODLE_HOST:-lms.example.com}"
PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; ((PASS++)); }
fail() { echo "  [FAIL] $1"; ((FAIL++)); }

echo "==> Security tests against $HOST"

echo "--- TLS version enforcement"
if openssl s_client -connect "$HOST:443" -tls1 </dev/null 2>&1 | grep -q "handshake failure"; then
    pass "TLS 1.0 rejected"
else
    fail "TLS 1.0 accepted (must be disabled)"
fi

if openssl s_client -connect "$HOST:443" -tls1_1 </dev/null 2>&1 | grep -q "handshake failure"; then
    pass "TLS 1.1 rejected"
else
    fail "TLS 1.1 accepted (must be disabled)"
fi

echo "--- HTTP security headers"
HEADERS=$(curl -sI "https://$HOST")

check_header() {
    local header="$1"
    if echo "$HEADERS" | grep -qi "$header"; then
        pass "$header present"
    else
        fail "$header missing"
    fi
}

check_header "Strict-Transport-Security"
check_header "X-Frame-Options"
check_header "X-Content-Type-Options"
check_header "Referrer-Policy"

echo "--- HTTP → HTTPS redirect"
REDIRECT=$(curl -sI "http://$HOST" | grep -i "^location:" | tr -d '\r')
if echo "$REDIRECT" | grep -q "https://"; then
    pass "HTTP redirects to HTTPS"
else
    fail "HTTP does not redirect to HTTPS"
fi

echo "--- Direct PDF access blocked"
PDF_STATUS=$(curl -so /dev/null -w "%{http_code}" "https://$HOST/some-file.pdf")
if [[ "$PDF_STATUS" == "403" ]]; then
    pass "Direct .pdf access returns 403"
else
    fail "Direct .pdf access returned $PDF_STATUS (expected 403)"
fi

echo "--- Admin access restriction"
ADMIN_STATUS=$(curl -so /dev/null -w "%{http_code}" --max-time 5 "https://$HOST/admin/" 2>/dev/null || echo "000")
if [[ "$ADMIN_STATUS" == "000" || "$ADMIN_STATUS" == "403" ]]; then
    pass "Admin panel not reachable from public internet"
else
    fail "Admin panel returned $ADMIN_STATUS (expected 403 or timeout)"
fi

echo "--- Open port check"
OPEN_PORTS=$(nmap -p 80,443,8080,3306,5432,6379 --open -oG - "$HOST" 2>/dev/null | grep "Ports:" || true)
for UNEXPECTED in 8080 3306 5432 6379; do
    if echo "$OPEN_PORTS" | grep -q "$UNEXPECTED/open"; then
        fail "Port $UNEXPECTED is unexpectedly open"
    else
        pass "Port $UNEXPECTED is closed"
    fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
