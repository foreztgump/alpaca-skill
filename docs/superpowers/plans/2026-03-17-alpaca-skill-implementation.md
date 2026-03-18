# Alpaca Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 15 files (2 shared libraries + 12 domain scripts + 1 formatter) wrapping the Alpaca Markets REST API v2 for stock/crypto/options trading, market data, news, screener, and corporate actions.

**Architecture:** Flat scripts with shared libraries following the massive-skill pattern. `_lib.sh` provides HTTP primitives (separate `_api_get`/`_api_post`/`_api_patch`/`_api_delete`), auth, pagination. `_data_lib.sh` provides shared market data helpers for stocks/crypto. Domain scripts are thin wrappers. `alpaca_format.sh` handles human-readable output.

**Tech Stack:** Bash, curl, jq. No external dependencies.

**Conventions:**
- All domain scripts MUST use `set -euo pipefail` after the shebang
- `_http_request` is private — domain scripts call only `_api_get`/`_api_post`/`_api_patch`/`_api_delete`
- Run `shellcheck` after each task, not just at the end

**Spec:** `docs/superpowers/specs/2026-03-17-alpaca-skill-design.md`
**Reference:** `/home/cownose/projects/massive-skill/scripts/` (proven pattern to follow)

---

## File Structure

| File | Responsibility |
|------|----------------|
| `scripts/_lib.sh` | HTTP primitives, auth headers, URL building, pagination, flag parsing, error handling |
| `scripts/_data_lib.sh` | Shared market data helpers (bars, trades, quotes, snapshots, latest) for stock/crypto |
| `scripts/alpaca_account.sh` | Account info, portfolio history, config, activities |
| `scripts/alpaca_orders.sh` | Submit/list/get/cancel/replace orders, bracket orders, dry-run |
| `scripts/alpaca_positions.sh` | List/get/close positions |
| `scripts/alpaca_assets.sh` | Asset lookup, search |
| `scripts/alpaca_market.sh` | Market clock, trading calendar |
| `scripts/alpaca_data_stocks.sh` | Stock bars/trades/quotes/snapshots/latest (thin wrapper over `_data_lib.sh`) |
| `scripts/alpaca_data_crypto.sh` | Crypto bars/trades/quotes/snapshots/latest/orderbook (thin wrapper + orderbook) |
| `scripts/alpaca_data_options.sh` | Options bars/trades/snapshots/chain/latest (standalone, different API pattern) |
| `scripts/alpaca_news.sh` | News articles |
| `scripts/alpaca_screener.sh` | Most active stocks, top market movers |
| `scripts/alpaca_corporate_actions.sh` | Corporate actions (dividends, splits, mergers) |
| `scripts/alpaca_watchlists.sh` | Watchlist CRUD |
| `scripts/alpaca_format.sh` | JSON formatter (no API calls) |
| `tests/test_lib.sh` | Tests for `_lib.sh` |
| `tests/test_orders.sh` | Tests for order body construction and validation |
| `tests/test_format.sh` | Tests for formatter |
| `tests/run_tests.sh` | Test runner |
| `references/api-reference.md` | Alpaca API endpoint reference doc |

---

### Task 1: Test Framework & `_lib.sh` Core

**Files:**
- Create: `tests/run_tests.sh`
- Create: `tests/test_lib.sh`
- Create: `scripts/_lib.sh`

- [ ] **Step 1: Create the test runner**

```bash
#!/usr/bin/env bash
# tests/run_tests.sh — Discover and run all test_*.sh files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

PASS=0
FAIL=0
ERRORS=""

for test_file in "${SCRIPT_DIR}"/test_*.sh; do
  [[ -f "$test_file" ]] || continue
  test_name=$(basename "$test_file")
  if bash "$test_file"; then
    PASS=$((PASS + 1))
    echo "  PASS  $test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}\n"
    echo "  FAIL  $test_name"
  fi
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailed tests:\n${ERRORS}"
  exit 1
fi
```

- [ ] **Step 2: Write failing tests for `_lib.sh` core functions**

Create `tests/test_lib.sh` with tests for:
- `_require_api_key` — exits 1 when env vars missing
- `_build_url` — builds URL with base, path, and query params, skips empty values
- `_urlencode` — encodes special characters
- `_parse_flag` — extracts flag value
- `_has_flag` — detects flag presence
- `_require_arg` — exits 1 on missing arg
- `_check_http_status` — returns 0 for 200/201/204/207, returns 1 for 400/403/404/422/429/500

