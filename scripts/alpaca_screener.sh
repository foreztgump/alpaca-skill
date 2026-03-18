#!/usr/bin/env bash
# scripts/alpaca_screener.sh — Stock screener: most active, movers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_CALLER_ARGS=("$@")
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_screener.sh" "Stock screener: most active, movers" \
"  alpaca_screener.sh most-active [options]
    --by <V>        volume|trades (default: volume)
    --top <N>       Number of results (default: 10)

  alpaca_screener.sh movers [options]
    --market-type <V>   stocks|crypto (default: stocks)
    --top <N>           Number of results (default: 10)"
}

cmd_most_active() {
  local by top
  by=$(_parse_flag "--by" "$@")
  by="${by:-volume}"
  top=$(_parse_flag "--top" "$@")
  top="${top:-10}"

  local url
  url=$(_build_url "$LIB_DATA_URL" "/v1beta1/screener/stocks/most-actives" \
    "by=${by}" \
    "top=${top}")

  _fetch_and_output "most active" "$url"
}

cmd_movers() {
  local market_type top
  market_type=$(_parse_flag "--market-type" "$@")
  market_type="${market_type:-stocks}"
  top=$(_parse_flag "--top" "$@")
  top="${top:-10}"

  local url
  url=$(_build_url "$LIB_DATA_URL" "/v1beta1/screener/${market_type}/movers" \
    "top=${top}")

  _fetch_and_output "movers" "$url"
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
  most-active)    cmd_most_active "$@" ;;
  movers)         cmd_movers "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
