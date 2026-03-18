#!/usr/bin/env bash
# scripts/_lib.sh — shared functions for Alpaca Markets API scripts
# Source this file: source "${SCRIPT_DIR}/_lib.sh"
# NOTE: Sourcing scripts MUST set 'set -euo pipefail' before sourcing.
#
# Security summary (for auditors):
#   - External endpoints: paper-api.alpaca.markets, api.alpaca.markets, data.alpaca.markets
#   - Credentials: resolved from APCA_PAPER_KEY/APCA_PAPER_SECRET_KEY (paper)
#     or APCA_REAL_KEY/APCA_REAL_SECRET_KEY (live), via HTTP headers, never in URLs
#   - Fallback: APCA_API_KEY_ID/APCA_API_SECRET_KEY if mode-specific vars not set
#   - Local writes: ~/.config/alpaca-skill/ only
#   - No eval, no shell-outs to external tools

# --- Constants ---
# shellcheck disable=SC2034  # Constants used by scripts that source this library

readonly LIB_DATA_URL="https://data.alpaca.markets"
readonly LIB_CONFIG_DIR="${HOME}/.config/alpaca-skill"
readonly LIB_MAX_PAGES=10

# HTTP timeout in seconds
readonly HTTP_TIMEOUT="${APCA_TIMEOUT:-15}"

# File used to persist HTTP_CODE across subshells (deterministic path, no mktemp fork)
_LIB_HTTP_CODE_FILE="/tmp/.alpaca_http_code_$$"
trap 'rm -f "$_LIB_HTTP_CODE_FILE"' EXIT

# --- Mode Resolution ---
# Determine paper vs live mode. Checks (in order):
#   1. --live flag in caller's args (LIB_CALLER_ARGS) → live
#   2. --paper flag in caller's args → paper
#   3. APCA_PAPER env var (default: true)
#
# Domain scripts should set LIB_CALLER_ARGS before sourcing:
#   LIB_CALLER_ARGS=("$@"); source "${SCRIPT_DIR}/_lib.sh"

_LIB_IS_PAPER="true"
for _lib_arg in "${LIB_CALLER_ARGS[@]+"${LIB_CALLER_ARGS[@]}"}"; do
  case "$_lib_arg" in
    --live)  _LIB_IS_PAPER="false"; break ;;
    --paper) _LIB_IS_PAPER="true"; break ;;
  esac
done
# Fall back to env var if no flag found
if [[ -z "${LIB_CALLER_ARGS+x}" ]]; then
  _LIB_IS_PAPER="${APCA_PAPER:-true}"
fi

# Resolve trading URL
if [[ "$_LIB_IS_PAPER" == "true" ]]; then
  readonly LIB_TRADING_URL="https://paper-api.alpaca.markets"
else
  readonly LIB_TRADING_URL="https://api.alpaca.markets"
fi

# Track mode for display/logging (never log credentials)
if [[ "$_LIB_IS_PAPER" == "true" ]]; then
  readonly LIB_TRADING_MODE="paper"
else
  readonly LIB_TRADING_MODE="live"
fi

# --- Auth ---
# Resolve API key and secret based on resolved mode.
# Priority: mode-specific vars > generic vars
# Paper mode: APCA_PAPER_KEY / APCA_PAPER_SECRET_KEY
# Live mode:  APCA_REAL_KEY / APCA_REAL_SECRET_KEY
# Fallback:   APCA_API_KEY_ID / APCA_API_SECRET_KEY
if [[ "$_LIB_IS_PAPER" == "true" ]]; then
  APCA_API_KEY_ID="${APCA_PAPER_KEY:-${APCA_API_KEY_ID:-}}"
  APCA_API_SECRET_KEY="${APCA_PAPER_SECRET_KEY:-${APCA_API_SECRET_KEY:-}}"
else
  APCA_API_KEY_ID="${APCA_REAL_KEY:-${APCA_API_KEY_ID:-}}"
  APCA_API_SECRET_KEY="${APCA_REAL_SECRET_KEY:-${APCA_API_SECRET_KEY:-}}"
fi

# _strip_mode_flags <args...>
# Removes --live and --paper from argument list. Use in dispatch:
#   set -- $(_strip_mode_flags "$@")
_strip_mode_flags() {
  local filtered=()
  for arg in "$@"; do
    [[ "$arg" == "--live" || "$arg" == "--paper" ]] && continue
    filtered+=("$arg")
  done
  printf '%q ' "${filtered[@]}"
}

# _require_api_key
# Validates resolved API credentials are set. Exits with error if not.
_require_api_key() {
  if [[ -z "${APCA_API_KEY_ID:-}" ]]; then
    echo '{"error":"API key not set. Set APCA_PAPER_KEY (paper) or APCA_REAL_KEY (live), or APCA_API_KEY_ID as fallback."}' >&2
    exit 1
  fi
  if [[ -z "${APCA_API_SECRET_KEY:-}" ]]; then
    echo '{"error":"API secret not set. Set APCA_PAPER_SECRET_KEY (paper) or APCA_REAL_SECRET_KEY (live), or APCA_API_SECRET_KEY as fallback."}' >&2
    exit 1
  fi
}