Each test follows this pattern:
```bash
test_name() {
  # Arrange
  local input="..."
  # Act
  local result=$(function "$input")
  local exit_code=$?
  # Assert
  [[ "$result" == "expected" ]] || { echo "FAIL: test_name: got '$result'" >&2; return 1; }
}
```

The test file must mock `curl` and set `APCA_API_KEY_ID`/`APCA_API_SECRET_KEY` env vars before sourcing `_lib.sh`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `bash tests/run_tests.sh`
Expected: FAIL (scripts/_lib.sh does not exist)

- [ ] **Step 4: Implement `_lib.sh`**

Create `scripts/_lib.sh` with all functions from the spec:
- Constants: `LIB_TRADING_URL` (resolved from `APCA_PAPER`), `LIB_DATA_URL`, `LIB_CONFIG_DIR`, `LIB_MAX_PAGES=10`, `HTTP_TIMEOUT` (from `APCA_TIMEOUT` or default 15)
- `_require_api_key` — validate both env vars
- `_urlencode` — URL-encode string (same char-by-char approach as massive-skill)
- `_build_url <base> <path> [query_params...]` — build URL, skip empty values. **Key difference from massive-skill:** takes `base` as first param instead of using global
- `_http_request <method> <url> [json_body]` — private, does curl with `APCA-API-KEY-ID` and `APCA-API-SECRET-KEY` headers, extracts HTTP code via `curl -w "\n%{http_code}"`, writes code to temp file
- `_api_get <url>` — calls `_http_request GET`
- `_api_post <url> <json_body>` — calls `_http_request POST`
- `_api_patch <url> <json_body>` — calls `_http_request PATCH`
- `_api_delete <url>` — calls `_http_request DELETE`
- `_read_http_code` — read HTTP code from temp file
- `_check_http_status <code> <body> <action>` — handle 200/201/204/207 as success, 400/403/404/422/429/5xx as errors with JSON error on stderr
- `_parse_flag`, `_has_flag`, `_require_arg` — from massive-skill
- `_json_output` — pretty-print if terminal
- `_usage` — help text
- `_fetch_and_output <action> <url>` — GET + check + output
- `_paginate <url> [max_pages]` — follows `next_page_token` in response, appends `page_token=` to URL, collects results into array. Uses two `jq -r` calls (not eval). Stops at `LIB_MAX_PAGES`.
- `_paginate_and_output <url>` — convenience: `_paginate` + `_json_output` (avoids repeating this combo in domain scripts)
- Initialization: validate keys, resolve trading URL, create config dir

Reference: `/home/cownose/projects/massive-skill/scripts/_lib.sh` for exact patterns. Adapt `_build_url` to take `base` param, `_paginate` to use `next_page_token` instead of `next_url`, and add POST/PATCH/DELETE functions.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: PASS for all `_lib.sh` tests

- [ ] **Step 6: Run shellcheck**

```bash
shellcheck scripts/_lib.sh
```

Fix any issues before proceeding.

- [ ] **Step 7: Commit**

```bash
git add scripts/_lib.sh tests/run_tests.sh tests/test_lib.sh
git commit -m "feat(lib): add shared HTTP primitives, auth, pagination, and test framework"
```

---

### Task 2: `_data_lib.sh` — Shared Market Data Helpers

**Files:**
- Create: `scripts/_data_lib.sh`
- Create: `tests/test_data_lib.sh`

- [ ] **Step 1: Write failing tests for `_data_lib.sh`**

Create `tests/test_data_lib.sh` with tests for:
- URL construction: `_data_bars` with `--start`, `--end`, `--timeframe` produces correct URL
- URL construction: `_data_trades` with `--start`, `--sort desc` produces correct URL
- Flag passthrough: `--feed sip` appears in URL, `--currency` appears in URL
- `--start` validation: `_data_bars` without `--start` → exit 1
- Crypto symbol encoding: `BTC/USD` → `BTC%2FUSD` in URL path
- Pagination token: mock response with `next_page_token` → second request includes `page_token=`

Mock `curl` to capture the URL passed to it and assert correct structure.

