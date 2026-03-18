#!/usr/bin/env bash
# tests/test_lib.sh — Tests for scripts/_lib.sh
# Self-contained, runnable via: bash tests/test_lib.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly LIB_PATH="${SCRIPT_DIR}/../scripts/_lib.sh"

PASS=0
FAIL=0
ERRORS=""

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

assert_exit_code() {
  local test_name="$1"
  local expected_code="$2"
  shift 2
  # Run in subshell, capture exit code
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

# Helper to source _lib.sh in a subshell with mock env
source_lib() {
  export APCA_API_KEY_ID="test-key-id"
  export APCA_API_SECRET_KEY="test-secret-key"
  # shellcheck disable=SC1090
  source "$LIB_PATH"
}

echo "=== test_lib.sh ==="

# =====================================================================
# _require_api_key tests
# =====================================================================

# Arrange: no API key set
# Act + Assert: should exit 1
assert_exit_code "_require_api_key exits 1 when APCA_API_KEY_ID missing" 1 \
  bash -c 'unset APCA_API_KEY_ID; unset APCA_API_SECRET_KEY; source "'"$LIB_PATH"'"'

# Arrange: key ID set but secret missing
# Act + Assert: should exit 1
assert_exit_code "_require_api_key exits 1 when APCA_API_SECRET_KEY missing" 1 \
  bash -c 'export APCA_API_KEY_ID=test; unset APCA_API_SECRET_KEY; source "'"$LIB_PATH"'"'

# Arrange: both set
# Act + Assert: should exit 0 (sourcing succeeds)
assert_exit_code "_require_api_key succeeds when both keys set" 0 \
  bash -c 'export APCA_API_KEY_ID=test; export APCA_API_SECRET_KEY=secret; source "'"$LIB_PATH"'"'

# Verify error message content for missing key
error_output=$(bash -c 'unset APCA_API_KEY_ID; unset APCA_API_SECRET_KEY; unset APCA_PAPER_KEY; unset APCA_REAL_KEY; source "'"$LIB_PATH"'"' 2>&1 || true)
assert_contains "_require_api_key error mentions API key" "API key" "$error_output"

# Verify error message content for missing secret
error_output=$(bash -c 'export APCA_API_KEY_ID=test; unset APCA_API_SECRET_KEY; unset APCA_PAPER_SECRET_KEY; unset APCA_REAL_SECRET_KEY; source "'"$LIB_PATH"'"' 2>&1 || true)
assert_contains "_require_api_key error mentions API secret" "API secret" "$error_output"

# Verify paper key resolution: APCA_PAPER_KEY takes priority over APCA_API_KEY_ID
resolved_key=$(bash -c 'export APCA_PAPER_KEY=paper-key; export APCA_PAPER_SECRET_KEY=paper-secret; export APCA_API_KEY_ID=fallback; export APCA_API_SECRET_KEY=fallback-secret; export APCA_PAPER=true; source "'"$LIB_PATH"'"; echo "$APCA_API_KEY_ID"')
assert_eq "APCA_PAPER_KEY resolves to APCA_API_KEY_ID in paper mode" "paper-key" "$resolved_key"

# Verify live key resolution: APCA_REAL_KEY takes priority
resolved_key=$(bash -c 'export APCA_REAL_KEY=real-key; export APCA_REAL_SECRET_KEY=real-secret; export APCA_API_KEY_ID=fallback; export APCA_API_SECRET_KEY=fallback-secret; export APCA_PAPER=false; source "'"$LIB_PATH"'"; echo "$APCA_API_KEY_ID"')
assert_eq "APCA_REAL_KEY resolves to APCA_API_KEY_ID in live mode" "real-key" "$resolved_key"

# Verify fallback: APCA_API_KEY_ID used when mode-specific not set
resolved_key=$(bash -c 'unset APCA_PAPER_KEY; unset APCA_REAL_KEY; export APCA_API_KEY_ID=fallback-key; export APCA_API_SECRET_KEY=fallback-secret; export APCA_PAPER=true; source "'"$LIB_PATH"'"; echo "$APCA_API_KEY_ID"')
assert_eq "Falls back to APCA_API_KEY_ID when APCA_PAPER_KEY not set" "fallback-key" "$resolved_key"

# =====================================================================
# _build_url tests
# =====================================================================

# Source lib for remaining tests (sets mock env)
source_lib

# Arrange: base + path, no params
# Act
result=$(_build_url "https://example.com" "/v2/account")
# Assert
assert_eq "_build_url base+path" "https://example.com/v2/account" "$result"

# Arrange: base + path + single query param
# Act
result=$(_build_url "https://example.com" "/v2/orders" "status=open")
# Assert
assert_eq "_build_url with one param" "https://example.com/v2/orders?status=open" "$result"

# Arrange: base + path + multiple params
# Act
result=$(_build_url "https://example.com" "/v2/orders" "status=open" "limit=50")
# Assert
assert_eq "_build_url with two params" "https://example.com/v2/orders?status=open&limit=50" "$result"

# Arrange: param with empty value should be skipped
# Act
result=$(_build_url "https://example.com" "/v2/orders" "status=open" "after=" "limit=10")
# Assert
assert_eq "_build_url skips empty values" "https://example.com/v2/orders?status=open&limit=10" "$result"

# Arrange: no params at all
# Act
result=$(_build_url "$LIB_TRADING_URL" "/v2/account")
# Assert
assert_eq "_build_url with LIB_TRADING_URL" "https://paper-api.alpaca.markets/v2/account" "$result"

# Arrange: param with no = separator should be skipped
# Act
result=$(_build_url "https://example.com" "/v2/test" "invalid_param" "status=open")
# Assert
assert_eq "_build_url skips params without =" "https://example.com/v2/test?status=open" "$result"

# =====================================================================
# _urlencode tests
# =====================================================================

# Arrange: plain string
# Act + Assert
assert_eq "_urlencode plain" "hello" "$(_urlencode "hello")"

# Arrange: string with spaces
# Act + Assert
assert_eq "_urlencode spaces" "hello+world" "$(_urlencode "hello world")"

# Arrange: string with slash
# Act + Assert
assert_eq "_urlencode slash" "BTC%2FUSD" "$(_urlencode "BTC/USD")"

# Arrange: alphanumeric with safe chars
# Act + Assert
assert_eq "_urlencode safe chars" "test.value_1-2~3" "$(_urlencode "test.value_1-2~3")"

# Arrange: string with special characters
# Act + Assert
result=$(_urlencode "a&b=c")
assert_contains "_urlencode ampersand" "%26" "$result"
assert_contains "_urlencode equals" "%3D" "$result"

# =====================================================================
# _parse_flag tests
# =====================================================================

# Arrange: flag present with value
# Act + Assert
assert_eq "_parse_flag found" "50" "$(_parse_flag "--limit" "--status" "open" "--limit" "50")"

# Arrange: flag not present
# Act + Assert
assert_eq "_parse_flag not found" "" "$(_parse_flag "--missing" "--status" "open" "--limit" "50")"

# Arrange: flag is last arg (no value after it)
# Act + Assert
assert_eq "_parse_flag at end" "" "$(_parse_flag "--limit" "--status" "open" "--limit")"

# Arrange: flag present, first in args
# Act + Assert
assert_eq "_parse_flag first arg" "active" "$(_parse_flag "--status" "--status" "active")"

# =====================================================================
# _has_flag tests
# =====================================================================

# Arrange: flag present
# Act + Assert
if _has_flag "--verbose" "--verbose" "--limit" "50"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}  FAIL  _has_flag found\n"
  echo "  FAIL  _has_flag found" >&2
