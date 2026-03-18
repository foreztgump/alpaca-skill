#!/usr/bin/env bash
# scripts/alpaca_format.sh — Format JSON output from alpaca_* scripts for human-readable display
#
# This is a local formatter. It does NOT source _lib.sh and makes no API calls.
#
# Usage:
#   alpaca_account.sh get | alpaca_format.sh --type account
#   alpaca_format.sh --type news --format csv < news.json
#   alpaca_format.sh --type orders --top 10 results.json

set -euo pipefail

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
show_help() {
  cat >&2 <<'EOF'
alpaca_format.sh — Format JSON output from alpaca_* scripts

Usage:
  <command> | alpaca_format.sh --type <TYPE> [--format <FORMAT>] [--top N]
  alpaca_format.sh --type <TYPE> [--format <FORMAT>] [--top N] <file>

Types:
  account, activities, orders, positions, assets, bars, trades,
  quotes, snapshot, watchlists, calendar, clock, news, movers,
  options, option-chain, corporate-actions, orderbook

Formats:
  summary   Concise human-readable output (default)
  full      Pretty-printed JSON
  csv       Comma-separated values with header row

Options:
  --top N   Limit output to top N results
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
TYPE=""
FORMAT="summary"
TOP=""
INPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)    TYPE="$2";   shift 2 ;;
    --format)  FORMAT="$2"; shift 2 ;;
    --top)     TOP="$2";    shift 2 ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      echo "Error: unknown flag: $1" >&2
      exit 1
      ;;
    *)
      INPUT_FILE="$1"
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
VALID_TYPES="account activities orders positions assets bars trades quotes snapshot watchlists calendar clock news movers options option-chain corporate-actions orderbook"
if [[ -z "$TYPE" ]]; then
  echo "Error: --type is required." >&2
  show_help
  exit 1
fi

type_valid=false
for vt in $VALID_TYPES; do
  if [[ "$vt" == "$TYPE" ]]; then
    type_valid=true
    break
  fi
done
if [[ "$type_valid" != "true" ]]; then
  echo "Error: invalid type '$TYPE'. Must be one of: $VALID_TYPES" >&2
  exit 1
fi

if [[ "$FORMAT" != "summary" && "$FORMAT" != "full" && "$FORMAT" != "csv" ]]; then
  echo "Error: invalid format '$FORMAT'. Must be summary, full, or csv." >&2
  exit 1
fi

if [[ -n "$TOP" ]] && ! [[ "$TOP" =~ ^[0-9]+$ ]]; then
  echo "Error: --top must be a positive integer." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read input (stdin or file)
# ---------------------------------------------------------------------------
if [[ -n "$INPUT_FILE" ]]; then
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: file not found: $INPUT_FILE" >&2
    exit 1
  fi
  INPUT=$(cat "$INPUT_FILE")
else
  if [[ -t 0 ]]; then
    echo "Error: no input. Pipe JSON or provide a file argument." >&2
    show_help
    exit 1
  fi
  INPUT=$(cat)
fi

# Check for empty input
if [[ -z "${INPUT// /}" ]]; then
  echo "Error: no input. Pipe JSON or provide a file argument." >&2
  show_help
  exit 1
fi

# Validate JSON
if ! echo "$INPUT" | jq empty 2>/dev/null; then
  echo "Error: input is not valid JSON." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

# _format_number <value>
# Format large numbers: 1000000 -> 1.0M, 1000 -> 1.0K
_format_number() {
  local val="$1"
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "N/A"
    return
  fi
  echo "$val" | awk '{
    v = $1 + 0
    if (v < 0) { sign = "-"; v = -v } else { sign = "" }
    if (v >= 1000000000000) printf "%s%.1fT\n", sign, v / 1000000000000
    else if (v >= 1000000000) printf "%s%.1fB\n", sign, v / 1000000000
    else if (v >= 1000000) printf "%s%.1fM\n", sign, v / 1000000
    else if (v >= 1000) printf "%s%.1fK\n", sign, v / 1000
    else printf "%s%.0f\n", sign, v
  }'
}

# _format_timestamp <ISO 8601 or Unix timestamp>
# Convert timestamps to human-readable date.
_format_timestamp() {
  local ts="$1"
  if [[ -z "$ts" || "$ts" == "null" ]]; then
    echo "N/A"
    return
  fi
  # If it looks like an ISO date string, extract the date/time portion
  if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2} ]]; then
    # Trim to YYYY-MM-DD HH:MM:SS if possible
    echo "$ts" | sed -E 's/T/ /; s/\.[0-9]+//; s/Z$//; s/[+-][0-9]{2}:[0-9]{2}$//'
    return
  fi
  # Unix seconds
  date -d "@${ts}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$ts"
}