- [ ] **Step 2: Implement `_data_lib.sh`**

Sources `_lib.sh`. Implements 8 functions, each taking `base_path` as first param.

All paginated functions (`_data_bars`, `_data_trades`, `_data_quotes`) validate that `--start` is provided via `_require_arg`.

All functions parse both `--feed` and `--currency` — empty values are skipped by `_build_url`. This keeps the shared library consistent; calling scripts decide which flags to pass.

Functions:
- `_data_bars <base_path> <symbol> [flags...]` — builds URL `{LIB_DATA_URL}{base_path}/{symbol}/bars`, parses `--start`, `--end`, `--timeframe` (default 1Day), `--limit`, `--sort`, `--feed`, `--currency`, auto-paginates via `_paginate_and_output`
- `_data_trades <base_path> <symbol> [flags...]` — `{base_path}/{symbol}/trades`, parses `--start`, `--end`, `--limit`, `--sort`, `--feed`, `--currency`, auto-paginates
- `_data_quotes <base_path> <symbol> [flags...]` — `{base_path}/{symbol}/quotes`, parses `--start`, `--end`, `--limit`, `--sort`, `--feed`, `--currency`, auto-paginates
- `_data_snapshot <base_path> <symbol> [flags...]` — `{base_path}/{symbol}/snapshot`, parses `--feed`, `--currency`, single request
- `_data_snapshots <base_path> <symbols_csv> [flags...]` — `{base_path}/snapshots?symbols={csv}`, parses `--feed`, `--currency`, single request
- `_data_latest_trade <base_path> <symbol>` — `{base_path}/{symbol}/trades/latest`
- `_data_latest_quote <base_path> <symbol>` — `{base_path}/{symbol}/quotes/latest`
- `_data_latest_bar <base_path> <symbol>` — `{base_path}/{symbol}/bars/latest`

Each function: parse flags → build URL via `_build_url "$LIB_DATA_URL" "$path" "params..."` → `_fetch_and_output` or `_paginate_and_output`.

- [ ] **Step 3: Run tests to verify they pass**

Run: `bash tests/test_data_lib.sh`
Expected: PASS

- [ ] **Step 4: Run shellcheck**

```bash
shellcheck scripts/_data_lib.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/_data_lib.sh tests/test_data_lib.sh
git commit -m "feat(data-lib): add shared market data helpers for bars, trades, quotes, snapshots"
```

---

### Task 3: `alpaca_account.sh`

**Files:**
- Create: `scripts/alpaca_account.sh`

- [ ] **Step 1: Implement `alpaca_account.sh`**

Follow the massive-skill script pattern exactly (see `massive_price.sh`):
- Shebang, `SCRIPT_DIR`, source `_lib.sh`
- `show_help` using `_usage`
- `cmd_info` — `_fetch_and_output "account" "$(_build_url "$LIB_TRADING_URL" "/v2/account")"`
- `cmd_history` — parse `--period`, `--timeframe`, `--date-end`, `--extended-hours` → build URL → `_fetch_and_output`
- `cmd_config` — `_fetch_and_output "config" "$(_build_url "$LIB_TRADING_URL" "/v2/account/configurations")"`
- `cmd_activities` — two modes: positional `<type>` → `/v2/account/activities/{type}`, or flags only → `/v2/account/activities`. Parse `--activity-type`, `--date`, `--after`, `--until`, `--direction`, `--page-size`. Paginated.
- Main dispatch: `case "$subcommand" in info|history|config|activities|help ...`

- [ ] **Step 2: Make executable and test manually**

```bash
chmod +x scripts/alpaca_account.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/alpaca_account.sh
git commit -m "feat(account): add account info, portfolio history, config, activities"
```

---

### Task 4: `alpaca_orders.sh`

**Files:**
- Create: `scripts/alpaca_orders.sh`
- Create: `tests/test_orders.sh`

- [ ] **Step 1: Write failing tests for order body construction**

