# Alpaca Skill Design Spec

## Overview

Claude Agent Skill wrapping Alpaca Markets REST API v2 for stock and crypto trading. Pure bash (curl+jq) following the Agent Skills open standard. Enables AI agents to place/manage orders, check positions, view account info, and query market data.

## Architecture

**Pattern:** Flat scripts with shared libraries, same as massive-skill. Each script is standalone, sources `_lib.sh`, uses subcommand dispatch.

**Files:**
- `_lib.sh` — HTTP primitives, auth, pagination, flag parsing
- `_data_lib.sh` — shared market data helpers (bars, trades, quotes, snapshots)
- 8 domain scripts — thin wrappers over the libraries
- `alpaca_format.sh` — local JSON formatter, no API calls

**Key design decision:** Separate `_api_get`, `_api_post`, `_api_patch`, `_api_delete` functions rather than a generic `_api_request`. All delegate to a private `_http_request`. This makes destructive operations visible during code review and allows per-method success code handling.

**Key design decision:** Extract `_data_lib.sh` for shared market data patterns since stock and crypto data scripts have identical subcommands (bars, trades, quotes, snapshot, latest) differing only in URL prefix (`/v2/stocks` vs `/v1beta3/crypto/us`). All other scripts stay flat.

## `_lib.sh` — HTTP Primitives & Auth

### Constants

| Constant | Value | Notes |
|----------|-------|-------|
| `LIB_TRADING_URL` | `https://paper-api.alpaca.markets` or `https://api.alpaca.markets` | Resolved from `APCA_PAPER` env var (default: `true`) |
| `LIB_DATA_URL` | `https://data.alpaca.markets` | Always the same for both paper and live |
| `LIB_CONFIG_DIR` | `~/.config/alpaca-skill/` | Only local write location |
| `LIB_MAX_PAGES` | `10` | Pagination cap |
| `HTTP_TIMEOUT` | `15` | curl timeout in seconds (configurable via `APCA_TIMEOUT` env var) |

### Core HTTP Functions

**`_http_request <method> <url> [json_body]`** (private)
- Performs curl with auth headers: `APCA-API-KEY-ID` and `APCA-API-SECRET-KEY`
- Extracts HTTP status code and response body using `curl -w "\n%{http_code}"`
- Writes HTTP code to temp file for subshell access (same pattern as massive-skill)
- Sets `Content-Type: application/json` for POST/PATCH
- Uses `-m $HTTP_TIMEOUT` for all requests

**`_api_get <url>`** — GET, expects 200
**`_api_post <url> <json_body>`** — POST, expects 200/201
**`_api_patch <url> <json_body>`** — PATCH, expects 200
**`_api_delete <url>`** — DELETE, expects 200/204

### Status Checking

**`_check_http_status <code> <body> <action>`**

| HTTP Code | Behavior |
|-----------|----------|
| 200, 201 | Return 0 (success) |
| 204 | Return 0, output `{"status":"ok"}` |
| 207 | Return 0, output body as-is (multi-status for bulk cancel/close — caller interprets per-item results) |
| 400 | Extract `message` from body, error on stderr |
| 403 | "Check API key and permissions" on stderr |
| 404 | "Resource not found" on stderr |
| 422 | Extract `message` — invalid order params, market closed, etc. |
| 429 | "Rate limit exceeded, try again later" on stderr |
| 5xx | "Alpaca API error" on stderr |

All errors exit 1 with JSON error object on stderr. No automatic retries.

### Utilities (from massive-skill pattern)

- `_build_url <base> <path> [query_params...]` — builds URL, skips empty values
- `_urlencode <string>` — URL-encode for query params and path segments
- `_parse_flag <flag> <args...>` — extract value after named flag
- `_has_flag <flag> <args...>` — check flag presence
- `_require_arg <name> <value> <command>` — validate required positional arg
- `_json_output <body>` — pretty-print if terminal, raw if piped
- `_usage <script> <desc> <usage_text>` — print help and exit
- `_fetch_and_output <action> <url>` — GET + check + output shorthand
- `_paginate <url> [max_pages]` — follows `next_page_token`, collects into array

### Pagination

