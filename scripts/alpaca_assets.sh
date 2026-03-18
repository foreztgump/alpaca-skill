#!/usr/bin/env bash
# scripts/alpaca_assets.sh — Asset lookup and search
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_assets.sh" "Asset lookup and search" \
"  alpaca_assets.sh get <symbol>
    Returns details for a specific asset

  alpaca_assets.sh list [options]
    --status <V>        active|inactive (default: active)
    --asset-class <V>   us_equity|crypto
    --exchange <V>      Filter by exchange
    --limit <N>         Max results (client-side slicing)"
}

cmd_get() {
  local symbol="${1:-}"
  _require_arg "symbol" "$symbol" "get"

  _fetch_and_output "asset" "$(_build_url "$LIB_TRADING_URL" "/v2/assets/$symbol")"
}

cmd_list() {
  local status asset_class exchange limit
  status=$(_parse_flag "--status" "$@")
  asset_class=$(_parse_flag "--asset-class" "$@")
  exchange=$(_parse_flag "--exchange" "$@")
  limit=$(_parse_flag "--limit" "$@")

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/assets" \
    "status=${status}" \
    "asset_class=${asset_class}" \
    "exchange=${exchange}")

  local body
  body=$(_api_get "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "list assets" || exit 1

  if [[ -n "$limit" ]]; then
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
      echo '{"error":"--limit must be a positive integer"}' >&2
      exit 1
    fi
    body=$(echo "$body" | jq ".[0:${limit}]")
  fi

  _json_output "$body"
}

# --- Main dispatch ---
if [[ $# -lt 1 ]]; then
  show_help
fi

subcommand="$1"
shift

case "$subcommand" in
  get)    cmd_get "$@" ;;
  list)   cmd_list "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
