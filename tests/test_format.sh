#!/usr/bin/env bash
# tests/test_format.sh — Tests for scripts/alpaca_format.sh
# Self-contained, runnable via: bash tests/test_format.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly FORMAT_PATH="${SCRIPT_DIR}/../scripts/alpaca_format.sh"

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

assert_line_count() {
  local test_name="$1"
  local expected="$2"
  local output="$3"
  local actual
  actual=$(echo "$output" | wc -l)
  actual=$((actual + 0))  # trim whitespace
  if [[ "$actual" -eq "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}: expected ${expected} lines, got ${actual}\n"
    echo "  FAIL  ${test_name}: expected ${expected} lines, got ${actual}" >&2
  fi
}

echo "=== test_format.sh ==="

# =====================================================================
# Key-value shape: account --format summary
# =====================================================================

output=$(echo '{"equity":"50000","cash":"25000","buying_power":"50000","portfolio_value":"50000"}' \
  | bash "$FORMAT_PATH" --type account --format summary)
assert_contains "account summary has equity label" "Equity" "$output"
assert_contains "account summary has equity value" "50000" "$output"
assert_contains "account summary has cash" "Cash" "$output"
assert_contains "account summary has buying_power" "Buying Power" "$output"

# =====================================================================
# Key-value shape: clock --format summary
# =====================================================================

output=$(echo '{"is_open":true,"timestamp":"2026-03-17T10:30:00-04:00","next_open":"2026-03-18T09:30:00-04:00","next_close":"2026-03-17T16:00:00-04:00"}' \
  | bash "$FORMAT_PATH" --type clock --format summary)
assert_contains "clock summary has is_open" "is_open" "$output"
assert_contains "clock summary has true" "true" "$output"
assert_contains "clock summary has next_open" "next_open" "$output"

# =====================================================================
# Table shape: orders --format summary
# =====================================================================

output=$(echo '[{"symbol":"AAPL","side":"buy","type":"market","qty":"10","filled_qty":"10","status":"filled","submitted_at":"2026-03-17T10:00:00Z"}]' \
  | bash "$FORMAT_PATH" --type orders --format summary)
assert_contains "orders summary has AAPL" "AAPL" "$output"
assert_contains "orders summary has buy" "buy" "$output"
assert_contains "orders summary has SYMBOL header" "SYMBOL" "$output"

# =====================================================================
# Table shape: positions --format summary
# =====================================================================

output=$(echo '[{"symbol":"AAPL","qty":"10","avg_entry_price":"180.00","current_price":"185.00","unrealized_pl":"50.00","unrealized_plpc":"0.0278"}]' \
  | bash "$FORMAT_PATH" --type positions --format summary)
assert_contains "positions summary has AAPL" "AAPL" "$output"
assert_contains "positions summary has entry price" "180.00" "$output"
assert_contains "positions summary has SYMBOL header" "SYMBOL" "$output"

# =====================================================================
# OHLCV shape: bars --format csv
# =====================================================================

output=$(echo '{"bars":[{"t":"2026-03-17T00:00:00Z","o":180.0,"h":185.0,"l":179.0,"c":184.0,"v":1000000}]}' \
  | bash "$FORMAT_PATH" --type bars --format csv)
line1=$(echo "$output" | head -n 1)
line2=$(echo "$output" | sed -n '2p')
assert_contains "bars csv header" "date" "$line1"
assert_contains "bars csv header has open" "open" "$line1"
assert_contains "bars csv data has 180" "180" "$line2"

# =====================================================================
# Ranked list: movers --format summary
# =====================================================================

output=$(echo '{"gainers":[{"symbol":"TSLA","percent_change":5.2,"price":250.0}],"losers":[{"symbol":"META","percent_change":-3.1,"price":480.0}]}' \
  | bash "$FORMAT_PATH" --type movers --format summary)
assert_contains "movers summary has TSLA" "TSLA" "$output"
assert_contains "movers summary has 5.2" "5.2" "$output"
assert_contains "movers summary has Gainers section" "Gainers" "$output"
assert_contains "movers summary has Losers section" "Losers" "$output"
assert_contains "movers summary has META" "META" "$output"

# =====================================================================
# News: news --format summary
# =====================================================================

output=$(echo '{"news":[{"headline":"Apple earnings beat","source":"Reuters","created_at":"2026-03-17","symbols":["AAPL"]}]}' \
  | bash "$FORMAT_PATH" --type news --format summary)
assert_contains "news summary has headline" "Apple earnings" "$output"
assert_contains "news summary has source" "Reuters" "$output"
assert_contains "news summary has AAPL" "AAPL" "$output"

# =====================================================================
# Full format: account --format full (pretty JSON passthrough)
# =====================================================================

output=$(echo '{"equity":"50000","cash":"25000"}' \
  | bash "$FORMAT_PATH" --type account --format full)
assert_contains "full format has equity" "equity" "$output"
assert_contains "full format has 50000" "50000" "$output"
# Full format should be pretty-printed (multi-line)
line_count=$(echo "$output" | wc -l)
if [[ "$line_count" -gt 1 ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}  FAIL  full format should be multi-line\n"
  echo "  FAIL  full format should be multi-line" >&2
fi

# =====================================================================
# Top limit: --top 1 on a 3-item array
# =====================================================================

output=$(echo '[{"symbol":"AAPL","side":"buy","type":"market","qty":"10","status":"filled","submitted_at":"2026-03-17T10:00:00Z"},{"symbol":"TSLA","side":"sell","type":"limit","qty":"5","status":"open","submitted_at":"2026-03-17T11:00:00Z"},{"symbol":"GOOG","side":"buy","type":"market","qty":"3","status":"filled","submitted_at":"2026-03-17T12:00:00Z"}]' \
  | bash "$FORMAT_PATH" --type orders --format summary --top 1)
assert_contains "top 1 has AAPL" "AAPL" "$output"
# TSLA and GOOG should not appear in data rows
# Count actual data lines (excluding header/separator lines)
data_lines=$(echo "$output" | tail -n +3)  # skip header + separator
data_count=$(echo "$data_lines" | grep -c 'AAPL\|TSLA\|GOOG' || true)
if [[ "$data_count" -eq 1 ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  ERRORS="${ERRORS}  FAIL  top 1 should show only 1 data row, got ${data_count}\n"
  echo "  FAIL  top 1 should show only 1 data row, got ${data_count}" >&2
fi

# =====================================================================
# Error case: invalid type
# =====================================================================

assert_exit_code "invalid type exits 1" 1 \
  bash -c 'echo "{}" | bash "'"$FORMAT_PATH"'" --type bogus'

# =====================================================================
# Error case: no input (stdin is terminal)
# =====================================================================

# When piping empty string, it should fail on JSON validation
assert_exit_code "no input exits 1" 1 \
  bash -c 'echo "" | bash "'"$FORMAT_PATH"'" --type account'

# =====================================================================
# Summary
# =====================================================================

echo ""
echo "test_format.sh Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailed tests:\n${ERRORS}"
  exit 1
fi
exit 0
