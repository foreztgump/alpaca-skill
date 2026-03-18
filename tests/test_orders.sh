#!/usr/bin/env bash
# tests/test_orders.sh — Tests for scripts/alpaca_orders.sh
# Self-contained, runnable via: bash tests/test_orders.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly ORDERS_PATH="${SCRIPT_DIR}/../scripts/alpaca_orders.sh"
readonly LIB_PATH="${SCRIPT_DIR}/../scripts/_lib.sh"

PASS=0
FAIL=0
ERRORS=""

# --- Test helpers ---

assert_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}: output does not contain '${needle}'\n"
    echo "  FAIL  ${test_name}: output does not contain '${needle}'" >&2
  fi
}

assert_not_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}: output should not contain '${needle}'\n"
    echo "  FAIL  ${test_name}: output should not contain '${needle}'" >&2
  fi
}

assert_exit_code() {
  local test_name="$1"
  local expected_code="$2"
  shift 2
  local actual_code=0
  "$@" >/dev/null 2>/dev/null || actual_code=$?
  if [[ "$expected_code" -eq "$actual_code" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}: expected exit ${expected_code}, got ${actual_code}\n"
    echo "  FAIL  ${test_name}: expected exit ${expected_code}, got ${actual_code}" >&2
  fi
}

echo "=== test_orders.sh ==="

# =====================================================================
# Extract function definitions from the orders script for reuse
# =====================================================================

_FUNC_DEFS=$(bash -c '
  export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
  source "'"${LIB_PATH}"'"
  eval "$(sed -n "/^_validate_order_params/,/^}/p" "'"${ORDERS_PATH}"'")"
  eval "$(sed -n "/^_validate_type_params/,/^}/p" "'"${ORDERS_PATH}"'")"
  eval "$(sed -n "/^_validate_crypto_params/,/^}/p" "'"${ORDERS_PATH}"'")"
  eval "$(sed -n "/^_build_order_body/,/^}/p" "'"${ORDERS_PATH}"'")"
  declare -f _validate_order_params _validate_type_params _validate_crypto_params _build_order_body
' 2>/dev/null)

# Helper: build order body, output compact JSON via jq -c
# Usage: body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="market"; qty="10"')
run_build_body() {
  local vars="$1"
  bash -c '
    export APCA_API_KEY_ID="test-key-id"
    export APCA_API_SECRET_KEY="test-secret-key"
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="" side="" order_type="" time_in_force="day"
    qty="" notional="" limit_price="" stop_price=""
    trail_percent="" trail_price="" client_order_id=""
    extended_hours=false take_profit="" stop_loss="" stop_loss_limit=""
    '"${vars}"'
    _build_order_body | jq -c .
  ' 2>/dev/null
}

# =====================================================================
# Body construction tests — _build_order_body
# =====================================================================

# --- Test: Market order with --qty ---
body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="market"; qty="10"')
assert_contains "market order has qty" '"qty":"10"' "$body"
assert_contains "market order has type" '"type":"market"' "$body"
assert_contains "market order has symbol" '"symbol":"AAPL"' "$body"
assert_contains "market order has side" '"side":"buy"' "$body"

# --- Test: Market order with --notional ---
body=$(run_build_body 'symbol="TSLA"; side="buy"; order_type="market"; notional="500"')
assert_contains "notional order has notional" '"notional":"500"' "$body"
assert_not_contains "notional order has no qty" '"qty"' "$body"

# --- Test: Limit order ---
body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="limit"; qty="5"; limit_price="180.00"')
assert_contains "limit order has limit_price" '"limit_price":"180.00"' "$body"
assert_contains "limit order has type limit" '"type":"limit"' "$body"

# --- Test: Stop order ---
body=$(run_build_body 'symbol="AAPL"; side="sell"; order_type="stop"; qty="5"; stop_price="170.00"')
assert_contains "stop order has stop_price" '"stop_price":"170.00"' "$body"
assert_contains "stop order has type stop" '"type":"stop"' "$body"

# --- Test: Stop-limit order ---
body=$(run_build_body 'symbol="AAPL"; side="sell"; order_type="stop_limit"; qty="5"; stop_price="170.00"; limit_price="169.00"')
assert_contains "stop_limit has stop_price" '"stop_price":"170.00"' "$body"
assert_contains "stop_limit has limit_price" '"limit_price":"169.00"' "$body"