fi

# Arrange: flag not present
# Act + Assert
if _has_flag "--verbose" "--limit" "50"; then
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}  FAIL  _has_flag not found\n"
  echo "  FAIL  _has_flag not found" >&2
else
  PASS=$((PASS + 1))
fi

# Arrange: flag as value of another flag should still match
# Act + Assert
if _has_flag "--limit" "--status" "--limit"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}  FAIL  _has_flag as value\n"
  echo "  FAIL  _has_flag as value" >&2
fi

# =====================================================================
# _require_arg tests
# =====================================================================

# Arrange: value provided
# Act + Assert
assert_exit_code "_require_arg with value succeeds" 0 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _require_arg "symbol" "AAPL" "get"'

# Arrange: value empty
# Act + Assert
assert_exit_code "_require_arg with empty exits 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _require_arg "symbol" "" "get"'

# Verify error message content
error_output=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _require_arg "symbol" "" "get"' 2>&1 || true)
assert_contains "_require_arg error mentions arg name" "symbol" "$error_output"
assert_contains "_require_arg error mentions command" "get" "$error_output"

# =====================================================================
# _check_http_status tests
# =====================================================================

# Arrange: HTTP 200
# Act + Assert
assert_exit_code "_check_http_status 200 returns 0" 0 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 200 "{}" "test"'

