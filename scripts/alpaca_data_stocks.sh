#!/usr/bin/env bash
# scripts/alpaca_data_stocks.sh — Stock market data: bars, trades, quotes, snapshots
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_CALLER_ARGS=("$@")
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"
# shellcheck source=_data_lib.sh
source "${SCRIPT_DIR}/_data_lib.sh"

readonly BASE_PATH="/v2/stocks"

show_help() {
  _usage "alpaca_data_stocks.sh" "Stock market data" \
"  alpaca_data_stocks.sh bars <symbol> --start <DATE> [options]
    --end <DATE>         End date
    --timeframe <V>      1Min|5Min|15Min|1H|1D (default: 1Day)
    --limit <N>          Max results per page
    --sort <V>           asc|desc
    --feed <V>           iex|sip
    --currency <V>       Currency code

  alpaca_data_stocks.sh trades <symbol> --start <DATE> [options]
  alpaca_data_stocks.sh quotes <symbol> --start <DATE> [options]
    Same options as bars (except --timeframe)

  alpaca_data_stocks.sh snapshot <symbol> [--feed <V>] [--currency <V>]
  alpaca_data_stocks.sh snapshots <SYMBOLS_CSV> [--feed <V>] [--currency <V>]
  alpaca_data_stocks.sh latest-trade <symbol>
  alpaca_data_stocks.sh latest-quote <symbol>
  alpaca_data_stocks.sh latest-bar <symbol>"
}

cmd_bars() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "bars"
  shift
  _data_bars "$BASE_PATH" "$symbol" "$@"
}

cmd_trades() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "trades"
  shift
  _data_trades "$BASE_PATH" "$symbol" "$@"
}

cmd_quotes() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "quotes"
  shift
  _data_quotes "$BASE_PATH" "$symbol" "$@"
}

cmd_snapshot() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "snapshot"
  shift
  _data_snapshot "$BASE_PATH" "$symbol" "$@"
}

cmd_snapshots() {
  local symbols="${1:-}"
  _require_arg "symbols" "$symbols" "snapshots"
  shift
  _data_snapshots "$BASE_PATH" "$symbols" "$@"
}

cmd_latest_trade() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "latest-trade"
  _data_latest_trade "$BASE_PATH" "$symbol"
}

cmd_latest_quote() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "latest-quote"
  _data_latest_quote "$BASE_PATH" "$symbol"
}

cmd_latest_bar() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "latest-bar"
  _data_latest_bar "$BASE_PATH" "$symbol"
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
  quotes)        cmd_quotes "$@" ;;
  snapshot)      cmd_snapshot "$@" ;;
  snapshots)     cmd_snapshots "$@" ;;
  latest-trade)  cmd_latest_trade "$@" ;;
  latest-quote)  cmd_latest_quote "$@" ;;
  latest-bar)    cmd_latest_bar "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
