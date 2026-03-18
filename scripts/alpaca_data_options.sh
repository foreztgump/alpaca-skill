#!/usr/bin/env bash
# scripts/alpaca_data_options.sh — Options market data: bars, trades, quotes, snapshots, chain
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_CALLER_ARGS=("$@")
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

readonly BASE_PATH="/v1beta1/options"

show_help() {
  _usage "alpaca_data_options.sh" "Options market data" \
"  alpaca_data_options.sh bars <symbol> [options]
    --start <DATE>       Start date
    --end <DATE>         End date
    --timeframe <V>      1Min|5Min|15Min|1H|1D (default: 1Day)
    --limit <N>          Max results per page
    --sort <V>           asc|desc

  alpaca_data_options.sh trades <symbol> [options]
    --start <DATE>       Start date
    --end <DATE>         End date
    --limit <N>          Max results per page
    --sort <V>           asc|desc

  alpaca_data_options.sh latest-quote <symbol>
  alpaca_data_options.sh latest-trade <symbol>
  alpaca_data_options.sh snapshot <symbol>
  alpaca_data_options.sh snapshots <SYMBOLS_CSV>

  alpaca_data_options.sh chain <underlying> [options]
    --expiration-date <DATE>   Expiration date filter
    --type <V>                 call|put
    --strike-price-gte <P>     Min strike price
    --strike-price-lte <P>     Max strike price
    --root-symbol <V>          Root symbol filter"
}

cmd_bars() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "bars"
  shift

  local start end timeframe limit sort
  start=$(_parse_flag "--start" "$@")
  end=$(_parse_flag "--end" "$@")
  timeframe=$(_parse_flag "--timeframe" "$@")
  timeframe="${timeframe:-1Day}"
  limit=$(_parse_flag "--limit" "$@")
  sort=$(_parse_flag "--sort" "$@")

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/bars" \
    "symbols=${symbol}" \
    "start=${start}" \
    "end=${end}" \
    "timeframe=${timeframe}" \
    "limit=${limit}" \
    "sort=${sort}")

  _paginate_and_output "$url"
}

cmd_trades() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "trades"
  shift

  local start end limit sort
  start=$(_parse_flag "--start" "$@")
  end=$(_parse_flag "--end" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort=$(_parse_flag "--sort" "$@")

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/trades" \
    "symbols=${symbol}" \
    "start=${start}" \
    "end=${end}" \
    "limit=${limit}" \
    "sort=${sort}")

  _paginate_and_output "$url"
}

cmd_latest_quote() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "latest-quote"

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/quotes/latest" \
    "symbols=${symbol}")

  _fetch_and_output "latest quote" "$url"
}

cmd_latest_trade() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "latest-trade"

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/trades/latest" \
    "symbols=${symbol}")

  _fetch_and_output "latest trade" "$url"
}

cmd_snapshot() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "snapshot"

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/snapshots/${symbol}")

  _fetch_and_output "snapshot" "$url"
}

cmd_snapshots() {
  local symbols="${1:-}"
  _require_arg "symbols" "$symbols" "snapshots"

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/snapshots" \
    "symbols=${symbols}")

  _paginate_and_output "$url"
}

cmd_chain() {
  local underlying="${1:-}"
  _require_arg "underlying" "$underlying" "chain"
  shift

  local expiration_date option_type strike_gte strike_lte root_symbol
  expiration_date=$(_parse_flag "--expiration-date" "$@")
  option_type=$(_parse_flag "--type" "$@")
  strike_gte=$(_parse_flag "--strike-price-gte" "$@")
  strike_lte=$(_parse_flag "--strike-price-lte" "$@")
  root_symbol=$(_parse_flag "--root-symbol" "$@")

  local url
  url=$(_build_url "$LIB_DATA_URL" "${BASE_PATH}/snapshots/${underlying}" \
    "expiration_date=${expiration_date}" \
    "type=${option_type}" \
    "strike_price_gte=${strike_gte}" \
    "strike_price_lte=${strike_lte}" \
    "root_symbol=${root_symbol}")

  _paginate_and_output "$url"
}

# --- Main dispatch ---
if [[ $# -lt 1 ]]; then
  show_help
fi

subcommand="$1"
shift
# Strip --live/--paper flags (already handled by _lib.sh)
eval set -- "$(_strip_mode_flags "$@")"

case "$subcommand" in
  bars)          cmd_bars "$@" ;;
  trades)        cmd_trades "$@" ;;
  latest-quote)  cmd_latest_quote "$@" ;;
  latest-trade)  cmd_latest_trade "$@" ;;
  snapshot)      cmd_snapshot "$@" ;;
  snapshots)     cmd_snapshots "$@" ;;
  chain)         cmd_chain "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
