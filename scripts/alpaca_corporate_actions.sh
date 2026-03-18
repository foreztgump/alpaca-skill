#!/usr/bin/env bash
# scripts/alpaca_corporate_actions.sh — Corporate actions: dividends, splits, mergers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_corporate_actions.sh" "Corporate actions: dividends, splits, mergers" \
"  alpaca_corporate_actions.sh list [options]
    --symbols <CSV>     Filter by symbols (e.g. AAPL,TSLA)
    --types <CSV>       Filter by action types (e.g. dividend,merger)
    --date-from <DATE>  Start date filter
    --date-to <DATE>    End date filter
    --limit <N>         Max results per page
    --sort <V>          asc|desc"
}

cmd_list() {
  local symbols types date_from date_to limit sort
  symbols=$(_parse_flag "--symbols" "$@")
  types=$(_parse_flag "--types" "$@")
  date_from=$(_parse_flag "--date-from" "$@")
  date_to=$(_parse_flag "--date-to" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort=$(_parse_flag "--sort" "$@")

  local url
  url=$(_build_url "$LIB_DATA_URL" "/v1beta1/corporate-actions" \
    "symbols=${symbols}" \
    "types=${types}" \
    "date_from=${date_from}" \
    "date_to=${date_to}" \
    "limit=${limit}" \
    "sort=${sort}")

  _paginate_and_output "$url"
}

# --- Main dispatch ---
if [[ $# -lt 1 ]]; then
  show_help
fi

subcommand="$1"
shift

case "$subcommand" in
  list)           cmd_list "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
