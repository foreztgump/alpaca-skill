#!/usr/bin/env bash
# tests/test_data_lib.sh — Tests for scripts/_data_lib.sh
# Self-contained, runnable via: bash tests/test_data_lib.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DATA_LIB_PATH="${SCRIPT_DIR}/../scripts/_data_lib.sh"

PASS=0
FAIL=0
ERRORS=""

# Temp file for capturing URLs across subshells
_MOCK_URL_FILE="/tmp/.test_data_lib_url_$$"
trap 'rm -f "$_MOCK_URL_FILE"' EXIT

# --- Test helpers ---

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}: expected '${expected}', got '${actual}'\n"
    echo "  FAIL  ${test_name}: expected '${expected}', got '${actual}'" >&2
  fi
}

assert_contains() {
  local test_name="$1"
  local needle="$2"
  local haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}: '${haystack}' does not contain '${needle}'\n"
    echo "  FAIL  ${test_name}: '${haystack}' does not contain '${needle}'" >&2
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

# Helper: run a _data_lib function in a subshell with a curl mock that captures the URL.
# The mock curl writes the URL to a temp file (since _http_request does 2>/dev/null on curl).
# After sourcing, we override curl as a function and simplify pagination to a single GET.
# Usage: captured_url=$(run_with_mock_curl "_data_bars /v2/stocks AAPL --start 2026-01-01")
run_with_mock_curl() {
  local func_call="$1"
  local url_file="$_MOCK_URL_FILE"

  bash -c '
    export APCA_API_KEY_ID="test-key-id"
    export APCA_API_SECRET_KEY="test-secret-key"

    source "'"${DATA_LIB_PATH}"'"

    # Mock curl AFTER sourcing — writes URL to temp file, returns mock response
    curl() {
      local url="${*: -1}"
      echo "${url}" > "'"${url_file}"'"
      printf "%s\n%s" "{\"bars\":[]}" "200"
    }

    # Simplify _json_output (avoid jq pretty-print in tests)
    _json_output() { echo "$1"; }

    # Simplify _paginate_and_output to a single GET (tests URL construction, not pagination)
    _paginate_and_output() {
      local url="$1"
      local body
      body=$(_api_get "$url")
      _read_http_code
      echo "$body"
    }

    '"${func_call}"'
  ' >/dev/null 2>/dev/null

  if [[ -f "$url_file" ]]; then
    cat "$url_file"
    rm -f "$url_file"
  fi
}

echo "=== test_data_lib.sh ==="

# =====================================================================
# _data_bars URL construction tests
# =====================================================================

# Test: bars URL contains correct path and query params
captured=$(run_with_mock_curl '_data_bars "/v2/stocks" "AAPL" --start 2026-01-01 --end 2026-01-31 --timeframe 1Day')
assert_contains "bars URL contains path /v2/stocks/AAPL/bars" "/v2/stocks/AAPL/bars?" "$captured"
assert_contains "bars URL contains start param" "start=2026-01-01" "$captured"
assert_contains "bars URL contains end param" "end=2026-01-31" "$captured"
assert_contains "bars URL contains timeframe param" "timeframe=1Day" "$captured"

# Test: bars URL defaults timeframe to 1Day when not specified
captured=$(run_with_mock_curl '_data_bars "/v2/stocks" "AAPL" --start 2026-01-01')
assert_contains "bars URL defaults timeframe=1Day" "timeframe=1Day" "$captured"

# =====================================================================
# _data_trades URL construction tests
# =====================================================================

# Test: trades URL contains sort param
captured=$(run_with_mock_curl '_data_trades "/v2/stocks" "AAPL" --start 2026-01-01 --sort desc')
assert_contains "trades URL contains path /v2/stocks/AAPL/trades" "/v2/stocks/AAPL/trades?" "$captured"
assert_contains "trades URL contains sort=desc" "sort=desc" "$captured"

# =====================================================================
# Flag passthrough tests
# =====================================================================

# Test: --feed sip appears in URL
captured=$(run_with_mock_curl '_data_bars "/v2/stocks" "AAPL" --start 2026-01-01 --feed sip')
assert_contains "bars URL contains feed=sip" "feed=sip" "$captured"