Create `tests/test_orders.sh` with tests for:
- Market order body (with `--qty`)
- Market order body (with `--notional`)
- Limit order body (with `--limit-price`)
- Stop order body (with `--stop-price`)
- Stop-limit order body
- Trailing stop with `--trail-percent`
- Bracket order (with `--take-profit` and `--stop-loss`)
- Validation: missing `--limit-price` for limit order → exit 1
- Validation: both `--qty` and `--notional` → exit 1
- Validation: neither `--qty` nor `--notional` → exit 1
- Crypto validation: `BTC/USD` with `stop` type → exit 1 with warning
- Crypto validation: `BTC/USD` with `day` TIF → exit 1 with warning
- Dry-run mode outputs JSON without POSTing
- Error path: mock curl 422 with `{"message": "insufficient qty"}` → stderr error
- Error path: mock curl 429 → stderr rate limit message

Tests mock `curl` and call functions directly after sourcing the script.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test_orders.sh`
Expected: FAIL

- [ ] **Step 3: Implement `alpaca_orders.sh`**

The most complex script. Decompose `cmd_submit` into 3 functions to stay under 40 lines each:
- `_validate_order_params` — checks per-type requirements, crypto restrictions, qty/notional exclusivity
- `_build_order_body` — constructs JSON via single `jq -n` call
- `cmd_submit` — orchestrates: parse flags → validate → build body → dry-run check → POST

Subcommands:
- `cmd_list [flags...]` — Parse `--status`, `--limit`, `--after`, `--until`, `--direction`, `--nested`, `--symbols` → paginated GET
- `cmd_get <order_id>` — `_fetch_and_output`
- `cmd_get_by_client_id <client_order_id>` — `_fetch_and_output` with URL `/v2/orders:by_client_order_id?client_order_id=...`
- `cmd_cancel <order_id>` — `_api_delete` + `_check_http_status`
- `cmd_cancel_all` — `_api_delete` on `/v2/orders`, custom handling for 207
- `cmd_replace <order_id> [flags...]` — Parse `--qty`, `--limit-price`, `--stop-price`, `--trail`, `--time-in-force` → build JSON → `_api_patch`

**JSON body construction** uses a single `jq -n` call with conditional field addition (avoids multiple subshell forks):
```bash
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
```

**Crypto order validation** detects crypto symbols (contain `/`) and rejects unsupported types/TIF:
```bash
_validate_order_params() {
  # ... qty/notional/type checks ...
  # Crypto restrictions
  if [[ "$symbol" == *"/"* ]]; then
    case "$order_type" in
      stop|trailing_stop)
        echo '{"error":"crypto does not support order type: '"$order_type"'. Use market, limit, or stop_limit."}' >&2
        return 1 ;;
    esac
    case "$time_in_force" in
      day|opg|cls|fok)
        echo '{"error":"crypto does not support time_in_force: '"$time_in_force"'. Use gtc or ioc."}' >&2
        return 1 ;;
    esac
  fi
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test_orders.sh`
Expected: PASS

- [ ] **Step 5: Run shellcheck**

```bash
shellcheck scripts/alpaca_orders.sh
```

- [ ] **Step 6: Commit**

```bash
git add scripts/alpaca_orders.sh tests/test_orders.sh
git commit -m "feat(orders): add order submit, list, get, cancel, replace with validation"
```

---

### Task 5: `alpaca_positions.sh`

**Files:**
- Create: `scripts/alpaca_positions.sh`

- [ ] **Step 1: Implement `alpaca_positions.sh`**

Simple script with 4 subcommands:
- `cmd_list` — `_fetch_and_output "positions" "$(_build_url "$LIB_TRADING_URL" "/v2/positions")"`
- `cmd_get <symbol>` — `_fetch_and_output "position" "$(_build_url "$LIB_TRADING_URL" "/v2/positions/$symbol")"`
- `cmd_close <symbol> [flags]` — Parse `--qty`, `--percentage` → `_api_delete` on `/v2/positions/{symbol}?qty=&percentage=`
- `cmd_close_all` — `_api_delete` on `/v2/positions`, handle 207 multi-status

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/alpaca_positions.sh
git add scripts/alpaca_positions.sh
git commit -m "feat(positions): add list, get, close, close-all"
```

---

### Task 6: `alpaca_assets.sh` & `alpaca_market.sh`

**Files:**
- Create: `scripts/alpaca_assets.sh`
- Create: `scripts/alpaca_market.sh`

- [ ] **Step 1: Implement `alpaca_assets.sh`**