# --- URL Building ---

# _urlencode <string>
# URL-encodes a string for safe use in query parameters.
_urlencode() {
  local string="$1"
  local encoded=""
  local i c hex
  for (( i=0; i<${#string}; i++ )); do
    c="${string:$i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      ' ') encoded+='+' ;;
      # printf -v avoids forking a subshell per character
      *) printf -v hex '%%%02X' "'$c"; encoded+="$hex" ;;
    esac
  done
  echo "$encoded"
}

# _build_url <base> <path> [query_params...]
# Builds a full API URL from base, path, and optional query parameters.
# Query params should be in "key=value" format. Empty values are skipped.
# Alpaca uses header auth — no API key appended to URL.
_build_url() {
  local base="$1"
  local path="$2"
  shift 2
  local url="${base}${path}"
  local sep="?"
  local param

  for param in "$@"; do
    # Skip params with no '=' separator
    [[ "$param" != *"="* ]] && continue
    local key="${param%%=*}"
    local val="${param#*=}"
    if [[ -n "$val" ]]; then
      url="${url}${sep}${key}=$(_urlencode "$val")"
      sep="&"
    fi
  done

  echo "$url"
}

# --- HTTP ---

# _http_request <method> <url> [json_body]
# PRIVATE. Makes an authenticated HTTP request to Alpaca.
# Sends APCA-API-KEY-ID and APCA-API-SECRET-KEY via headers.
# Extracts HTTP code via curl -w and writes to temp file for subshell access.
# Outputs response body to stdout.
_http_request() {
  local method="$1"
  local url="$2"
  local json_body="${3:-}"

  local -a curl_args=(
    -s
    -w "\n%{http_code}"
    -X "$method"
    -m "$HTTP_TIMEOUT"
    -H "APCA-API-KEY-ID: ${APCA_API_KEY_ID}"
    -H "APCA-API-SECRET-KEY: ${APCA_API_SECRET_KEY}"
    -H "Accept: application/json"
  )

  # Set Content-Type for methods with a body
  if [[ "$method" == "POST" || "$method" == "PATCH" ]]; then
    curl_args+=(-H "Content-Type: application/json")
    if [[ -n "$json_body" ]]; then
      curl_args+=(-d "$json_body")
    fi
  fi

  local response
  if ! response=$(curl "${curl_args[@]}" "$url" 2>/dev/null); then
    echo '{"error":"network request failed"}' >&2
    HTTP_CODE="000"
    echo "$HTTP_CODE" > "$_LIB_HTTP_CODE_FILE"
    return 1
  fi

  # Extract HTTP code and body using bash string ops (no fork)
  HTTP_CODE="${response##*$'\n'}"
  echo "$HTTP_CODE" > "$_LIB_HTTP_CODE_FILE"
  echo "${response%$'\n'*}"
  return 0
}

# _api_get <url>
# Authenticated GET request.
_api_get() {
  _http_request GET "$1"
}

# _api_post <url> <json_body>
# Authenticated POST request with JSON body.
_api_post() {
  _http_request POST "$1" "$2"
}

# _api_patch <url> <json_body>
# Authenticated PATCH request with JSON body.
_api_patch() {
  _http_request PATCH "$1" "$2"
}

# _api_delete <url>
# Authenticated DELETE request.
_api_delete() {
  _http_request DELETE "$1"
}

# _read_http_code — read HTTP_CODE from file (use after subshell calls)
_read_http_code() {
  if [[ -f "$_LIB_HTTP_CODE_FILE" ]]; then
    read -r HTTP_CODE < "$_LIB_HTTP_CODE_FILE"
  fi
}

# --- Status Checking ---

# _check_http_status <code> <body> <action_description>
# Checks HTTP status code and outputs error JSON to stderr if not successful.
# 200/201 → success. 204 → success (no content). 207 → success (multi-status).
# Returns 0 on success, 1 on any error.
_check_http_status() {
  local http_code="$1"
  local body="$2"
  local action="$3"

  if ! [[ "$http_code" =~ ^[0-9]+$ ]]; then
    echo "{\"error\":\"${action} failed (invalid HTTP response)\"}" >&2
    return 1
  fi

  # Success codes
  if [[ "$http_code" -eq 200 || "$http_code" -eq 201 ]]; then
    return 0
  fi
  if [[ "$http_code" -eq 204 ]]; then
    return 0
  fi
  if [[ "$http_code" -eq 207 ]]; then
    return 0
  fi

  # Error codes with specific messages
  local msg=""
  case "$http_code" in
    400)
      msg=$(echo "$body" | jq -r '.message // .error // empty' 2>/dev/null)
      if [[ -z "$msg" ]]; then
        msg="Bad request"
      fi
      ;;
    403)
      msg="Check API key and permissions"
      ;;
    404)
      msg="Resource not found"
      ;;
    422)
      msg=$(echo "$body" | jq -r '.message // .error // empty' 2>/dev/null)
      if [[ -z "$msg" ]]; then
        msg="Unprocessable entity"
      fi
      ;;
    429)
      msg="Rate limit exceeded"
      ;;
    *)
      if [[ "$http_code" -ge 500 ]]; then
        msg="Alpaca API error"
      else
        msg=$(echo "$body" | jq -r '.message // .error // empty' 2>/dev/null)
        if [[ -z "$msg" ]]; then
          msg="Unexpected error"
        fi
      fi
      ;;
  esac

  echo "{\"error\":\"${action} failed (HTTP ${http_code}): ${msg}\"}" >&2
  return 1
}