# --- Test: Trailing stop with trail_percent ---
body=$(run_build_body 'symbol="AAPL"; side="sell"; order_type="trailing_stop"; qty="5"; trail_percent="5"')
assert_contains "trailing stop has trail_percent" '"trail_percent":"5"' "$body"
assert_contains "trailing stop has type" '"type":"trailing_stop"' "$body"

# --- Test: Bracket order ---
body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="market"; qty="10"; take_profit="200"; stop_loss="170"')
assert_contains "bracket has order_class" '"order_class":"bracket"' "$body"
assert_contains "bracket has take_profit" '"take_profit"' "$body"
assert_contains "bracket take_profit has limit_price" '"limit_price":"200"' "$body"
assert_contains "bracket has stop_loss" '"stop_loss"' "$body"
assert_contains "bracket stop_loss has stop_price" '"stop_price":"170"' "$body"

# =====================================================================
# Validation tests — _validate_order_params
# =====================================================================

# --- Test: Missing limit_price for limit order ---
assert_exit_code "limit without limit_price exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="buy"; order_type="limit"; qty="10"
    time_in_force="day"; notional=""; limit_price=""; stop_price=""
    trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: Both qty and notional ---
assert_exit_code "qty and notional exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="buy"; order_type="market"
    time_in_force="day"; qty="10"; notional="500"
    limit_price=""; stop_price=""; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: Neither qty nor notional ---
assert_exit_code "neither qty nor notional exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="buy"; order_type="market"
    time_in_force="day"; qty=""; notional=""
    limit_price=""; stop_price=""; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: Crypto with stop type ---
assert_exit_code "crypto stop type exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="BTC/USD"; side="sell"; order_type="stop"
    time_in_force="gtc"; qty="1"; notional=""
    limit_price=""; stop_price="50000"; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: Crypto with day TIF ---
assert_exit_code "crypto day TIF exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="BTC/USD"; side="buy"; order_type="market"
    time_in_force="day"; qty="1"; notional=""
    limit_price=""; stop_price=""; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: Valid market order passes validation ---
assert_exit_code "valid market order passes" 0 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="buy"; order_type="market"
    time_in_force="day"; qty="10"; notional=""
    limit_price=""; stop_price=""; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: Stop order without stop_price ---
assert_exit_code "stop without stop_price exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="sell"; order_type="stop"
    time_in_force="day"; qty="5"; notional=""
    limit_price=""; stop_price=""; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: stop_limit without both prices ---
assert_exit_code "stop_limit missing prices exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="sell"; order_type="stop_limit"
    time_in_force="day"; qty="5"; notional=""
    limit_price="169.00"; stop_price=""; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: trailing_stop without trail params ---
assert_exit_code "trailing_stop no trail exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="sell"; order_type="trailing_stop"
    time_in_force="day"; qty="5"; notional=""
    limit_price=""; stop_price=""; trail_percent=""; trail_price=""
    _validate_order_params
  '

# --- Test: trailing_stop with both trail params ---
assert_exit_code "trailing_stop both trails exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="AAPL"; side="sell"; order_type="trailing_stop"
    time_in_force="day"; qty="5"; notional=""
    limit_price=""; stop_price=""; trail_percent="3"; trail_price="5.00"
    _validate_order_params
  '

# --- Test: Crypto trailing_stop rejected ---
assert_exit_code "crypto trailing_stop exits 1" 1 \
  bash -c '
    export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
    source "'"${LIB_PATH}"'"
    '"${_FUNC_DEFS}"'
    symbol="ETH/USD"; side="sell"; order_type="trailing_stop"
    time_in_force="gtc"; qty="1"; notional=""
    limit_price=""; stop_price=""; trail_percent="5"; trail_price=""
    _validate_order_params
  '

# =====================================================================
# Dry-run test — cmd_submit with --dry-run
# =====================================================================

_MOCK_CURL_FILE="/tmp/.test_orders_curl_called_$$"
rm -f "$_MOCK_CURL_FILE"

dry_output=$(bash -c '
  export APCA_API_KEY_ID="test-key-id"
  export APCA_API_SECRET_KEY="test-secret-key"
  source "'"${LIB_PATH}"'"

  curl() {
    echo "CURL_CALLED" > "'"${_MOCK_CURL_FILE}"'"
    printf "%s\n%s" "{}" "200"
  }

  _json_output() { echo "$1"; }

  '"${_FUNC_DEFS}"'
  eval "$(sed -n "/^cmd_submit/,/^}/p" "'"${ORDERS_PATH}"'")"

  cmd_submit AAPL buy market --qty 10 --dry-run
' 2>/dev/null | jq -c .)