# _format_price <value>
# Format price with $ and 2 decimal places
_format_price() {
  local val="$1"
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "N/A"
    return
  fi
  printf '$%.2f' "$val"
}

# _format_price_comma <value>
# Format price with $ and comma grouping and 2 decimal places
_format_price_comma() {
  local val="$1"
  if [[ -z "$val" || "$val" == "null" ]]; then
    echo "N/A"
    return
  fi
  printf '$%\047.2f' "$val"
}

# ---------------------------------------------------------------------------
# Extract results array from various Alpaca API response shapes
# ---------------------------------------------------------------------------
_extract_results() {
  local json="$1"
  echo "$json" | jq '
    if (. | type) == "array" then .
    elif (. | type) == "object" then
      if (.bars | type) == "array" then .bars
      elif (.news | type) == "array" then .news
      elif (.trades | type) == "array" then .trades
      elif (.quotes | type) == "array" then .quotes
      elif (.activities | type) == "array" then .activities
      elif (.assets | type) == "array" then .assets
      elif (.orders | type) == "array" then .orders
      elif (.positions | type) == "array" then .positions
      elif (.watchlists | type) == "array" then .watchlists
      elif (.results | type) == "array" then .results
      elif (.gainers | type) == "array" or (.losers | type) == "array" then .
      else [.]
      end
    else [.]
    end
  ' 2>/dev/null
}

# Apply --top limit to a JSON array
_apply_top() {
  local json_array="$1"
  if [[ -n "$TOP" ]]; then
    echo "$json_array" | jq "if (. | type) == \"array\" then .[0:${TOP}] else . end"
  else
    echo "$json_array"
  fi
}

