#!/usr/bin/env bash
# scripts/alpaca_account.sh — Account info, portfolio history, config, activities
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_account.sh" "Account info, portfolio history, config, and activities" \
"  alpaca_account.sh info
    Returns buying power, cash, portfolio value, equity

  alpaca_account.sh history [options]
    --period         Time period (default: 1M)
    --timeframe      1Min|5Min|15Min|1H|1D (default: 1D)
    --date-end       End date (YYYY-MM-DD)
    --extended-hours  Include extended hours

  alpaca_account.sh config
    Returns account configurations

  alpaca_account.sh activities [type] [options]
    type              Activity type (e.g. FILL, DIV, JNLC)
    --activity-type   Filter by activity type (via query param)
    --date            Exact date filter
    --after           After cursor for pagination
    --until           Until date filter
    --direction       asc|desc
    --page-size       Number of results per page"
}

cmd_info() {
  _fetch_and_output "account" "$(_build_url "$LIB_TRADING_URL" "/v2/account")"
}

cmd_history() {
  local period timeframe date_end
  period=$(_parse_flag "--period" "$@")
  timeframe=$(_parse_flag "--timeframe" "$@")
  date_end=$(_parse_flag "--date-end" "$@")

  period="${period:-1M}"
  timeframe="${timeframe:-1D}"

  local params=(
    "period=${period}"
    "timeframe=${timeframe}"
    "date_end=${date_end}"
  )

  if _has_flag "--extended-hours" "$@"; then
    params+=("extended_hours=true")
  fi

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/account/portfolio/history" "${params[@]}")

  _fetch_and_output "portfolio history" "$url"
}

cmd_config() {
  _fetch_and_output "account config" "$(_build_url "$LIB_TRADING_URL" "/v2/account/configurations")"
}

cmd_activities() {
  local activity_type_path=""

  # If first positional arg doesn't start with --, use it as activity type in path
  if [[ $# -gt 0 && "$1" != --* ]]; then
    activity_type_path="$1"
    shift
  fi

  local activity_type date after until_val direction page_size
  activity_type=$(_parse_flag "--activity-type" "$@")
  date=$(_parse_flag "--date" "$@")
  after=$(_parse_flag "--after" "$@")
  until_val=$(_parse_flag "--until" "$@")
  direction=$(_parse_flag "--direction" "$@")
  page_size=$(_parse_flag "--page-size" "$@")

  local path
  if [[ -n "$activity_type_path" ]]; then
    path="/v2/account/activities/${activity_type_path}"
  else
    path="/v2/account/activities"
  fi

  local url
  url=$(_build_url "$LIB_TRADING_URL" "$path" \
    "activity_type=${activity_type}" \
    "date=${date}" \
    "after=${after}" \
    "until=${until_val}" \
    "direction=${direction}" \
    "page_size=${page_size}")

  _paginate_and_output "$url"
}

# --- Main dispatch ---
if [[ $# -lt 1 ]]; then
  show_help
fi

subcommand="$1"
shift

case "$subcommand" in
  info)       cmd_info "$@" ;;
  history)    cmd_history "$@" ;;
  config)     cmd_config "$@" ;;
  activities) cmd_activities "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