Alpaca uses `next_page_token` in response body → pass as `page_token` query param on next request. The `_paginate` function:
1. Makes initial request
2. Checks for `next_page_token` in response
3. If present, appends `page_token=<value>` to URL and fetches next page
4. Collects all results into a single JSON array
5. Stops at `LIB_MAX_PAGES` or when no more pages

No `eval` — uses two separate `jq -r` calls: one to extract `next_page_token` into a bash variable, one to extract results into a temp file. Safer than massive-skill's eval approach.

### Initialization

On source:
1. Validate `APCA_API_KEY_ID` is set (exit 1 if not)
2. Validate `APCA_API_SECRET_KEY` is set (exit 1 if not)
3. Resolve `LIB_TRADING_URL` from `APCA_PAPER` (default `true`)
4. Create `LIB_CONFIG_DIR` if missing

## `_data_lib.sh` — Shared Market Data Helpers

Sources `_lib.sh`. Each function takes a `base_path` parameter.

### Functions

**`_data_bars <base_path> <symbol> [flags...]`**
- `GET {LIB_DATA_URL}{base_path}/{symbol}/bars?start=&end=&timeframe=&limit=&page_token=`
- Auto-paginates via `_paginate`
- Flags: `--start`, `--end`, `--timeframe` (default `1Day`), `--limit`, `--feed`, `--currency`

**`_data_trades <base_path> <symbol> [flags...]`**
- `GET {LIB_DATA_URL}{base_path}/{symbol}/trades?start=&end=&limit=`
- Auto-paginates

**`_data_quotes <base_path> <symbol> [flags...]`**
- `GET {LIB_DATA_URL}{base_path}/{symbol}/quotes?start=&end=&limit=`
- Auto-paginates

**`_data_snapshot <base_path> <symbol> [flags...]`**
- `GET {LIB_DATA_URL}{base_path}/{symbol}/snapshot?feed=`
- Per-symbol path (returns flat object, not dictionary keyed by symbol)
- Single request, no pagination

**`_data_snapshots <base_path> <symbols_csv> [flags...]`**
- `GET {LIB_DATA_URL}{base_path}/snapshots?symbols={csv}`
- Multi-symbol variant

**`_data_latest_trade <base_path> <symbol>`**
- `GET {LIB_DATA_URL}{base_path}/{symbol}/trades/latest`

**`_data_latest_quote <base_path> <symbol>`**
- `GET {LIB_DATA_URL}{base_path}/{symbol}/quotes/latest`

**`_data_latest_bar <base_path> <symbol>`**
- `GET {LIB_DATA_URL}{base_path}/{symbol}/bars/latest`

### Common Flags

| Flag | Default | Used by |
|------|---------|---------|
| `--start` | (required for bars/trades/quotes) | bars, trades, quotes |
| `--end` | (optional) | bars, trades, quotes |
| `--timeframe` | `1Day` | bars only |
| `--limit` | (API default) | bars, trades, quotes |
| `--sort` | `asc` | bars, trades, quotes (`asc` or `desc`) |
| `--feed` | (API default, stocks only) | all stock data |
| `--currency` | `USD` (crypto only) | all crypto data |

### Symbol Handling

- Stocks: uppercase, no transformation
- Crypto: ensure slash format (`BTC/USD`), URL-encode slash for path segments (`BTC%2FUSD`)

## Domain Scripts

### `alpaca_account.sh` — Account & Portfolio

| Subcommand | HTTP | Endpoint | Notes |
|------------|------|----------|-------|
| `info` | GET | `/v2/account` | Returns buying power, cash, portfolio value, equity |
| `history [flags]` | GET | `/v2/account/portfolio/history` | Flags: `--period` (1M default), `--timeframe` (1D default), `--date-end`, `--extended-hours` |
| `config` | GET | `/v2/account/configurations` | Day trade settings, DTBP checks |
| `activities [flags]` | GET | `/v2/account/activities` | Flags: `--activity-type` (FILL, DIV, etc.), `--date`, `--after`, `--until`, `--direction`, `--page-size`. Paginated via `page_token`. |
| `activities <type>` | GET | `/v2/account/activities/{type}` | Filtered by activity type (e.g., FILL, DIV, TRANS) |

### `alpaca_orders.sh` — Order Management

