#!/usr/bin/env bash
# http_check.sh - Check HTTP endpoints return expected status codes
#
# Usage: http_check.sh <url> [expected_status]
#
# Expected status codes (defaults to 200 if not specified):
#   200 - OK
#   302 - Redirect
#   401 - Unauthorized (expected if auth is enabled)

set -euo pipefail

URL="$1"
EXPECTED_STATUS="${2:-200,302,401}"
MAX_RETRIES="${3:-30}"
RETRY_DELAY="${4:-2}"

echo "🌐 Checking HTTP endpoint: $URL"
echo "   Expected status: $EXPECTED_STATUS"
echo ""

for i in $(seq 1 $MAX_RETRIES); do
    # Use curl to get HTTP status code
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$URL" 2>/dev/null || echo "000")
    
    # Check if the status code is in the expected list
    if echo "$EXPECTED_STATUS" | grep -q "$HTTP_CODE"; then
        echo "✅ Success! Got HTTP $HTTP_CODE (attempt $i/$MAX_RETRIES)"
        exit 0
    else
        if [ "$HTTP_CODE" = "000" ]; then
            echo "⏳ Attempt $i/$MAX_RETRIES: Connection failed, retrying..."
        else
            echo "⏳ Attempt $i/$MAX_RETRIES: Got HTTP $HTTP_CODE (expected $EXPECTED_STATUS), retrying..."
        fi
        
        if [ $i -lt $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
    fi
done

echo ""
echo "❌ Failed after $MAX_RETRIES attempts"
echo "   Last status code: $HTTP_CODE"
echo "   Expected: $EXPECTED_STATUS"
exit 1