# --- Argument Parsing ---

# _parse_flag <flag_name> <args...>
# Returns the value following the named flag, or empty string if not found.
_parse_flag() {
  local flag="$1"
  shift
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "$flag" && $# -gt 1 ]]; then
      echo "$2"
      return 0
    fi
    shift
  done
  echo ""
}

# _has_flag <flag_name> <args...>
# Returns 0 if the flag is present in args, 1 otherwise.
_has_flag() {
  local flag="$1"
  shift
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "$flag" ]]; then
      return 0
    fi
    shift
  done
  return 1
}

# _require_arg <name> <value> <command>
# Validates that a required argument is present. Exits with error if not.
_require_arg() {
  local name="$1"
  local value="$2"
  local command="$3"
  if [[ -z "$value" ]]; then
    echo "{\"error\":\"${command} requires: <${name}>\"}" >&2
    exit 1
  fi
}

# --- Output ---

# _json_output <body>
# Outputs pretty-printed JSON if stdout is a terminal, raw otherwise.
# Skips jq re-parse when piped (API already returns valid JSON).
_json_output() {
  if [[ -t 1 ]]; then
    echo "$1" | jq '.'
  else
    echo "$1"
  fi
}

# _usage <script_name> <description> <usage_text>
# Prints usage info and exits.
_usage() {
  local script="$1"
  local desc="$2"
  local usage="$3"
  cat >&2 <<EOF
${script} — ${desc}

Usage:
${usage}

Requires: APCA_API_KEY_ID and APCA_API_SECRET_KEY environment variables
EOF
  exit 1
}

# --- Convenience Wrappers ---

# _fetch_and_output <action> <url>
# Makes an API GET request, checks status, and outputs JSON. Exits 1 on error.
_fetch_and_output() {
  local action="$1"
  local url="$2"
  local body
  body=$(_api_get "$url")
  _read_http_code
  _check_http_status "$HTTP_CODE" "$body" "$action" || exit 1
  _json_output "$body"
}

# _paginate <url> [max_pages]
# Follows next_page_token pagination, collecting results into a JSON array.
# Appends page_token=<value> to URL for subsequent pages.
# Stops at max_pages (default: LIB_MAX_PAGES) to prevent runaway requests.
# NO EVAL — uses two separate jq -r calls.
_paginate() {
  local url="$1"
  local max_pages="${2:-$LIB_MAX_PAGES}"
  local page=0
  local current_url="$url"
  local tmpfile
  tmpfile=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$tmpfile'" RETURN

  while [[ -n "$current_url" && "$page" -lt "$max_pages" ]]; do
    local body
    body=$(_api_get "$current_url")
    _read_http_code

    if ! _check_http_status "$HTTP_CODE" "$body" "paginate"; then
      echo "$body"
      rm -f "$tmpfile"
      return 1
    fi

    # Extract page results — use jq to get array content
    echo "$body" | jq -c '
      if type == "array" then .
      elif .results then .results
      elif .activities then .activities
      elif .orders then .orders
      elif .positions then .positions
      elif .bars then (.bars | if type == "object" then [to_entries[].value[]] else . end)
      elif .trades then (.trades | if type == "object" then [to_entries[].value[]] else . end)
      elif .quotes then (.quotes | if type == "object" then [to_entries[].value[]] else . end)
      elif .news then .news
      elif .snapshots then .snapshots
      elif .corporate_actions then .corporate_actions
      else [.]
      end // []
    ' >> "$tmpfile" 2>/dev/null

    # Extract next_page_token with a separate jq call (NO EVAL)
    local next_token
    next_token=$(echo "$body" | jq -r '.next_page_token // empty' 2>/dev/null)

    if [[ -n "$next_token" ]]; then
      # Append page_token to URL
      if [[ "$url" == *"?"* ]]; then
        current_url="${url}&page_token=${next_token}"
      else
        current_url="${url}?page_token=${next_token}"
      fi
    else
      current_url=""
    fi

    page=$((page + 1))
  done

  # Merge all pages in one pass
  local all_results count
  all_results=$(jq -s 'add // []' "$tmpfile")
  count=$(echo "$all_results" | jq 'length')
  rm -f "$tmpfile"
  echo "{\"count\":${count},\"results\":${all_results}}"
}

# _paginate_and_output <url>
# Paginates an endpoint and outputs combined JSON. Exits 1 on error.
_paginate_and_output() {
  local url="$1"
  local body
  body=$(_paginate "$url") || exit 1
  _json_output "$body"
}

# --- Initialization (runs on source) ---

_require_api_key
[[ -d "$LIB_CONFIG_DIR" ]] || mkdir -p "$LIB_CONFIG_DIR" 2>/dev/null