| Subcommand | HTTP | Endpoint | Notes |
|------------|------|----------|-------|
| `submit <symbol> <side> <type> [flags]` | POST | `/v2/orders` | Builds JSON body. Validates required params per order type. |
| `list [flags]` | GET | `/v2/orders` | Flags: `--status`, `--limit`, `--after`, `--until`, `--direction`, `--nested`, `--symbols` |
| `get <order_id>` | GET | `/v2/orders/{id}` | |
| `get-by-client-id <client_order_id>` | GET | `/v2/orders:by_client_order_id?client_order_id=...` | Lookup by user-assigned client order ID |
| `cancel <order_id>` | DELETE | `/v2/orders/{id}` | |
| `cancel-all` | DELETE | `/v2/orders` | Returns array of cancellation statuses. Uses custom handler for 207 multi-status. |
| `replace <order_id> [flags]` | PATCH | `/v2/orders/{id}` | Flags: `--qty`, `--limit-price`, `--stop-price`, `--trail`, `--time-in-force` |

**Order submit JSON body construction:**

Base fields (always present):
```json
{
  "symbol": "<SYMBOL>",
  "side": "buy|sell",
  "type": "market|limit|stop|stop_limit|trailing_stop",
  "time_in_force": "day"
}
```

Conditional fields:
- `--qty N` → `"qty": "N"`
- `--notional N` → `"notional": "N"` (mutually exclusive with qty)
- `--limit-price P` → `"limit_price": "P"` (required for limit, stop_limit)
- `--stop-price P` → `"stop_price": "P"` (required for stop, stop_limit)
- `--trail-percent P` → `"trail_percent": "P"` (trailing_stop)
- `--trail-price P` → `"trail_price": "P"` (trailing_stop)
- `--time-in-force V` → `"time_in_force": "V"` (override default)
- `--extended-hours` → `"extended_hours": true` (limit orders only)
- `--client-order-id ID` → `"client_order_id": "ID"`

Bracket order fields:
- `--take-profit TP --stop-loss SL` → `"order_class": "bracket"` with nested:
  ```json
  "take_profit": {"limit_price": "TP"},
  "stop_loss": {"stop_price": "SL"}
  ```
- `--stop-loss-limit SLL` → adds `"limit_price": "SLL"` inside `stop_loss`

Validation before POST:
- `limit` requires `--limit-price`
- `stop` requires `--stop-price`
- `stop_limit` requires both `--limit-price` and `--stop-price`
- `trailing_stop` requires `--trail-percent` or `--trail-price` (not both)
- `--qty` and `--notional` are mutually exclusive
- At least one of `--qty` or `--notional` is required
- `--dry-run` outputs constructed JSON body without POSTing (for human review before execution)

### `alpaca_positions.sh` — Position Management

| Subcommand | HTTP | Endpoint | Notes |
|------------|------|----------|-------|
| `list` | GET | `/v2/positions` | No pagination (returns all) |
| `get <symbol>` | GET | `/v2/positions/{symbol}` | |
| `close <symbol> [flags]` | DELETE | `/v2/positions/{symbol}` | Flags: `--qty`, `--percentage` |
| `close-all` | DELETE | `/v2/positions` | Returns array of per-position results. Uses custom handler for 207 multi-status. |

### `alpaca_assets.sh` — Asset Lookup

| Subcommand | HTTP | Endpoint | Notes |
|------------|------|----------|-------|
| `get <symbol>` | GET | `/v2/assets/{symbol}` | |
| `list [flags]` | GET | `/v2/assets` | Flags: `--status`, `--asset-class`, `--exchange`. No pagination (returns full list). Use `_fetch_and_output`. Large response (~10k assets) — consider client-side `--limit` via jq slicing. |

### `alpaca_market.sh` — Market Clock & Calendar

| Subcommand | HTTP | Endpoint | Notes |
|------------|------|----------|-------|
| `clock` | GET | `/v2/clock` | Is market open, next open/close |
| `calendar [flags]` | GET | `/v2/calendar` | Flags: `--start`, `--end`. No pagination. |

### `alpaca_data_stocks.sh` — Stock Market Data

Thin wrapper. Sets `BASE_PATH="/v2/stocks"`, dispatches to `_data_lib.sh` functions.
Adds `--feed` flag support (sip/iex).

