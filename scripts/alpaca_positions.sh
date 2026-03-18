#!/usr/bin/env bash
# scripts/alpaca_positions.sh — Position list, get, close, close-all
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_positions.sh" "Position management: list, get, close, close-all" \
"  alpaca_positions.sh list
    Returns all open positions

  alpaca_positions.sh get <symbol>
    Returns position for a specific symbol

  alpaca_positions.sh close <symbol> [options]
    --qty <N>           Number of shares to close
    --percentage <P>    Percentage of position to close (0-100)

  alpaca_positions.sh close-all
    Closes all open positions (returns 207 multi-status)"
}

cmd_list() {
  _fetch_and_output "positions" "$(_build_url "$LIB_TRADING_URL" "/v2/positions")"
}

cmd_get() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "get"

  _fetch_and_output "position" "$(_build_url "$LIB_TRADING_URL" "/v2/positions/$symbol")"
}

cmd_close() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "close"
  shift

  local qty percentage
  qty=$(_parse_flag "--qty" "$@")
  percentage=$(_parse_flag "--percentage" "$@")

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/positions/$symbol" \
    "qty=${qty}" \
    "percentage=${percentage}")

  local body
  body=$(_api_delete "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "close position" || return 1
  _json_output "$body"
}

cmd_close_all() {
  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/positions")
  local body
  body=$(_api_delete "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "close all positions" || return 1
  _json_output "$body"
}

# --- Main dispatch ---
if [[ $# -lt 1 ]]; then
  show_help
fi

subcommand="$1"
shift

case "$subcommand" in
  list)       cmd_list "$@" ;;
  get)        cmd_get "$@" ;;
  close)      cmd_close "$@" ;;
  close-all)  cmd_close_all "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
