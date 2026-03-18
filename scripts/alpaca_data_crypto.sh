#!/usr/bin/env bash
# scripts/alpaca_data_crypto.sh — Crypto market data: bars, trades, quotes, snapshots, orderbook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
# shellcheck source=_data_lib.sh
source "${SCRIPT_DIR}/_data_lib.sh"

readonly BASE_PATH="/v1beta3/crypto/us"

# _normalize_crypto_symbol <symbol>
# If symbol doesn't contain '/', append '/USD' (e.g. BTC -> BTC/USD).
_normalize_crypto_symbol() {
  local sym="$1"
  if [[ "$sym" != *"/"* ]]; then
    echo "${sym}/USD"
  else
    echo "$sym"
  fi
}

show_help() {
  _usage "alpaca_data_crypto.sh" "Crypto market data" \
"  alpaca_data_crypto.sh bars <symbol> --start <DATE> [options]
    --end <DATE>         End date
    --timeframe <V>      1Min|5Min|15Min|1H|1D (default: 1Day)
    --limit <N>          Max results per page
    --sort <V>           asc|desc
    --feed <V>           us
    --currency <V>       Currency code

  alpaca_data_crypto.sh trades <symbol> --start <DATE> [options]
  alpaca_data_crypto.sh quotes <symbol> --start <DATE> [options]
    Same options as bars (except --timeframe)

  alpaca_data_crypto.sh snapshot <symbol> [--feed <V>] [--currency <V>]
  alpaca_data_crypto.sh snapshots <SYMBOLS_CSV> [--feed <V>] [--currency <V>]
  alpaca_data_crypto.sh latest-trade <symbol>
  alpaca_data_crypto.sh latest-quote <symbol>
  alpaca_data_crypto.sh latest-bar <symbol>
  alpaca_data_crypto.sh orderbook <symbol>

  Symbols: BTC is auto-expanded to BTC/USD"
}

# Crypto API uses query params (?symbols=BTC/USD) not per-symbol paths.
# Override _data_lib.sh functions with direct query param construction.

cmd_bars() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "bars"
  shift
  local start end timeframe limit sort_order currency
  start=$(_parse_flag "--start" "$@"); _require_arg "start" "$start" "bars"
  end=$(_parse_flag "--end" "$@")
  timeframe=$(_parse_flag "--timeframe" "$@"); timeframe="${timeframe:-1Day}"
  limit=$(_parse_flag "--limit" "$@")
  sort_order=$(_parse_flag "--sort" "$@")
  currency=$(_parse_flag "--currency" "$@")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/bars" \
    "symbols=${symbol}" "start=${start}" "end=${end}" \
    "timeframe=${timeframe}" "limit=${limit}" "sort=${sort_order}" "currency=${currency}")
  _paginate_and_output "$url"
}

cmd_trades() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "trades"
  shift
  local start end limit sort_order currency
  start=$(_parse_flag "--start" "$@"); _require_arg "start" "$start" "trades"
  end=$(_parse_flag "--end" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort_order=$(_parse_flag "--sort" "$@")
  currency=$(_parse_flag "--currency" "$@")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/trades" \
    "symbols=${symbol}" "start=${start}" "end=${end}" \
    "limit=${limit}" "sort=${sort_order}" "currency=${currency}")
  _paginate_and_output "$url"
}

cmd_quotes() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "quotes"
  shift
  local start end limit sort_order currency
  start=$(_parse_flag "--start" "$@"); _require_arg "start" "$start" "quotes"
  end=$(_parse_flag "--end" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort_order=$(_parse_flag "--sort" "$@")
  currency=$(_parse_flag "--currency" "$@")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/quotes" \
    "symbols=${symbol}" "start=${start}" "end=${end}" \
    "limit=${limit}" "sort=${sort_order}" "currency=${currency}")
  _paginate_and_output "$url"
}

cmd_snapshot() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "snapshot"
  shift
  local currency
  currency=$(_parse_flag "--currency" "$@")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/snapshots" \
    "symbols=${symbol}" "currency=${currency}")
  _fetch_and_output "snapshot" "$url"
}

cmd_snapshots() {
  local symbols="${1:-}"
  _require_arg "symbols" "$symbols" "snapshots"
  shift
  local currency
  currency=$(_parse_flag "--currency" "$@")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/snapshots" \
    "symbols=${symbols}" "currency=${currency}")
  _fetch_and_output "snapshots" "$url"
}

cmd_latest_trade() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "latest-trade"
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/latest/trades" "symbols=${symbol}")
  _fetch_and_output "latest trade" "$url"
}

cmd_latest_quote() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "latest-quote"
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/latest/quotes" "symbols=${symbol}")
  _fetch_and_output "latest quote" "$url"
}

cmd_latest_bar() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "latest-bar"
  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/latest/bars" "symbols=${symbol}")
  _fetch_and_output "latest bar" "$url"
}

cmd_orderbook() {
  local symbol
  symbol=$(_normalize_crypto_symbol "${1:-}")
  _require_arg "symbol" "$symbol" "orderbook"

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/latest/orderbooks" \
    "symbols=${symbol}")

  _fetch_and_output "orderbook" "$url"
}

# --- Main dispatch ---
if [[ $# -lt 1 ]]; then
  show_help
fi

subcommand="$1"
shift

case "$subcommand" in
  bars)          cmd_bars "$@" ;;
  trades)        cmd_trades "$@" ;;
  quotes)        cmd_quotes "$@" ;;
  snapshot)      cmd_snapshot "$@" ;;
  snapshots)     cmd_snapshots "$@" ;;
  latest-trade)  cmd_latest_trade "$@" ;;
  latest-quote)  cmd_latest_quote "$@" ;;
  latest-bar)    cmd_latest_bar "$@" ;;
  orderbook)     cmd_orderbook "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