| Subcommand | Delegates to |
|------------|-------------|
| `bars <symbol> [flags]` | `_data_bars` |
| `trades <symbol> [flags]` | `_data_trades` |
| `quotes <symbol> [flags]` | `_data_quotes` |
| `snapshot <symbol> [flags]` | `_data_snapshot` |
| `snapshots <symbols> [flags]` | `_data_snapshots` |
| `latest-trade <symbol>` | `_data_latest_trade` |
| `latest-bar <symbol>` | `_data_latest_bar` |
| `latest-quote <symbol>` | `_data_latest_quote` |

### `alpaca_data_crypto.sh` — Crypto Market Data

Thin wrapper. Sets `BASE_PATH="/v1beta3/crypto/us"`, dispatches to `_data_lib.sh` functions.
Normalizes symbols to slash format, URL-encodes for path segments.

Same subcommands as stocks. Adds `--currency` flag.

**Note on crypto orders:** Crypto only supports `market`, `limit`, `stop_limit` order types with `gtc` and `ioc` time-in-force. The `alpaca_orders.sh submit` validation should warn if unsupported types/TIF are used with crypto symbols (detected by slash in symbol).

### `alpaca_watchlists.sh` — Watchlist Management

| Subcommand | HTTP | Endpoint | Notes |
|------------|------|----------|-------|
| `list` | GET | `/v2/watchlists` | |
| `get <id>` | GET | `/v2/watchlists/{id}` | |
| `create <name> [--symbols CSV]` | POST | `/v2/watchlists` | JSON body: `{"name": "...", "symbols": [...]}` |
| `add-symbol <id> <symbol>` | POST | `/v2/watchlists/{id}` | JSON body: `{"symbol": "..."}` |
| `remove-symbol <id> <symbol>` | DELETE | `/v2/watchlists/{id}/{symbol}` | |
| `delete <id>` | DELETE | `/v2/watchlists/{id}` | |

### `alpaca_format.sh` — JSON Formatter

Local-only (no `_lib.sh`, no API calls). Same pattern as massive-skill's `massive_format.sh`.

**Types:** `account`, `activities`, `orders`, `positions`, `assets`, `bars`, `trades`, `quotes`, `snapshot`, `watchlists`, `calendar`, `clock`

**Formats:** `summary` (default human-readable), `full` (pretty JSON), `csv`

**Options:** `--top N` to limit results

**Input:** stdin pipe or file argument

**Formatters per type:**
- `account` — key-value pairs: equity, cash, buying power, P&L
- `orders` — table: id, symbol, side, type, qty, filled_qty, status, submitted_at
- `positions` — table: symbol, qty, avg_entry, current_price, unrealized_pl, unrealized_plpc
- `assets` — table: symbol, name, class, exchange, status, tradable
- `bars` — table: timestamp, open, high, low, close, volume (reuse massive-skill pattern)
- `trades` — table: timestamp, price, size
- `quotes` — table: timestamp, bid, bid_size, ask, ask_size
- `snapshot` — key-value: symbol, latest_trade, latest_quote, minute_bar, daily_bar
- `watchlists` — table: id, name, symbols count
- `calendar` — table: date, open, close
- `clock` — key-value: is_open, timestamp, next_open, next_close

## Security

- Credentials via HTTP headers only, never in URLs or logs
- `curl -s` (no verbose output that could leak headers)
- `APCA_PAPER=true` default — live trading requires explicit opt-in
- Scripts write only to `~/.config/alpaca-skill/`
- No `eval` — use jq `-r` for safe extraction
- Both env vars validated at source time (fail fast)
- No shell-outs to external tools beyond curl and jq

## Testing

- Each script gets a test file in `tests/`
- Tests mock `curl` with a bash function override returning canned JSON
- Test pattern: set mock env vars → source script functions → call → assert output/exit code
- `tests/run_tests.sh` — discovers and runs all test files, reports pass/fail
- Key test cases:
  - `_lib.sh`: auth validation, URL building, HTTP method routing, status code handling, pagination
  - `alpaca_orders.sh`: order body construction for each type, validation (missing params, mutual exclusion)
  - `alpaca_format.sh`: each type × each format
  - Error paths: 429, 422, missing env vars