# Arrange: HTTP 201
# Act + Assert
assert_exit_code "_check_http_status 201 returns 0" 0 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 201 "{}" "test"'

# Arrange: HTTP 204
# Act + Assert
assert_exit_code "_check_http_status 204 returns 0" 0 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 204 "" "test"'

# Arrange: HTTP 207 (multi-status for bulk ops)
# Act + Assert
assert_exit_code "_check_http_status 207 returns 0" 0 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 207 "[]" "test"'

# Arrange: HTTP 400
# Act + Assert
assert_exit_code "_check_http_status 400 returns 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 400 "{\"message\":\"bad request\"}" "test"'

# Verify 400 extracts message
error_output=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 400 "{\"message\":\"invalid symbol\"}" "order"' 2>&1 || true)
assert_contains "_check_http_status 400 extracts message" "invalid symbol" "$error_output"

# Arrange: HTTP 403
# Act + Assert
assert_exit_code "_check_http_status 403 returns 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 403 "{}" "test"'

# Verify 403 mentions API key
error_output=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 403 "{}" "test"' 2>&1 || true)
assert_contains "_check_http_status 403 mentions permissions" "Check API key and permissions" "$error_output"

# Arrange: HTTP 404
# Act + Assert
assert_exit_code "_check_http_status 404 returns 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 404 "{}" "test"'

error_output=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 404 "{}" "test"' 2>&1 || true)
assert_contains "_check_http_status 404 message" "Resource not found" "$error_output"

# Arrange: HTTP 422 (common for invalid orders)
# Act + Assert
assert_exit_code "_check_http_status 422 returns 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 422 "{\"message\":\"insufficient qty\"}" "test"'

error_output=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 422 "{\"message\":\"insufficient qty\"}" "order"' 2>&1 || true)
assert_contains "_check_http_status 422 extracts message" "insufficient qty" "$error_output"

# Arrange: HTTP 429
# Act + Assert
assert_exit_code "_check_http_status 429 returns 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 429 "{}" "test"'

error_output=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 429 "{}" "test"' 2>&1 || true)
assert_contains "_check_http_status 429 message" "Rate limit exceeded" "$error_output"

# Arrange: HTTP 500 (server error)
# Act + Assert
assert_exit_code "_check_http_status 500 returns 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 500 "{}" "test"'

error_output=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status 500 "{}" "test"' 2>&1 || true)
assert_contains "_check_http_status 500 message" "Alpaca API error" "$error_output"

# Arrange: invalid (non-numeric) HTTP code
# Act + Assert
assert_exit_code "_check_http_status invalid code returns 1" 1 \
  bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; _check_http_status "abc" "{}" "test"'

# =====================================================================
# LIB_TRADING_URL resolution tests
# =====================================================================

# Arrange: APCA_PAPER=true (default)
# Act
trading_url=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; export APCA_PAPER=true; source "'"$LIB_PATH"'"; echo "$LIB_TRADING_URL"')
# Assert
assert_eq "LIB_TRADING_URL paper" "https://paper-api.alpaca.markets" "$trading_url"

# Arrange: APCA_PAPER=false
# Act
trading_url=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; export APCA_PAPER=false; source "'"$LIB_PATH"'"; echo "$LIB_TRADING_URL"')
# Assert
assert_eq "LIB_TRADING_URL live" "https://api.alpaca.markets" "$trading_url"

# Arrange: APCA_PAPER unset (defaults to paper)
# Act
trading_url=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; unset APCA_PAPER; source "'"$LIB_PATH"'"; echo "$LIB_TRADING_URL"')
# Assert
assert_eq "LIB_TRADING_URL default paper" "https://paper-api.alpaca.markets" "$trading_url"

# =====================================================================
# Constants tests
# =====================================================================

data_url=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; echo "$LIB_DATA_URL"')
assert_eq "LIB_DATA_URL" "https://data.alpaca.markets" "$data_url"

max_pages=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; echo "$LIB_MAX_PAGES"')
assert_eq "LIB_MAX_PAGES" "10" "$max_pages"

timeout_val=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; echo "$HTTP_TIMEOUT"')
assert_eq "HTTP_TIMEOUT default" "15" "$timeout_val"

timeout_custom=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; export APCA_TIMEOUT=30; source "'"$LIB_PATH"'"; echo "$HTTP_TIMEOUT"')
assert_eq "HTTP_TIMEOUT custom" "30" "$timeout_custom"

# =====================================================================
# _strip_mode_flags tests
# =====================================================================

# Strip --live from middle of args
stripped=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; eval set -- "$(_strip_mode_flags "--status" "open" "--live" "--limit" "50")"; echo "$*"')
assert_eq "_strip_mode_flags removes --live" "open 50" "$(echo "$stripped" | sed 's/--status //;s/--limit //')"

# Strip --paper from args
stripped=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; eval set -- "$(_strip_mode_flags "--paper" "--status" "open")"; echo "$#:$*"')
assert_contains "_strip_mode_flags removes --paper" "open" "$stripped"

# No args produces zero args
arg_count=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; eval set -- "$(_strip_mode_flags)"; echo "$#"')
assert_eq "_strip_mode_flags no args" "0" "$arg_count"

# Only --live produces zero args
arg_count=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; eval set -- "$(_strip_mode_flags "--live")"; echo "$#"')
assert_eq "_strip_mode_flags only --live" "0" "$arg_count"

# Args with spaces preserved
stripped=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; source "'"$LIB_PATH"'"; eval set -- "$(_strip_mode_flags "hello world" "--live" "foo")"; echo "$1|$2"')
assert_eq "_strip_mode_flags preserves spaces" "hello world|foo" "$stripped"

# =====================================================================
# Mode resolution tests (--live/--paper flags + APCA_PAPER env)
# =====================================================================

# --live flag overrides APCA_PAPER=true
mode=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; export APCA_PAPER=true; LIB_CALLER_ARGS=("--live"); source "'"$LIB_PATH"'"; echo "$LIB_TRADING_MODE"')
assert_eq "--live flag overrides APCA_PAPER=true" "live" "$mode"

# --paper flag overrides APCA_PAPER=false
mode=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; export APCA_PAPER=false; LIB_CALLER_ARGS=("--paper"); source "'"$LIB_PATH"'"; echo "$LIB_TRADING_MODE"')
assert_eq "--paper flag overrides APCA_PAPER=false" "paper" "$mode"

# No flag falls back to APCA_PAPER=false
mode=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; export APCA_PAPER=false; LIB_CALLER_ARGS=("list"); source "'"$LIB_PATH"'"; echo "$LIB_TRADING_MODE"')
assert_eq "no flag falls back to APCA_PAPER=false" "live" "$mode"

# No flag, no env defaults to paper
mode=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; unset APCA_PAPER; LIB_CALLER_ARGS=("list"); source "'"$LIB_PATH"'"; echo "$LIB_TRADING_MODE"')
assert_eq "no flag no env defaults to paper" "paper" "$mode"

# --live resolves to live trading URL
url=$(bash -c 'export APCA_API_KEY_ID=k; export APCA_API_SECRET_KEY=s; LIB_CALLER_ARGS=("submit" "AAPL" "--live"); source "'"$LIB_PATH"'"; echo "$LIB_TRADING_URL"')
assert_eq "--live resolves to live URL" "https://api.alpaca.markets" "$url"

# --live uses APCA_REAL_KEY
key=$(bash -c 'export APCA_PAPER_KEY=paper; export APCA_PAPER_SECRET_KEY=ps; export APCA_REAL_KEY=real; export APCA_REAL_SECRET_KEY=rs; LIB_CALLER_ARGS=("--live"); source "'"$LIB_PATH"'"; echo "$APCA_API_KEY_ID"')
assert_eq "--live uses APCA_REAL_KEY" "real" "$key"

# =====================================================================
# Summary
# =====================================================================

echo ""
echo "test_lib.sh Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailed tests:\n${ERRORS}"
  exit 1
fi
exit 0
