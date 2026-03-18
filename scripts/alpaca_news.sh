#!/usr/bin/env bash
# scripts/alpaca_news.sh — Market news feed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_CALLER_ARGS=("$@")
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_news.sh" "Market news feed" \
"  alpaca_news.sh list [options]
    --symbols <CSV>         Filter by symbols (e.g. AAPL,TSLA)
    --start <DATE>          Start date
    --end <DATE>            End date
    --limit <N>             Max results per page
    --sort <V>              asc|desc
    --include-content       Include full article content
    --exclude-contentless   Exclude articles without content"
}

cmd_list() {
  local symbols start end limit sort
  symbols=$(_parse_flag "--symbols" "$@")
  start=$(_parse_flag "--start" "$@")
  end=$(_parse_flag "--end" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort=$(_parse_flag "--sort" "$@")

  local params=(
    "symbols=${symbols}"
    "start=${start}"
    "end=${end}"
    "limit=${limit}"
    "sort=${sort}"
  )

  if _has_flag "--include-content" "$@"; then
    params+=("include_content=true")
  fi

  if _has_flag "--exclude-contentless" "$@"; then
    params+=("exclude_contentless=true")
  fi

  local url
  url=$(_build_url "$LIB_DATA_URL" "/v1beta1/news" "${params[@]}")

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
  list)           cmd_list "$@" ;;
  -h|--help|help) show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