# ---------------------------------------------------------------------------
# Full format — just pretty-print the JSON
# ---------------------------------------------------------------------------
if [[ "$FORMAT" == "full" ]]; then
  if [[ -n "$TOP" ]]; then
    RESULTS=$(_extract_results "$INPUT")
    RESULTS=$(_apply_top "$RESULTS")
    echo "$RESULTS" | jq '.'
  else
    echo "$INPUT" | jq '.'
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Formatting: account (key-value)
# ---------------------------------------------------------------------------
_format_account_summary() {
  local items="$1"
  echo "$items" | jq -r '
    .[0] // . |
    "Equity:          " + (.equity // "N/A" | tostring),
    "Cash:            " + (.cash // "N/A" | tostring),
    "Buying Power:    " + (.buying_power // "N/A" | tostring),
    "Portfolio Value: " + (.portfolio_value // "N/A" | tostring)
  '
}

_format_account_csv() {
  local items="$1"
  echo "key,value"
  echo "$items" | jq -r '
    .[0] // . |
    to_entries[] | [.key, (.value | tostring)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: clock (key-value)
# ---------------------------------------------------------------------------
_format_clock_summary() {
  local items="$1"
  echo "$items" | jq -r '
    .[0] // . |
    "is_open:    " + (.is_open | tostring),
    "timestamp:  " + (.timestamp // "N/A" | tostring),
    "next_open:  " + (.next_open // "N/A" | tostring),
    "next_close: " + (.next_close // "N/A" | tostring)
  '
}

_format_clock_csv() {
  local items="$1"
  echo "key,value"
  echo "$items" | jq -r '
    .[0] // . |
    to_entries[] | [.key, (.value | tostring)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: orders (table)
# ---------------------------------------------------------------------------
_format_orders_summary() {
  local items="$1"
  printf '%-8s  %-6s  %-10s  %8s  %-10s  %s\n' "SYMBOL" "SIDE" "TYPE" "QTY" "STATUS" "SUBMITTED"
  printf '%-8s  %-6s  %-10s  %8s  %-10s  %s\n' "------" "----" "----" "---" "------" "---------"
  echo "$items" | jq -r '
    .[] |
    (.symbol // "N/A") as $sym |
    (.side // "N/A") as $side |
    (.type // "N/A") as $type |
    (.qty // .filled_qty // "N/A" | tostring) as $qty |
    (.status // "N/A") as $status |
    (.submitted_at // .created_at // "N/A" | tostring) as $submitted |
    [$sym, $side, $type, $qty, $status, $submitted] | @tsv
  ' | while IFS=$'\t' read -r sym side type_val qty status submitted; do
    local tsFmt
    tsFmt=$(_format_timestamp "$submitted")
    printf '%-8s  %-6s  %-10s  %8s  %-10s  %s\n' "$sym" "$side" "$type_val" "$qty" "$status" "$tsFmt"
  done
}

_format_orders_csv() {
  local items="$1"
  echo "symbol,side,type,qty,status,submitted_at"
  echo "$items" | jq -r '
    .[] |
    [(.symbol // ""), (.side // ""), (.type // ""),
     (.qty // .filled_qty // "" | tostring), (.status // ""),
     (.submitted_at // .created_at // "" | tostring)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: positions (table)
# ---------------------------------------------------------------------------
_format_positions_summary() {
  local items="$1"
  printf '%-8s  %8s  %10s  %10s  %10s  %8s\n' "SYMBOL" "QTY" "ENTRY" "CURRENT" "P&L" "P&L%"
  printf '%-8s  %8s  %10s  %10s  %10s  %8s\n' "------" "---" "-----" "-------" "---" "----"
  echo "$items" | jq -r '
    .[] |
    (.symbol // "N/A") as $sym |
    (.qty // "N/A" | tostring) as $qty |
    (.avg_entry_price // "N/A" | tostring) as $entry |
    (.current_price // "N/A" | tostring) as $current |
    (.unrealized_pl // "N/A" | tostring) as $pl |
    (.unrealized_plpc // "N/A" | tostring) as $plpc |
    [$sym, $qty, $entry, $current, $pl, $plpc] | @tsv
  ' | while IFS=$'\t' read -r sym qty entry current pl plpc; do
    local entryFmt currentFmt plFmt plpcFmt
    entryFmt=$(_format_price "$entry")
    currentFmt=$(_format_price "$current")
    plFmt=$(_format_price "$pl")
    if [[ "$plpc" != "N/A" && "$plpc" != "null" && -n "$plpc" ]]; then
      plpcFmt=$(awk -v v="$plpc" 'BEGIN { printf "%.2f%%", v * 100 }')
    else
      plpcFmt="N/A"
    fi
    printf '%-8s  %8s  %10s  %10s  %10s  %8s\n' "$sym" "$qty" "$entryFmt" "$currentFmt" "$plFmt" "$plpcFmt"
  done
}

_format_positions_csv() {
  local items="$1"
  echo "symbol,qty,avg_entry_price,current_price,unrealized_pl,unrealized_plpc"
  echo "$items" | jq -r '
    .[] |
    [(.symbol // ""), (.qty // "" | tostring), (.avg_entry_price // "" | tostring),
     (.current_price // "" | tostring), (.unrealized_pl // "" | tostring),
     (.unrealized_plpc // "" | tostring)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: bars / aggregates (OHLCV)
# ---------------------------------------------------------------------------
_format_bars_summary() {
  local items="$1"
  printf '%-22s  %10s  %10s  %10s  %10s  %10s\n' "DATE" "OPEN" "HIGH" "LOW" "CLOSE" "VOLUME"
  printf '%-22s  %10s  %10s  %10s  %10s  %10s\n' "----" "----" "----" "---" "-----" "------"
  echo "$items" | jq -r '
    .[] |
    (.t // .timestamp // "N/A" | tostring) as $ts |
    (.o // .open // null) as $open |
    (.h // .high // null) as $high |
    (.l // .low // null) as $low |
    (.c // .close // null) as $close |
    (.v // .volume // null) as $vol |
    [$ts, ($open // "" | tostring), ($high // "" | tostring), ($low // "" | tostring), ($close // "" | tostring), ($vol // "" | tostring)] | @tsv
  ' | while IFS=$'\t' read -r ts open high low close vol; do
    local tsFmt openFmt highFmt lowFmt closeFmt volFmt
    tsFmt=$(_format_timestamp "$ts")
    openFmt=$(_format_price "$open")
    highFmt=$(_format_price "$high")
    lowFmt=$(_format_price "$low")
    closeFmt=$(_format_price "$close")
    volFmt=$(_format_number "$vol")
    printf '%-22s  %10s  %10s  %10s  %10s  %10s\n' "$tsFmt" "$openFmt" "$highFmt" "$lowFmt" "$closeFmt" "$volFmt"
  done
}

_format_bars_csv() {
  local items="$1"
  echo "date,open,high,low,close,volume"
  echo "$items" | jq -r '
    .[] |
    (.t // .timestamp // "" | tostring) as $ts |
    (.o // .open // "" | tostring) as $open |
    (.h // .high // "" | tostring) as $high |
    (.l // .low // "" | tostring) as $low |
    (.c // .close // "" | tostring) as $close |
    (.v // .volume // "" | tostring) as $vol |
    [$ts, $open, $high, $low, $close, $vol] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: trades (table)
# ---------------------------------------------------------------------------
_format_trades_summary() {
  local items="$1"
  printf '%-22s  %10s  %8s\n' "TIMESTAMP" "PRICE" "SIZE"
  printf '%-22s  %10s  %8s\n' "---------" "-----" "----"
  echo "$items" | jq -r '
    .[] |
    (.t // .timestamp // "N/A" | tostring) as $ts |
    (.p // .price // null) as $price |
    (.s // .size // null) as $size |
    [$ts, ($price // "" | tostring), ($size // "" | tostring)] | @tsv
  ' | while IFS=$'\t' read -r ts price size; do
    local tsFmt priceFmt
    tsFmt=$(_format_timestamp "$ts")
    priceFmt=$(_format_price "$price")
    printf '%-22s  %10s  %8s\n' "$tsFmt" "$priceFmt" "$size"
  done
}

_format_trades_csv() {
  local items="$1"
  echo "timestamp,price,size"
  echo "$items" | jq -r '
    .[] |
    (.t // .timestamp // "" | tostring) as $ts |
    (.p // .price // "" | tostring) as $price |
    (.s // .size // "" | tostring) as $size |
    [$ts, $price, $size] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: quotes (table)
# ---------------------------------------------------------------------------
_format_quotes_summary() {
  local items="$1"
  printf '%-22s  %10s  %8s  %10s  %8s\n' "TIMESTAMP" "BID" "BID_SZ" "ASK" "ASK_SZ"
  printf '%-22s  %10s  %8s  %10s  %8s\n' "---------" "---" "------" "---" "------"
  echo "$items" | jq -r '
    .[] |
    (.t // .timestamp // "N/A" | tostring) as $ts |
    (.bp // .bid_price // null) as $bid |
    (.bs // .bid_size // null) as $bidSz |
    (.ap // .ask_price // null) as $ask |
    (.as // .ask_size // null) as $askSz |
    [$ts, ($bid // "" | tostring), ($bidSz // "" | tostring), ($ask // "" | tostring), ($askSz // "" | tostring)] | @tsv
  ' | while IFS=$'\t' read -r ts bid bidSz ask askSz; do
    local tsFmt bidFmt askFmt
    tsFmt=$(_format_timestamp "$ts")
    bidFmt=$(_format_price "$bid")
    askFmt=$(_format_price "$ask")
    printf '%-22s  %10s  %8s  %10s  %8s\n' "$tsFmt" "$bidFmt" "$bidSz" "$askFmt" "$askSz"
  done
}

_format_quotes_csv() {
  local items="$1"
  echo "timestamp,bid,bid_size,ask,ask_size"
  echo "$items" | jq -r '
    .[] |
    (.t // .timestamp // "" | tostring) as $ts |
    (.bp // .bid_price // "" | tostring) as $bid |
    (.bs // .bid_size // "" | tostring) as $bidSz |
    (.ap // .ask_price // "" | tostring) as $ask |
    (.as // .ask_size // "" | tostring) as $askSz |
    [$ts, $bid, $bidSz, $ask, $askSz] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: assets (table)
# ---------------------------------------------------------------------------
_format_assets_summary() {
  local items="$1"
  printf '%-8s  %-30s  %-10s  %-10s  %s\n' "SYMBOL" "NAME" "CLASS" "EXCHANGE" "TRADABLE"
  printf '%-8s  %-30s  %-10s  %-10s  %s\n' "------" "----" "-----" "--------" "--------"
  echo "$items" | jq -r '
    .[] |
    (.symbol // "N/A") as $sym |
    (.name // "N/A") as $name |
    (.class // "N/A") as $class |
    (.exchange // "N/A") as $exch |
    (if .tradable == true then "Yes"
     elif .tradable == false then "No"
     else "N/A" end) as $tradable |
    [$sym, $name, $class, $exch, $tradable] | @tsv
  ' | while IFS=$'\t' read -r sym name class_val exch tradable; do
    printf '%-8s  %-30s  %-10s  %-10s  %s\n' "$sym" "$name" "$class_val" "$exch" "$tradable"
  done
}

_format_assets_csv() {
  local items="$1"
  echo "symbol,name,class,exchange,tradable"
  echo "$items" | jq -r '
    .[] |
    [(.symbol // ""), (.name // ""), (.class // ""), (.exchange // ""),
     (if .tradable == true then "true" elif .tradable == false then "false" else "" end)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: watchlists (table)
# ---------------------------------------------------------------------------
_format_watchlists_summary() {
  local items="$1"
  printf '%-10s  %-20s  %s\n' "ID" "NAME" "SYMBOLS"
  printf '%-10s  %-20s  %s\n' "--" "----" "-------"
  echo "$items" | jq -r '
    .[] |
    (.id // "N/A" | tostring | .[0:8]) as $id |
    (.name // "N/A") as $name |
    (if .assets then (.assets | length | tostring) else "0" end) as $count |
    [$id, $name, $count] | @tsv
  ' | while IFS=$'\t' read -r id name count; do
    printf '%-10s  %-20s  %s\n' "$id" "$name" "$count"
  done
}

_format_watchlists_csv() {
  local items="$1"
  echo "id,name,symbol_count"
  echo "$items" | jq -r '
    .[] |
    [(.id // ""), (.name // ""),
     (if .assets then (.assets | length | tostring) else "0" end)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: calendar (table)
# ---------------------------------------------------------------------------
_format_calendar_summary() {
  local items="$1"
  printf '%-12s  %-10s  %s\n' "DATE" "OPEN" "CLOSE"
  printf '%-12s  %-10s  %s\n' "----" "----" "-----"
  echo "$items" | jq -r '
    .[] |
    (.date // "N/A") as $date |
    (.open // "N/A") as $open |
    (.close // "N/A") as $close |
    [$date, $open, $close] | @tsv
  ' | while IFS=$'\t' read -r dt open close; do
    printf '%-12s  %-10s  %s\n' "$dt" "$open" "$close"
  done
}

_format_calendar_csv() {
  local items="$1"
  echo "date,open,close"
  echo "$items" | jq -r '
    .[] |
    [(.date // ""), (.open // ""), (.close // "")] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: activities (table)
# ---------------------------------------------------------------------------
_format_activities_summary() {
  local items="$1"
  printf '%-22s  %-10s  %-8s  %8s  %10s\n' "DATE" "TYPE" "SYMBOL" "QTY" "PRICE"
  printf '%-22s  %-10s  %-8s  %8s  %10s\n' "----" "----" "------" "---" "-----"
  echo "$items" | jq -r '
    .[] |
    (.transaction_time // .date // "N/A" | tostring) as $date |
    (.activity_type // .type // "N/A") as $type |
    (.symbol // "N/A") as $sym |
    (.qty // "N/A" | tostring) as $qty |
    (.price // "N/A" | tostring) as $price |
    [$date, $type, $sym, $qty, $price] | @tsv
  ' | while IFS=$'\t' read -r dt type_val sym qty price; do
    local tsFmt priceFmt
    tsFmt=$(_format_timestamp "$dt")
    priceFmt=$(_format_price "$price")
    printf '%-22s  %-10s  %-8s  %8s  %10s\n' "$tsFmt" "$type_val" "$sym" "$qty" "$priceFmt"
  done
}

_format_activities_csv() {
  local items="$1"
  echo "date,type,symbol,qty,price"
  echo "$items" | jq -r '
    .[] |
    [(.transaction_time // .date // "" | tostring), (.activity_type // .type // ""),
     (.symbol // ""), (.qty // "" | tostring), (.price // "" | tostring)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: news
# ---------------------------------------------------------------------------
_format_news_summary() {
  local items="$1"
  echo "$items" | jq -r '
    .[] |
    (.headline // .title // "Untitled") as $headline |
    (.source // .author // "Unknown") as $source |
    (.created_at // .updated_at // "N/A" | tostring) as $date |
    (if .symbols then (.symbols | join(", "))
     elif .tickers then (.tickers | join(", "))
     else "N/A" end) as $symbols |
    [$headline, $source, $date, $symbols] | @tsv
  ' | while IFS=$'\t' read -r headline source dt symbols; do
    echo "---"
    echo "  $headline"
    echo "  Source: $source  |  Date: $dt"
    echo "  Symbols: $symbols"
  done
}

_format_news_csv() {
  local items="$1"
  echo "headline,source,date,symbols"
  echo "$items" | jq -r '
    .[] |
    (.headline // .title // "") as $headline |
    (.source // .author // "") as $source |
    (.created_at // .updated_at // "" | tostring) as $date |
    (if .symbols then (.symbols | join("; "))
     elif .tickers then (.tickers | join("; "))
     else "" end) as $symbols |
    [$headline, $source, $date, $symbols] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: movers (ranked list with gainers/losers sections)
# ---------------------------------------------------------------------------
_format_movers_summary() {
  local json="$1"
  local has_gainers has_losers
  has_gainers=$(echo "$json" | jq 'if (. | type) == "array" then false elif (.gainers | type) == "array" and (.gainers | length) > 0 then true else false end')
  has_losers=$(echo "$json" | jq 'if (. | type) == "array" then false elif (.losers | type) == "array" and (.losers | length) > 0 then true else false end')

  if [[ "$has_gainers" == "true" ]]; then
    echo "=== Gainers ==="
    local rank=0
    echo "$json" | jq -r '
      .gainers[] |
      (.symbol // "N/A") as $sym |
      (.percent_change // .change // 0 | tostring) as $pct |
      (.price // .last_price // 0 | tostring) as $price |
      [$sym, $pct, $price] | @tsv
    ' | while IFS=$'\t' read -r sym pct price; do
      rank=$((rank + 1))
      local priceFmt
      priceFmt=$(_format_price "$price")
      printf '%2d. %-8s  %8s%%  %10s\n' "$rank" "$sym" "$pct" "$priceFmt"
    done
  fi

  if [[ "$has_losers" == "true" ]]; then
    echo "=== Losers ==="
    local rank=0
    echo "$json" | jq -r '
      .losers[] |
      (.symbol // "N/A") as $sym |
      (.percent_change // .change // 0 | tostring) as $pct |
      (.price // .last_price // 0 | tostring) as $price |
      [$sym, $pct, $price] | @tsv
    ' | while IFS=$'\t' read -r sym pct price; do
      rank=$((rank + 1))
      local priceFmt
      priceFmt=$(_format_price "$price")
      printf '%2d. %-8s  %8s%%  %10s\n' "$rank" "$sym" "$pct" "$priceFmt"
    done
  fi

  # Fallback: if it's a flat array (not gainers/losers structure)
  if [[ "$has_gainers" != "true" && "$has_losers" != "true" ]]; then
    local rank=0
    echo "$json" | jq -r '
      .[] |
      (.symbol // "N/A") as $sym |
      (.percent_change // .change // 0 | tostring) as $pct |
      (.price // .last_price // 0 | tostring) as $price |
      [$sym, $pct, $price] | @tsv
    ' | while IFS=$'\t' read -r sym pct price; do
      rank=$((rank + 1))
      local priceFmt
      priceFmt=$(_format_price "$price")
      printf '%2d. %-8s  %8s%%  %10s\n' "$rank" "$sym" "$pct" "$priceFmt"
    done
  fi
}

_format_movers_csv() {
  local json="$1"
  echo "section,symbol,percent_change,price"
  echo "$json" | jq -r '
    if (.gainers | type) == "array" then
      (.gainers[] | ["gainer", (.symbol // ""), (.percent_change // .change // "" | tostring), (.price // .last_price // "" | tostring)] | @csv),
      (.losers[]? | ["loser", (.symbol // ""), (.percent_change // .change // "" | tostring), (.price // .last_price // "" | tostring)] | @csv)
    elif (. | type) == "array" then
      .[] | ["", (.symbol // ""), (.percent_change // .change // "" | tostring), (.price // .last_price // "" | tostring)] | @csv
    else empty
    end
  '
}

# ---------------------------------------------------------------------------
# Formatting: options / option-chain (table)
# ---------------------------------------------------------------------------
_format_options_summary() {
  local items="$1"
  printf '%-22s  %10s  %10s  %10s  %8s  %s\n' "CONTRACT" "BID" "ASK" "LAST" "VOLUME" "GREEKS"
  printf '%-22s  %10s  %10s  %10s  %8s  %s\n' "--------" "---" "---" "----" "------" "------"
  echo "$items" | jq -r '
    .[] |
    (.symbol // .contract // "N/A") as $contract |
    (.bid // .bid_price // null) as $bid |
    (.ask // .ask_price // null) as $ask |
    (.last // .last_price // .close // null) as $last |
    (.volume // null) as $vol |
    (if .greeks then
      "d=" + (.greeks.delta // "?" | tostring) + " g=" + (.greeks.gamma // "?" | tostring)
     else "N/A" end) as $greeks |
    [$contract, ($bid // "" | tostring), ($ask // "" | tostring), ($last // "" | tostring), ($vol // "" | tostring), $greeks] | @tsv
  ' | while IFS=$'\t' read -r contract bid ask last vol greeks; do
    local bidFmt askFmt lastFmt
    bidFmt=$(_format_price "$bid")
    askFmt=$(_format_price "$ask")
    lastFmt=$(_format_price "$last")
    printf '%-22s  %10s  %10s  %10s  %8s  %s\n' "$contract" "$bidFmt" "$askFmt" "$lastFmt" "$vol" "$greeks"
  done
}

_format_options_csv() {
  local items="$1"
  echo "contract,bid,ask,last,volume,delta,gamma"
  echo "$items" | jq -r '
    .[] |
    [(.symbol // .contract // ""),
     (.bid // .bid_price // "" | tostring), (.ask // .ask_price // "" | tostring),
     (.last // .last_price // .close // "" | tostring), (.volume // "" | tostring),
     (.greeks.delta // "" | tostring), (.greeks.gamma // "" | tostring)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: corporate-actions (key-value per action)
# ---------------------------------------------------------------------------
_format_corporate_actions_summary() {
  local items="$1"
  echo "$items" | jq -r '
    .[] |
    to_entries |
    map(select(.value != null and (.value | type) != "object" and (.value | type) != "array")) |
    .[] |
    "  \(.key): \(.value)"
  '
}

_format_corporate_actions_csv() {
  local items="$1"
  # Extract all unique scalar keys for header
  local header
  header=$(echo "$items" | jq -r '
    [.[] | to_entries[] | select(.value != null and (.value | type) != "object" and (.value | type) != "array") | .key] | unique | join(",")
  ')
  echo "$header"
  echo "$items" | jq -r --arg hdr "$header" '
    ($hdr | split(",")) as $keys |
    .[] |
    . as $item |
    [$keys[] | ($item[.] // "" | tostring)] | @csv
  '
}

# ---------------------------------------------------------------------------
# Formatting: orderbook (bids/asks sections)
# ---------------------------------------------------------------------------
_format_orderbook_summary() {
  local items="$1"
  local obj
  obj=$(echo "$items" | jq '.[0] // .')

  echo "=== BIDS ==="
  printf '  %10s  %8s\n' "PRICE" "SIZE"
  printf '  %10s  %8s\n' "-----" "----"
  echo "$obj" | jq -r '
    (.bids // [])[] |
    (.p // .price // 0 | tostring) as $price |
    (.s // .size // 0 | tostring) as $size |
    [$price, $size] | @tsv
  ' | while IFS=$'\t' read -r price size; do
    local priceFmt
    priceFmt=$(_format_price "$price")
    printf '  %10s  %8s\n' "$priceFmt" "$size"
  done

  echo "=== ASKS ==="
  printf '  %10s  %8s\n' "PRICE" "SIZE"
  printf '  %10s  %8s\n' "-----" "----"
  echo "$obj" | jq -r '
    (.asks // [])[] |
    (.p // .price // 0 | tostring) as $price |
    (.s // .size // 0 | tostring) as $size |
    [$price, $size] | @tsv
  ' | while IFS=$'\t' read -r price size; do
    local priceFmt
    priceFmt=$(_format_price "$price")
    printf '  %10s  %8s\n' "$priceFmt" "$size"
  done
}

_format_orderbook_csv() {
  local items="$1"
  echo "side,price,size"
  local obj
  obj=$(echo "$items" | jq '.[0] // .')
  echo "$obj" | jq -r '
    ((.bids // [])[] | ["bid", (.p // .price // "" | tostring), (.s // .size // "" | tostring)] | @csv),
    ((.asks // [])[] | ["ask", (.p // .price // "" | tostring), (.s // .size // "" | tostring)] | @csv)
  '
}

# ---------------------------------------------------------------------------
# Formatting: snapshot
# ---------------------------------------------------------------------------
_format_snapshot_summary() {
  local items="$1"
  local obj
  obj=$(echo "$items" | jq '.[0] // .')

  echo "=== Latest Trade ==="
  echo "$obj" | jq -r '
    if .latestTrade then
      "  Price: " + (.latestTrade.p // "N/A" | tostring),
      "  Size:  " + (.latestTrade.s // "N/A" | tostring)
    elif .latest_trade then
      "  Price: " + (.latest_trade.p // "N/A" | tostring),
      "  Size:  " + (.latest_trade.s // "N/A" | tostring)
    else
      "  N/A"
    end
  '

  echo "=== Latest Quote ==="
  echo "$obj" | jq -r '
    if .latestQuote then
      "  Bid: " + (.latestQuote.bp // "N/A" | tostring) + "  Ask: " + (.latestQuote.ap // "N/A" | tostring)
    elif .latest_quote then
      "  Bid: " + (.latest_quote.bp // "N/A" | tostring) + "  Ask: " + (.latest_quote.ap // "N/A" | tostring)
    else
      "  N/A"
    end
  '

  echo "=== Daily Bar ==="
  echo "$obj" | jq -r '
    if .dailyBar then
      "  Open:   " + (.dailyBar.o // "N/A" | tostring),
      "  High:   " + (.dailyBar.h // "N/A" | tostring),
      "  Low:    " + (.dailyBar.l // "N/A" | tostring),
      "  Close:  " + (.dailyBar.c // "N/A" | tostring),
      "  Volume: " + (.dailyBar.v // "N/A" | tostring)
    elif .daily_bar then
      "  Open:   " + (.daily_bar.o // "N/A" | tostring),
      "  High:   " + (.daily_bar.h // "N/A" | tostring),
      "  Low:    " + (.daily_bar.l // "N/A" | tostring),
      "  Close:  " + (.daily_bar.c // "N/A" | tostring),
      "  Volume: " + (.daily_bar.v // "N/A" | tostring)
    else
      "  N/A"
    end
  '
}

_format_snapshot_csv() {
  local items="$1"
  # Snapshot is a complex nested object; fall back to full JSON
  echo "$items" | jq '.'
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

# Movers has a special structure (gainers/losers), handle separately
if [[ "$TYPE" == "movers" ]]; then
  # For movers, _extract_results returns the object itself (with gainers/losers)
  RESULTS=$(_extract_results "$INPUT")
  # Apply top to gainers and losers separately if present
  if [[ -n "$TOP" ]]; then
    RESULTS=$(echo "$RESULTS" | jq --argjson top "$TOP" '
      if (.gainers | type) == "array" then .gainers = .gainers[0:$top] else . end |
      if (.losers | type) == "array" then .losers = .losers[0:$top] else . end
    ')
  fi
  if [[ "$FORMAT" == "summary" ]]; then
    _format_movers_summary "$RESULTS"
  else
    _format_movers_csv "$RESULTS"
  fi
  exit 0
fi

RESULTS=$(_extract_results "$INPUT")
RESULTS=$(_apply_top "$RESULTS")

# Check for empty results
result_count=$(echo "$RESULTS" | jq 'if (. | type) == "array" then length else 1 end' 2>/dev/null || echo "0")
if [[ "$result_count" == "0" || "$result_count" == "null" ]]; then
  echo "No results found."
  exit 0
fi

case "${TYPE}" in
  account)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_account_summary "$RESULTS"
    else
      _format_account_csv "$RESULTS"
    fi
    ;;
  clock)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_clock_summary "$RESULTS"
    else
      _format_clock_csv "$RESULTS"
    fi
    ;;
  orders)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_orders_summary "$RESULTS"
    else
      _format_orders_csv "$RESULTS"
    fi
    ;;
  positions)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_positions_summary "$RESULTS"
    else
      _format_positions_csv "$RESULTS"
    fi
    ;;
  bars)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_bars_summary "$RESULTS"
    else
      _format_bars_csv "$RESULTS"
    fi
    ;;
  trades)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_trades_summary "$RESULTS"
    else
      _format_trades_csv "$RESULTS"
    fi
    ;;
  quotes)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_quotes_summary "$RESULTS"
    else
      _format_quotes_csv "$RESULTS"
    fi
    ;;
  assets)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_assets_summary "$RESULTS"
    else
      _format_assets_csv "$RESULTS"
    fi
    ;;
  watchlists)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_watchlists_summary "$RESULTS"
    else
      _format_watchlists_csv "$RESULTS"
    fi
    ;;
  calendar)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_calendar_summary "$RESULTS"
    else
      _format_calendar_csv "$RESULTS"
    fi
    ;;
  activities)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_activities_summary "$RESULTS"
    else
      _format_activities_csv "$RESULTS"
    fi
    ;;
  news)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_news_summary "$RESULTS"
    else
      _format_news_csv "$RESULTS"
    fi
    ;;
  options|option-chain)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_options_summary "$RESULTS"
    else
      _format_options_csv "$RESULTS"
    fi
    ;;
  corporate-actions)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_corporate_actions_summary "$RESULTS"
    else
      _format_corporate_actions_csv "$RESULTS"
    fi
    ;;
  orderbook)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_orderbook_summary "$RESULTS"
    else
      _format_orderbook_csv "$RESULTS"
    fi
    ;;
  snapshot)
    if [[ "$FORMAT" == "summary" ]]; then
      _format_snapshot_summary "$RESULTS"
    else
      _format_snapshot_csv "$RESULTS"
    fi
    ;;
  *)
    echo "Error: unhandled type '$TYPE'" >&2
    exit 1
    ;;
esac
