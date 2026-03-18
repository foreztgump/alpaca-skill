#!/usr/bin/env bash
# scripts/alpaca_market.sh — Market clock and calendar
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_market.sh" "Market clock and trading calendar" \
"  alpaca_market.sh clock
    Returns current market clock (open/close times, is_open)

  alpaca_market.sh calendar [options]
    --start <DATE>      Start date (YYYY-MM-DD)
    --end <DATE>        End date (YYYY-MM-DD)"
}

cmd_clock() {
  _fetch_and_output "clock" "$(_build_url "$LIB_TRADING_URL" "/v2/clock")"
}

cmd_calendar() {
  local start end
  start=$(_parse_flag "--start" "$@")
  end=$(_parse_flag "--end" "$@")

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/calendar" \
    "start=${start}" \
    "end=${end}")

  _fetch_and_output "calendar" "$url"
}

# --- Main dispatch ---
if [[ $# -lt 1 ]]; then
  show_help
fi

subcommand="$1"
shift

case "$subcommand" in
  clock)     cmd_clock "$@" ;;
  calendar)  cmd_calendar "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
