#!/usr/bin/env bash
# scripts/alpaca_watchlists.sh — Watchlist CRUD: list, get, create, add/remove symbols, delete
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_CALLER_ARGS=("$@")
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_watchlists.sh" "Watchlist management" \
"  alpaca_watchlists.sh list
    List all watchlists

  alpaca_watchlists.sh get <id>
    Get a specific watchlist by ID

  alpaca_watchlists.sh create <name> [--symbols CSV]
    Create a new watchlist with optional initial symbols

  alpaca_watchlists.sh add-symbol <id> <symbol>
    Add a symbol to a watchlist

  alpaca_watchlists.sh remove-symbol <id> <symbol>
    Remove a symbol from a watchlist

  alpaca_watchlists.sh delete <id>
    Delete a watchlist"
}

cmd_list() {
  _fetch_and_output "watchlists" "$(_build_url "$LIB_TRADING_URL" "/v2/watchlists")"
}

cmd_get() {
  local id="${1:-}"
  _require_arg "id" "$id" "get"

  _fetch_and_output "watchlist" "$(_build_url "$LIB_TRADING_URL" "/v2/watchlists/${id}")"
}

cmd_create() {
  local name="${1:-}"
  _require_arg "name" "$name" "create"
  shift

  local symbols_csv
  symbols_csv=$(_parse_flag "--symbols" "$@")

  local body
  if [[ -n "$symbols_csv" ]]; then
    body=$(jq -n --arg name "$name" --arg syms "$symbols_csv" \
      '{name: $name, symbols: ($syms | split(","))}')
  else
    body=$(jq -n --arg name "$name" '{name: $name}')
  fi

  local url response
  url=$(_build_url "$LIB_TRADING_URL" "/v2/watchlists")
  response=$(_api_post "$url" "$body")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$response" "create watchlist" || exit 1
  _json_output "$response"
}

cmd_add_symbol() {
  local id="${1:-}"
  _require_arg "id" "$id" "add-symbol"
  local symbol="${2:-}"
  _require_arg "symbol" "$symbol" "add-symbol"

  local body
  body=$(jq -n --arg s "$symbol" '{symbol: $s}')

  local url response
  url=$(_build_url "$LIB_TRADING_URL" "/v2/watchlists/${id}")
  response=$(_api_post "$url" "$body")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$response" "add symbol" || exit 1
  _json_output "$response"
}

cmd_remove_symbol() {
  local id="${1:-}"
  _require_arg "id" "$id" "remove-symbol"
  local symbol="${2:-}"
  _require_arg "symbol" "$symbol" "remove-symbol"

  local url body
  url=$(_build_url "$LIB_TRADING_URL" "/v2/watchlists/${id}/${symbol}")
  body=$(_api_delete "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "remove symbol" || exit 1

  if [[ -n "$body" && "$body" != "{}" ]]; then
    _json_output "$body"
  else
    echo '{"status":"symbol removed"}'
  fi
}

cmd_delete() {
  local id="${1:-}"
  _require_arg "id" "$id" "delete"

  local url body
  url=$(_build_url "$LIB_TRADING_URL" "/v2/watchlists/${id}")
  body=$(_api_delete "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "delete watchlist" || exit 1

  if [[ -n "$body" && "$body" != "{}" ]]; then
    _json_output "$body"
  else
    echo '{"status":"watchlist deleted"}'
  fi
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
  list)           cmd_list "$@" ;;
  get)            cmd_get "$@" ;;
  create)         cmd_create "$@" ;;
  add-symbol)     cmd_add_symbol "$@" ;;
  remove-symbol)  cmd_remove_symbol "$@" ;;
  delete)         cmd_delete "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
