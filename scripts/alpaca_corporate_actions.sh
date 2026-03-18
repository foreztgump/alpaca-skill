#!/usr/bin/env bash
# scripts/alpaca_corporate_actions.sh — Corporate actions: dividends, splits, mergers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_CALLER_ARGS=("$@")
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_corporate_actions.sh" "Corporate actions: dividends, splits, mergers" \
"  alpaca_corporate_actions.sh list [options]
    --symbols <CSV>     Filter by symbols (e.g. AAPL,TSLA)
    --types <CSV>       Filter by action types (e.g. dividend,merger,split,spinoff)
    --start <DATE>      Start date (YYYY-MM-DD)
    --end <DATE>        End date (YYYY-MM-DD)
    --limit <N>         Max results per page (1-1000, default 100)
    --sort <V>          asc|desc"
}

cmd_list() {
  local symbols types start_date end_date limit sort_order
  symbols=$(_parse_flag "--symbols" "$@")
  types=$(_parse_flag "--types" "$@")
  start_date=$(_parse_flag "--start" "$@")
  end_date=$(_parse_flag "--end" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort_order=$(_parse_flag "--sort" "$@")

  local url
  url=$(_build_url "$LIB_DATA_URL" "/v1beta1/corporate-actions" \
    "symbols=${symbols}" \
    "types=${types}" \
    "start=${start_date}" \
    "end=${end_date}" \
    "limit=${limit}" \
    "sort=${sort_order}")

  _paginate_and_output "$url" "$limit"
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
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