# Test: --currency USD appears in URL
captured=$(run_with_mock_curl '_data_bars "/v2/stocks" "AAPL" --start 2026-01-01 --currency USD')
assert_contains "bars URL contains currency=USD" "currency=USD" "$captured"

# Test: both --feed and --currency together
captured=$(run_with_mock_curl '_data_trades "/v2/stocks" "MSFT" --start 2026-01-01 --feed sip --currency USD')
assert_contains "trades URL contains feed=sip" "feed=sip" "$captured"
assert_contains "trades URL contains currency=USD" "currency=USD" "$captured"

# =====================================================================
# --start validation tests
# =====================================================================

# Test: _data_bars without --start exits 1
assert_exit_code "bars without --start exits 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"${DATA_LIB_PATH}"'"; _data_bars "/v2/stocks" "AAPL"'

# Test: _data_trades without --start exits 1
assert_exit_code "trades without --start exits 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"${DATA_LIB_PATH}"'"; _data_trades "/v2/stocks" "AAPL"'

# Test: _data_quotes without --start exits 1
assert_exit_code "quotes without --start exits 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"${DATA_LIB_PATH}"'"; _data_quotes "/v2/stocks" "AAPL"'

# =====================================================================
# Crypto symbol encoding tests
# =====================================================================

# Test: BTC/USD is URL-encoded in path as BTC%2FUSD
captured=$(run_with_mock_curl '_data_bars "/v1beta3/crypto/us" "BTC/USD" --start 2026-01-01')
assert_contains "crypto bars URL encodes slash" "BTC%2FUSD" "$captured"
assert_contains "crypto bars URL has correct base path" "/v1beta3/crypto/us/" "$captured"

# Test: crypto trades also encode symbol
captured=$(run_with_mock_curl '_data_trades "/v1beta3/crypto/us" "ETH/USD" --start 2026-01-01')
assert_contains "crypto trades URL encodes slash" "ETH%2FUSD" "$captured"

# =====================================================================
# _data_snapshot URL construction tests
# =====================================================================

captured=$(run_with_mock_curl '_data_snapshot "/v2/stocks" "AAPL" --feed sip')
assert_contains "snapshot URL contains /AAPL/snapshot" "/v2/stocks/AAPL/snapshot" "$captured"
assert_contains "snapshot URL contains feed=sip" "feed=sip" "$captured"

# =====================================================================
# _data_snapshots URL construction tests
# =====================================================================

captured=$(run_with_mock_curl '_data_snapshots "/v2/stocks" "AAPL,TSLA" --feed sip')
assert_contains "snapshots URL contains /snapshots" "/v2/stocks/snapshots?" "$captured"
assert_contains "snapshots URL contains symbols param" "symbols=AAPL" "$captured"

# =====================================================================
# _data_latest_* URL construction tests
# =====================================================================

captured=$(run_with_mock_curl '_data_latest_trade "/v2/stocks" "AAPL"')
assert_contains "latest trade URL" "/v2/stocks/AAPL/trades/latest" "$captured"

captured=$(run_with_mock_curl '_data_latest_quote "/v2/stocks" "AAPL"')
assert_contains "latest quote URL" "/v2/stocks/AAPL/quotes/latest" "$captured"

captured=$(run_with_mock_curl '_data_latest_bar "/v2/stocks" "AAPL"')
assert_contains "latest bar URL" "/v2/stocks/AAPL/bars/latest" "$captured"

# =====================================================================
# _data_quotes URL construction tests
# =====================================================================

captured=$(run_with_mock_curl '_data_quotes "/v2/stocks" "AAPL" --start 2026-01-01 --end 2026-01-31 --feed sip')
assert_contains "quotes URL contains /AAPL/quotes" "/v2/stocks/AAPL/quotes?" "$captured"
assert_contains "quotes URL contains start param" "start=2026-01-01" "$captured"
assert_contains "quotes URL contains feed param" "feed=sip" "$captured"

# =====================================================================
# Plain symbol (no slash) is NOT encoded
# =====================================================================

captured=$(run_with_mock_curl '_data_bars "/v2/stocks" "AAPL" --start 2026-01-01')
assert_contains "stock symbol not encoded" "/v2/stocks/AAPL/bars?" "$captured"

# =====================================================================
# Summary
# =====================================================================

echo ""
echo "test_data_lib.sh Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailed tests:\n${ERRORS}"
  exit 1
fi
exit 0