Two subcommands:
- `cmd_get <symbol>` — `_fetch_and_output`
- `cmd_list [flags]` — Parse `--status`, `--asset-class`, `--exchange`, `--limit` → `_fetch_and_output` (no pagination). If `--limit` set, pipe through `jq '.[0:N]'`.

- [ ] **Step 2: Implement `alpaca_market.sh`**

Two subcommands:
- `cmd_clock` — `_fetch_and_output "clock" "$(_build_url "$LIB_TRADING_URL" "/v2/clock")"`
- `cmd_calendar [flags]` — Parse `--start`, `--end` → `_fetch_and_output`

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/alpaca_assets.sh scripts/alpaca_market.sh
git add scripts/alpaca_assets.sh scripts/alpaca_market.sh
git commit -m "feat(assets,market): add asset lookup, search, clock, calendar"
```

---

### Task 7: `alpaca_data_stocks.sh` & `alpaca_data_crypto.sh`

**Files:**
- Create: `scripts/alpaca_data_stocks.sh`
- Create: `scripts/alpaca_data_crypto.sh`

- [ ] **Step 1: Implement `alpaca_data_stocks.sh`**

Thin wrapper over `_data_lib.sh`. Source both `_lib.sh` and `_data_lib.sh`.
Set `readonly BASE_PATH="/v2/stocks"`.
Dispatch: `bars`, `trades`, `quotes`, `snapshot`, `snapshots`, `latest-trade`, `latest-quote`, `latest-bar` → delegate to `_data_*` functions passing `"$BASE_PATH"` and forwarding remaining args. Pass `--feed` flag through.

- [ ] **Step 2: Implement `alpaca_data_crypto.sh`**

Same structure but with `readonly BASE_PATH="/v1beta3/crypto/us"`.
Add `_normalize_crypto_symbol` helper that ensures slash format (adds `/USD` if missing, e.g., `BTC` → `BTC/USD`).
Add `cmd_orderbook <symbol>` — direct `_api_get` on `${LIB_DATA_URL}/v1beta3/crypto/us/latest/orderbooks?symbols=$(_urlencode "$symbol")`.
Pass `--currency` flag through.

- [ ] **Step 3: Make executable and commit**

```bash
chmod +x scripts/alpaca_data_stocks.sh scripts/alpaca_data_crypto.sh
git add scripts/alpaca_data_stocks.sh scripts/alpaca_data_crypto.sh
git commit -m "feat(data): add stock and crypto market data scripts"
```

---

### Task 8: `alpaca_data_options.sh`

**Files:**
- Create: `scripts/alpaca_data_options.sh`

- [ ] **Step 1: Implement `alpaca_data_options.sh`**

Standalone (no `_data_lib.sh` — different API pattern). Sources `_lib.sh` only.
Base path: `/v1beta1/options`.

Subcommands:
- `cmd_bars <symbol> [flags]` — `GET /v1beta1/options/bars?symbols={symbol}&start=&end=&timeframe=&limit=&sort=`. Paginated.
- `cmd_trades <symbol> [flags]` — `GET /v1beta1/options/trades?symbols={symbol}&...`. Paginated.
- `cmd_latest_quote <symbol>` — `GET /v1beta1/options/quotes/latest?symbols={symbol}`
- `cmd_latest_trade <symbol>` — `GET /v1beta1/options/trades/latest?symbols={symbol}`
- `cmd_snapshot <symbol>` — `GET /v1beta1/options/snapshots/{symbol}`
- `cmd_snapshots [flags]` — `GET /v1beta1/options/snapshots?symbols={csv}`. Paginated.
- `cmd_chain <underlying> [flags]` — `GET /v1beta1/options/snapshots/{underlying}?...`. Parse `--expiration-date`, `--type`, `--strike-price-gte`, `--strike-price-lte`, `--root-symbol`. Paginated.

Key difference: options use multi-symbol query params (`?symbols=X`) rather than per-symbol paths for bars/trades.

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/alpaca_data_options.sh
git add scripts/alpaca_data_options.sh
git commit -m "feat(options): add options market data with chain, bars, trades, snapshots"
```

---

### Task 9: `alpaca_news.sh`, `alpaca_screener.sh`, `alpaca_corporate_actions.sh`

