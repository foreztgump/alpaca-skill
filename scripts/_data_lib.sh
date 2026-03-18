#!/usr/bin/env bash
# scripts/_data_lib.sh — shared market data helpers for bars, trades, quotes, snapshots
# Source this file from data scripts: source "${SCRIPT_DIR}/_data_lib.sh"
#
# All functions take base_path as first param so the same logic works
# for stocks (/v2/stocks), crypto (/v1beta3/crypto/us), and options (/v1beta1/options).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

# _encode_symbol <symbol>
# URL-encode slashes in symbol for path segments (e.g. BTC/USD -> BTC%2FUSD).
_encode_symbol() {
  local sym="$1"
  if [[ "$sym" == *"/"* ]]; then
    _urlencode "$sym"
  else
    echo "$sym"
  fi
}

# _data_bars <base_path> <symbol> [flags...]
# Fetch historical bar (OHLCV) data with auto-pagination.
# Required: --start. Optional: --end, --timeframe (default 1Day), --limit, --sort, --feed, --currency.
_data_bars() {
  local base_path="$1"
  local symbol="$2"
  shift 2

  local start end timeframe limit sort feed currency
  start=$(_parse_flag "--start" "$@")
  _require_arg "--start" "$start" "_data_bars"
  end=$(_parse_flag "--end" "$@")
  timeframe=$(_parse_flag "--timeframe" "$@")
  timeframe="${timeframe:-1Day}"
  limit=$(_parse_flag "--limit" "$@")
  sort=$(_parse_flag "--sort" "$@")
  feed=$(_parse_flag "--feed" "$@")
  currency=$(_parse_flag "--currency" "$@")

  local encoded_sym
  encoded_sym=$(_encode_symbol "$symbol")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/${encoded_sym}/bars" \
    "start=${start}" \
    "end=${end}" \
    "timeframe=${timeframe}" \
    "limit=${limit}" \
    "sort=${sort}" \
    "feed=${feed}" \
    "currency=${currency}")

  _paginate_and_output "$url"
}

# _data_trades <base_path> <symbol> [flags...]
# Fetch historical trade data with auto-pagination.
# Required: --start. Optional: --end, --limit, --sort, --feed, --currency.
_data_trades() {
  local base_path="$1"
  local symbol="$2"
  shift 2

  local start end limit sort feed currency
  start=$(_parse_flag "--start" "$@")
  _require_arg "--start" "$start" "_data_trades"
  end=$(_parse_flag "--end" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort=$(_parse_flag "--sort" "$@")
  feed=$(_parse_flag "--feed" "$@")
  currency=$(_parse_flag "--currency" "$@")

  local encoded_sym
  encoded_sym=$(_encode_symbol "$symbol")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/${encoded_sym}/trades" \
    "start=${start}" \
    "end=${end}" \
    "limit=${limit}" \
    "sort=${sort}" \
    "feed=${feed}" \
    "currency=${currency}")

  _paginate_and_output "$url"
}

# _data_quotes <base_path> <symbol> [flags...]
# Fetch historical quote data with auto-pagination.
# Required: --start. Optional: --end, --limit, --sort, --feed, --currency.
_data_quotes() {
  local base_path="$1"
  local symbol="$2"
  shift 2

  local start end limit sort feed currency
  start=$(_parse_flag "--start" "$@")
  _require_arg "--start" "$start" "_data_quotes"
  end=$(_parse_flag "--end" "$@")
  limit=$(_parse_flag "--limit" "$@")
  sort=$(_parse_flag "--sort" "$@")
  feed=$(_parse_flag "--feed" "$@")
  currency=$(_parse_flag "--currency" "$@")

  local encoded_sym
  encoded_sym=$(_encode_symbol "$symbol")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/${encoded_sym}/quotes" \
    "start=${start}" \
    "end=${end}" \
    "limit=${limit}" \
    "sort=${sort}" \
    "feed=${feed}" \
    "currency=${currency}")

  _paginate_and_output "$url"
}

# _data_snapshot <base_path> <symbol> [flags...]
# Fetch a single symbol snapshot (no pagination).
# Optional: --feed, --currency.
_data_snapshot() {
  local base_path="$1"
  local symbol="$2"
  shift 2

  local feed currency
  feed=$(_parse_flag "--feed" "$@")
  currency=$(_parse_flag "--currency" "$@")

  local encoded_sym
  encoded_sym=$(_encode_symbol "$symbol")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/${encoded_sym}/snapshot" \
    "feed=${feed}" \
    "currency=${currency}")

  _fetch_and_output "snapshot" "$url"
}

# _data_snapshots <base_path> <symbols_csv> [flags...]
# Fetch snapshots for multiple symbols (no pagination).
# Optional: --feed, --currency.
_data_snapshots() {
  local base_path="$1"
  local symbols_csv="$2"
  shift 2

  local feed currency
  feed=$(_parse_flag "--feed" "$@")
  currency=$(_parse_flag "--currency" "$@")

  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/snapshots" \
    "symbols=${symbols_csv}" \
    "feed=${feed}" \
    "currency=${currency}")

  _fetch_and_output "snapshots" "$url"
}

# _data_latest_trade <base_path> <symbol>
# Fetch the latest trade for a symbol.
_data_latest_trade() {
  local base_path="$1"
  local symbol="$2"

  local encoded_sym
  encoded_sym=$(_encode_symbol "$symbol")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/${encoded_sym}/trades/latest")

  _fetch_and_output "latest trade" "$url"
}

# _data_latest_quote <base_path> <symbol>
# Fetch the latest quote for a symbol.
_data_latest_quote() {
  local base_path="$1"
  local symbol="$2"

  local encoded_sym
  encoded_sym=$(_encode_symbol "$symbol")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/${encoded_sym}/quotes/latest")

  _fetch_and_output "latest quote" "$url"
}

# _data_latest_bar <base_path> <symbol>
# Fetch the latest bar for a symbol.
_data_latest_bar() {
  local base_path="$1"
  local symbol="$2"

  local encoded_sym
  encoded_sym=$(_encode_symbol "$symbol")
  local url
  url=$(_build_url "$LIB_DATA_URL" "${base_path}/${encoded_sym}/bars/latest")

  _fetch_and_output "latest bar" "$url"
}
