#!/usr/bin/env bash
# scripts/alpaca_orders.sh — Order submit, list, get, cancel, replace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
LIB_CALLER_ARGS=("$@")
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

show_help() {
  _usage "alpaca_orders.sh" "Order management: submit, list, get, cancel, replace" \
"  alpaca_orders.sh submit <symbol> <buy|sell> <type> [flags]
    --qty <N>            Share quantity
    --notional <AMOUNT>  Dollar amount (mutually exclusive with --qty)
    --limit-price <P>    Limit price (required for limit, stop_limit)
    --stop-price <P>     Stop price (required for stop, stop_limit)
    --trail-percent <P>  Trail percent (for trailing_stop)
    --trail-price <P>    Trail price (for trailing_stop)
    --time-in-force <V>  day|gtc|opg|cls|ioc|fok (default: day)
    --extended-hours     Enable extended hours trading
    --client-order-id <ID>  Client-specified order ID
    --take-profit <P>    Take profit limit price (bracket order)
    --stop-loss <P>      Stop loss stop price (bracket order)
    --stop-loss-limit <P> Stop loss limit price (bracket order)
    --dry-run            Print order JSON without submitting

  alpaca_orders.sh list [flags]
    --status <V>         open|closed|all (default: open)
    --limit <N>          Max results
    --after <DATE>       After timestamp
    --until <DATE>       Until timestamp
    --direction <V>      asc|desc
    --nested             Include nested orders
    --symbols <CSV>      Filter by symbols

  alpaca_orders.sh get <order_id>
  alpaca_orders.sh get-by-client-id <client_order_id>
  alpaca_orders.sh cancel <order_id>
  alpaca_orders.sh cancel-all
  alpaca_orders.sh replace <order_id> [flags]
    --qty <N>            New quantity
    --limit-price <P>    New limit price
    --stop-price <P>     New stop price
    --trail <P>          New trail value
    --time-in-force <V>  New time in force"
}

# _validate_order_params
# Validates order parameters from caller's scope. Outputs error JSON to stderr.
# Returns 0 on success, 1 on validation failure.
_validate_order_params() {
  if [[ -n "$qty" && -n "$notional" ]]; then
    echo '{"error":"--qty and --notional are mutually exclusive"}' >&2
    return 1
  fi
  if [[ -z "$qty" && -z "$notional" ]]; then
    echo '{"error":"one of --qty or --notional is required"}' >&2
    return 1
  fi
  _validate_type_params || return 1
  if [[ "$symbol" == *"/"* ]]; then
    _validate_crypto_params || return 1
  fi
  return 0
}

# _validate_type_params — checks type-specific required params
_validate_type_params() {
  case "$order_type" in
    limit)
      [[ -n "$limit_price" ]] || { echo '{"error":"limit order requires --limit-price"}' >&2; return 1; }
      ;;
    stop)
      [[ -n "$stop_price" ]] || { echo '{"error":"stop order requires --stop-price"}' >&2; return 1; }
      ;;
    stop_limit)
      if [[ -z "$stop_price" || -z "$limit_price" ]]; then
        echo '{"error":"stop_limit order requires --stop-price and --limit-price"}' >&2
        return 1
      fi
      ;;
    trailing_stop)
      if [[ -n "$trail_percent" && -n "$trail_price" ]]; then
        echo '{"error":"--trail-percent and --trail-price are mutually exclusive"}' >&2
        return 1
      fi
      if [[ -z "$trail_percent" && -z "$trail_price" ]]; then
        echo '{"error":"trailing_stop requires --trail-percent or --trail-price"}' >&2
        return 1
      fi
      ;;
  esac
  return 0
}

# _validate_crypto_params — checks crypto-specific restrictions
_validate_crypto_params() {
  case "$order_type" in
    stop|trailing_stop)
      echo "{\"error\":\"crypto does not support ${order_type} orders\"}" >&2
      return 1 ;;
  esac
  case "$time_in_force" in
    day|opg|cls|fok)
      echo "{\"error\":\"crypto does not support time_in_force=${time_in_force}\"}" >&2
      return 1 ;;
  esac
  return 0
}

# _build_order_body
# Builds JSON order body from caller's scope variables using jq.
_build_order_body() {
  jq -n \
    --arg symbol "$symbol" \
    --arg side "$side" \
    --arg type "$order_type" \
    --arg tif "$time_in_force" \
    --arg qty "$qty" \
    --arg notional "$notional" \
    --arg limit_price "$limit_price" \
    --arg stop_price "$stop_price" \
    --arg trail_percent "$trail_percent" \
    --arg trail_price "$trail_price" \
    --arg client_order_id "$client_order_id" \
    --argjson extended_hours "${extended_hours:-false}" \
    --arg take_profit "$take_profit" \
    --arg stop_loss "$stop_loss" \
    --arg stop_loss_limit "$stop_loss_limit" \
    '{symbol: $symbol, side: $side, type: $type, time_in_force: $tif}
     | if $qty != "" then . + {qty: $qty} else . end
     | if $notional != "" then . + {notional: $notional} else . end
     | if $limit_price != "" then . + {limit_price: $limit_price} else . end
     | if $stop_price != "" then . + {stop_price: $stop_price} else . end
     | if $trail_percent != "" then . + {trail_percent: $trail_percent} else . end
     | if $trail_price != "" then . + {trail_price: $trail_price} else . end
     | if $client_order_id != "" then . + {client_order_id: $client_order_id} else . end
     | if $extended_hours then . + {extended_hours: true} else . end
     | if $take_profit != "" then . + {order_class: "bracket", take_profit: {limit_price: $take_profit}} else . end
     | if $stop_loss != "" then .stop_loss = {stop_price: $stop_loss} else . end
     | if $stop_loss_limit != "" then .stop_loss.limit_price = $stop_loss_limit else . end'
}