**Files:**
- Create: `scripts/alpaca_news.sh`
- Create: `scripts/alpaca_screener.sh`
- Create: `scripts/alpaca_corporate_actions.sh`

- [ ] **Step 1: Implement `alpaca_news.sh`**

Single subcommand `list`. Source `_lib.sh`.
Parse: `--symbols`, `--start`, `--end`, `--limit`, `--sort`, `--include-content`, `--exclude-contentless`.
URL: `${LIB_DATA_URL}/v1beta1/news?...`. Paginated via `page_token`.

- [ ] **Step 2: Implement `alpaca_screener.sh`**

Two subcommands:
- `cmd_most_active [flags]` — Parse `--by` (volume/trades), `--top`. URL: `${LIB_DATA_URL}/v1beta1/screener/stocks/most-actives?by=&top=`
- `cmd_movers [flags]` — Parse `--market-type` (default stocks), `--top`. URL: `${LIB_DATA_URL}/v1beta1/screener/{market_type}/movers?top=`

- [ ] **Step 3: Implement `alpaca_corporate_actions.sh`**

Single subcommand `list`. Source `_lib.sh`.
Parse: `--symbols`, `--types`, `--date-from`, `--date-to`, `--limit`, `--sort`.
URL: `${LIB_DATA_URL}/v1beta1/corporate-actions?...`. Paginated.

- [ ] **Step 4: Make executable and commit**

```bash
chmod +x scripts/alpaca_news.sh scripts/alpaca_screener.sh scripts/alpaca_corporate_actions.sh
git add scripts/alpaca_news.sh scripts/alpaca_screener.sh scripts/alpaca_corporate_actions.sh
git commit -m "feat(news,screener,corp-actions): add news, most active, movers, corporate actions"
```

---

### Task 10: `alpaca_watchlists.sh`

**Files:**
- Create: `scripts/alpaca_watchlists.sh`

- [ ] **Step 1: Implement `alpaca_watchlists.sh`**

6 subcommands:
- `cmd_list` — `_fetch_and_output`
- `cmd_get <id>` — `_fetch_and_output`
- `cmd_create <name> [--symbols CSV]` — Build JSON `{"name": "...", "symbols": [...]}` via `jq -n`. `_api_post`.
- `cmd_add_symbol <id> <symbol>` — Build JSON `{"symbol": "..."}`. `_api_post` on `/v2/watchlists/{id}`.
- `cmd_remove_symbol <id> <symbol>` — `_api_delete` on `/v2/watchlists/{id}/{symbol}`
- `cmd_delete <id>` — `_api_delete` on `/v2/watchlists/{id}`

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/alpaca_watchlists.sh
git add scripts/alpaca_watchlists.sh
git commit -m "feat(watchlists): add watchlist CRUD"
```

---

### Task 11: `alpaca_format.sh`

**Files:**
- Create: `scripts/alpaca_format.sh`
- Create: `tests/test_format.sh`

- [ ] **Step 1: Write failing tests for key formatter types**

Create `tests/test_format.sh` with tests covering one type per output shape:
- Key-value shape: `--type account --format summary` — expected key-value output
- Key-value shape: `--type clock --format summary` — is_open, next_open, next_close
- Table shape: `--type orders --format summary` — expected table with columns
- Table shape: `--type positions --format summary` — symbol, qty, unrealized_pl
- OHLCV shape: `--type bars --format csv` — expected CSV with header
- Ranked list shape: `--type movers --format summary` — ranked by change percent
- News shape: `--type news --format summary` — headline, source, symbols
- Full format: `--type account --format full` — pretty JSON passthrough
- `--top 3` limits output to 3 items
- Invalid type → exit 1
- No input → exit 1

Each test pipes canned JSON into the formatter and asserts output.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/test_format.sh`
Expected: FAIL

- [ ] **Step 3: Implement `alpaca_format.sh`**

Follow the exact same structure as `/home/cownose/projects/massive-skill/scripts/massive_format.sh`:
- No `_lib.sh` sourcing, standalone
- Argument parsing: `--type`, `--format` (summary/full/csv), `--top N`, file arg
- Validate type against: `account`, `activities`, `orders`, `positions`, `assets`, `bars`, `trades`, `quotes`, `snapshot`, `watchlists`, `calendar`, `clock`, `news`, `movers`, `options`, `option-chain`, `corporate-actions`, `orderbook`
- Read input from stdin or file
- `_extract_results` — handle Alpaca response shapes (array at root, or nested in known keys)
- `_apply_top` — jq slicing
- Full format → `jq '.'`
- Per-type summary/csv formatters