assert_contains "dry-run outputs symbol" '"symbol":"AAPL"' "$dry_output"
assert_contains "dry-run outputs side" '"side":"buy"' "$dry_output"
assert_contains "dry-run outputs type" '"type":"market"' "$dry_output"
assert_contains "dry-run outputs qty" '"qty":"10"' "$dry_output"

# Verify curl was NOT called
if [[ -f "$_MOCK_CURL_FILE" ]]; then
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}  FAIL  dry-run should not call curl\n"
  echo "  FAIL  dry-run should not call curl" >&2
  rm -f "$_MOCK_CURL_FILE"
else
  PASS=$((PASS + 1))
fi

# =====================================================================
# Error path tests — mock curl returns error codes
# =====================================================================

# --- Test: 422 response with error message ---
error_422=$(bash -c '
  export APCA_API_KEY_ID="test-key-id"
  export APCA_API_SECRET_KEY="test-secret-key"
  source "'"${LIB_PATH}"'"

  curl() {
    printf "%s\n%s" "{\"message\":\"insufficient qty\"}" "422"
  }

  _json_output() { echo "$1"; }

  '"${_FUNC_DEFS}"'
  eval "$(sed -n "/^cmd_submit/,/^}/p" "'"${ORDERS_PATH}"'")"

  cmd_submit AAPL buy market --qty 10
' 2>&1 || true)

assert_contains "422 error contains message" "insufficient qty" "$error_422"

# --- Test: 429 rate limit response ---
error_429=$(bash -c '
  export APCA_API_KEY_ID="test-key-id"
  export APCA_API_SECRET_KEY="test-secret-key"
  source "'"${LIB_PATH}"'"

  curl() {
    printf "%s\n%s" "{}" "429"
  }

  _json_output() { echo "$1"; }

  '"${_FUNC_DEFS}"'
  eval "$(sed -n "/^cmd_submit/,/^}/p" "'"${ORDERS_PATH}"'")"

  cmd_submit AAPL buy market --qty 10
' 2>&1 || true)

assert_contains "429 error contains rate limit" "Rate limit" "$error_429"

# =====================================================================
# Validation error message content tests
# =====================================================================

error_limit=$(bash -c '
  export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
  source "'"${LIB_PATH}"'"
  '"${_FUNC_DEFS}"'
  symbol="AAPL"; side="buy"; order_type="limit"; qty="10"
  time_in_force="day"; notional=""; limit_price=""; stop_price=""
  trail_percent=""; trail_price=""
  _validate_order_params
' 2>&1 || true)
assert_contains "limit error mentions limit-price" "limit-price" "$error_limit"

error_both=$(bash -c '
  export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
  source "'"${LIB_PATH}"'"
  '"${_FUNC_DEFS}"'
  symbol="AAPL"; side="buy"; order_type="market"
  time_in_force="day"; qty="10"; notional="500"
  limit_price=""; stop_price=""; trail_percent=""; trail_price=""
  _validate_order_params
' 2>&1 || true)
assert_contains "qty+notional error mentions exclusive" "mutually exclusive" "$error_both"

error_crypto=$(bash -c '
  export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s
  source "'"${LIB_PATH}"'"
  '"${_FUNC_DEFS}"'
  symbol="BTC/USD"; side="sell"; order_type="stop"
  time_in_force="gtc"; qty="1"; notional=""
  limit_price=""; stop_price="50000"; trail_percent=""; trail_price=""
  _validate_order_params
' 2>&1 || true)
assert_contains "crypto stop error mentions type" "stop" "$error_crypto"

# =====================================================================
# Extended hours, client_order_id, TIF body tests
# =====================================================================

body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="limit"; qty="5"; limit_price="180.00"; extended_hours=true')
assert_contains "extended hours in body" '"extended_hours":true' "$body"

body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="market"; qty="1"; client_order_id="my-order-123"')
assert_contains "client_order_id in body" '"client_order_id":"my-order-123"' "$body"

body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="market"; qty="10"; time_in_force="gtc"')
assert_contains "tif gtc in body" '"time_in_force":"gtc"' "$body"

# =====================================================================
# Stop-loss with limit price in bracket
# =====================================================================

body=$(run_build_body 'symbol="AAPL"; side="buy"; order_type="market"; qty="10"; take_profit="200"; stop_loss="170"; stop_loss_limit="168"')
assert_contains "bracket stop_loss_limit" '"limit_price":"168"' "$body"

# =====================================================================
# Summary
# =====================================================================

echo ""
echo "test_orders.sh Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailed tests:\n${ERRORS}"
  exit 1
fi
exit 0