# cmd_submit <symbol> <side> <type> [flags]
# Orchestrates order validation, body building, and submission.
cmd_submit() {
  local symbol="${1:-}" side="${2:-}" order_type="${3:-}"
  _require_arg "symbol" "$symbol" "submit"
  _require_arg "side" "$side" "submit"
  _require_arg "type" "$order_type" "submit"
  shift 3

  # Parse all flags into variables used by _validate and _build
  local qty notional limit_price stop_price trail_percent trail_price
  local client_order_id extended_hours take_profit stop_loss stop_loss_limit
  local time_in_force dry_run
  qty=$(_parse_flag "--qty" "$@")
  notional=$(_parse_flag "--notional" "$@")
  limit_price=$(_parse_flag "--limit-price" "$@")
  stop_price=$(_parse_flag "--stop-price" "$@")
  trail_percent=$(_parse_flag "--trail-percent" "$@")
  trail_price=$(_parse_flag "--trail-price" "$@")
  time_in_force=$(_parse_flag "--time-in-force" "$@")
  time_in_force="${time_in_force:-day}"
  client_order_id=$(_parse_flag "--client-order-id" "$@")
  take_profit=$(_parse_flag "--take-profit" "$@")
  stop_loss=$(_parse_flag "--stop-loss" "$@")
  stop_loss_limit=$(_parse_flag "--stop-loss-limit" "$@")
  extended_hours=false; _has_flag "--extended-hours" "$@" && extended_hours=true
  dry_run=false; _has_flag "--dry-run" "$@" && dry_run=true

  _validate_order_params || return 1
  local body; body=$(_build_order_body)

  if [[ "$dry_run" == "true" ]]; then
    _json_output "$body"; return 0
  fi
  local url response
  url=$(_build_url "$LIB_TRADING_URL" "/v2/orders")
  response=$(_api_post "$url" "$body")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$response" "submit order" || return 1
  _json_output "$response"
}

cmd_list() {
  local status limit after until_val direction nested symbols
  status=$(_parse_flag "--status" "$@")
  status="${status:-open}"
  limit=$(_parse_flag "--limit" "$@")
  after=$(_parse_flag "--after" "$@")
  until_val=$(_parse_flag "--until" "$@")
  direction=$(_parse_flag "--direction" "$@")
  symbols=$(_parse_flag "--symbols" "$@")
  nested=false
  if _has_flag "--nested" "$@"; then
    nested=true
  fi

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/orders" \
    "status=${status}" \
    "limit=${limit}" \
    "after=${after}" \
    "until=${until_val}" \
    "direction=${direction}" \
    "nested=${nested}" \
    "symbols=${symbols}")

  _paginate_and_output "$url" "$limit"
}

cmd_get() {
  local order_id="${1:-}"
  _require_arg "order_id" "$order_id" "get"

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/orders/${order_id}")
  _fetch_and_output "get order" "$url"
}

cmd_get_by_client_id() {
  local client_order_id="${1:-}"
  _require_arg "client_order_id" "$client_order_id" "get-by-client-id"

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/orders:by_client_order_id" \
    "client_order_id=${client_order_id}")
  _fetch_and_output "get order by client id" "$url"
}

cmd_cancel() {
  local order_id="${1:-}"
  _require_arg "order_id" "$order_id" "cancel"

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/orders/${order_id}")
  local body
  body=$(_api_delete "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "cancel order" || return 1

  if [[ -n "$body" && "$body" != "{}" ]]; then
    _json_output "$body"
  else
    echo '{"status":"order cancelled"}'
  fi
}

cmd_cancel_all() {
  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/orders")
  local body
  body=$(_api_delete "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "cancel all orders" || return 1
  _json_output "$body"
}

cmd_replace() {
  local order_id="${1:-}"
  _require_arg "order_id" "$order_id" "replace"
  shift

  local qty limit_price stop_price trail time_in_force
  qty=$(_parse_flag "--qty" "$@")
  limit_price=$(_parse_flag "--limit-price" "$@")
  stop_price=$(_parse_flag "--stop-price" "$@")
  trail=$(_parse_flag "--trail" "$@")
  time_in_force=$(_parse_flag "--time-in-force" "$@")

  local body
  body=$(jq -n \
    --arg qty "$qty" \
    --arg limit_price "$limit_price" \
    --arg stop_price "$stop_price" \
    --arg trail "$trail" \
    --arg tif "$time_in_force" \
    '{}
     | if $qty != "" then . + {qty: $qty} else . end
     | if $limit_price != "" then . + {limit_price: $limit_price} else . end
     | if $stop_price != "" then . + {stop_price: $stop_price} else . end
     | if $trail != "" then . + {trail: $trail} else . end
     | if $tif != "" then . + {time_in_force: $tif} else . end')

  local url
  url=$(_build_url "$LIB_TRADING_URL" "/v2/orders/${order_id}")
  local response
  response=$(_api_patch "$url" "$body")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$response" "replace order" || return 1
  _json_output "$response"
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
  submit)             cmd_submit "$@" ;;
  list)               cmd_list "$@" ;;
  get)                cmd_get "$@" ;;
  get-by-client-id)   cmd_get_by_client_id "$@" ;;
  cancel)             cmd_cancel "$@" ;;
  cancel-all)         cmd_cancel_all "$@" ;;
  replace)            cmd_replace "$@" ;;
  -h|--help|help)     show_help ;;
  *)
    echo "{\"error\":\"unknown subcommand: ${subcommand}\"}" >&2
    show_help
    ;;
esac