Key formatters:
- `account` summary: key-value display of equity, cash, buying_power, portfolio_value, etc.
- `orders` summary: table with symbol, side, type, qty, status, submitted_at
- `positions` summary: table with symbol, qty, avg_entry_price, current_price, unrealized_pl
- `bars` summary: reuse massive-skill's bars formatter (timestamp, OHLCV)
- `clock` summary: is_open, timestamp, next_open, next_close
- `news` summary: headline, source, created_at, symbols
- `movers` summary: ranked list with symbol, price, change percent

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test_format.sh`
Expected: PASS

- [ ] **Step 5: Make executable and commit**

```bash
chmod +x scripts/alpaca_format.sh
git add scripts/alpaca_format.sh tests/test_format.sh
git commit -m "feat(format): add JSON formatter with 18 types, summary/full/csv formats"
```

---

### Task 12: API Reference & Final Integration

**Files:**
- Create: `references/api-reference.md`
- Modify: `SKILL.md` (minor — verify all scripts listed)
- Modify: `README.md` (update script count)

- [ ] **Step 1: Generate `references/api-reference.md`**

Create a concise API reference doc listing all Alpaca endpoints used by the skill. Grouped by script. For each endpoint: method, path, query params, response shape. This is for the agent to consult when SKILL.md isn't enough.

- [ ] **Step 2: Make all scripts executable**

```bash
chmod +x scripts/*.sh
```

- [ ] **Step 3: Run shellcheck on all scripts**

```bash
shellcheck scripts/*.sh
```

Fix any issues.

- [ ] **Step 4: Run full test suite**

```bash
bash tests/run_tests.sh
```

Expected: All PASS.

- [ ] **Step 5: Update README with final script count and features**

Update README.md to reflect all 15 scripts and the full feature list.

- [ ] **Step 6: Commit**

```bash
git add references/api-reference.md scripts/*.sh README.md SKILL.md
git commit -m "docs: add API reference, finalize scripts, update README"
```

---

### Task 13: Integration Test with Paper Account

**Files:**
- None created (manual verification)

- [ ] **Step 1: Set paper trading credentials**

```bash
export APCA_API_KEY_ID=<your_paper_key>
export APCA_API_SECRET_KEY=<your_paper_secret>
export APCA_PAPER=true
```

- [ ] **Step 2: Smoke test each script**

Run each script with a basic subcommand and verify JSON output:
```bash
scripts/alpaca_account.sh info
scripts/alpaca_market.sh clock
scripts/alpaca_market.sh calendar --start 2026-03-01 --end 2026-03-31
scripts/alpaca_assets.sh get AAPL
scripts/alpaca_data_stocks.sh snapshot AAPL
scripts/alpaca_data_stocks.sh latest-trade AAPL
scripts/alpaca_data_crypto.sh snapshot BTC/USD
scripts/alpaca_data_options.sh chain AAPL
scripts/alpaca_news.sh list --limit 5
scripts/alpaca_screener.sh most-active
scripts/alpaca_screener.sh movers
scripts/alpaca_positions.sh list
scripts/alpaca_orders.sh list --status all --limit 5
scripts/alpaca_watchlists.sh list
```

- [ ] **Step 3: Test order flow (paper)**

```bash
# Place a market order
scripts/alpaca_orders.sh submit AAPL buy market --qty 1
# Check it
scripts/alpaca_orders.sh list --status open
# Check position
scripts/alpaca_positions.sh list
# Close it
scripts/alpaca_positions.sh close AAPL
```

- [ ] **Step 4: Test format pipeline**

```bash
scripts/alpaca_account.sh info | scripts/alpaca_format.sh --type account
scripts/alpaca_data_stocks.sh bars AAPL --start 2026-03-01 --end 2026-03-15 | scripts/alpaca_format.sh --type bars
scripts/alpaca_screener.sh movers | scripts/alpaca_format.sh --type movers
```

- [ ] **Step 5: Fix any issues found and commit**

```bash
git add -A
git commit -m "fix: address issues found during integration testing"
```
