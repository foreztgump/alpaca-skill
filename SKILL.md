---
name: alpaca
description: >
  Trade stocks and crypto via Alpaca Markets API. Use when the user asks to place
  orders (buy/sell stocks, crypto), check positions, view account balance/portfolio,
  manage watchlists, look up assets, check market hours, query market data
  (stock/crypto/options prices, bars, quotes, trades, snapshots), read news,
  find most active stocks or top movers, view options chains, or look up corporate
  actions (dividends, splits). Supports paper and live trading.
  Requires APCA_API_KEY_ID and APCA_API_SECRET_KEY env vars.
  Covers: market/limit/stop/stop-limit/trailing-stop orders, bracket orders (OTO/OCO),
  fractional shares, notional orders, position management, portfolio history,
  account activities, asset search, stock and crypto market data (bars, quotes,
  trades, snapshots, latest prices), options data (chain with greeks, bars, trades,
  snapshots), crypto orderbook, news articles, screener (most active, movers),
  corporate actions, watchlists, market clock and calendar.
allowed-tools: Bash
---

# Alpaca Trading Skill

Trade stocks and crypto, manage positions, and query market data via Alpaca Markets API v2.

## Prerequisites

- `APCA_API_KEY_ID` environment variable must be set
- `APCA_API_SECRET_KEY` environment variable must be set
- `APCA_PAPER` environment variable controls paper vs live trading (default: `true`)
- `curl` and `jq` must be available

## Workflow Decision Tree

```text
User wants to trade or check markets?
├── Account & Portfolio
│   ├── Account balance / buying power → alpaca_account.sh info
│   ├── Portfolio history / P&L → alpaca_account.sh history [--period 1M] [--timeframe 1D]
│   ├── Account configurations → alpaca_account.sh config
│   ├── Activity history (fills, dividends) → alpaca_account.sh activities [--activity-type FILL]
│   └── Activities by type → alpaca_account.sh activities FILL [--date 2026-03-17]
├── Place an Order
│   ├── Market order (buy/sell now)
│   │   ├── By shares → alpaca_orders.sh submit <SYMBOL> <buy|sell> market --qty <N>
│   │   └── By dollar amount → alpaca_orders.sh submit <SYMBOL> <buy|sell> market --notional <AMOUNT>
│   ├── Limit order → alpaca_orders.sh submit <SYMBOL> <buy|sell> limit --qty <N> --limit-price <PRICE>
│   ├── Stop order → alpaca_orders.sh submit <SYMBOL> <buy|sell> stop --qty <N> --stop-price <PRICE>
│   ├── Stop-limit → alpaca_orders.sh submit <SYMBOL> <buy|sell> stop_limit --qty <N> --stop-price <P> --limit-price <P>
│   ├── Trailing stop (%) → alpaca_orders.sh submit <SYMBOL> <buy|sell> trailing_stop --qty <N> --trail-percent <PCT>
│   ├── Trailing stop ($) → alpaca_orders.sh submit <SYMBOL> <buy|sell> trailing_stop --qty <N> --trail-price <AMT>
│   └── Bracket order → alpaca_orders.sh submit <SYMBOL> buy market --qty <N> --take-profit <TP> --stop-loss <SL>
├── Manage Orders
│   ├── List open orders → alpaca_orders.sh list [--status open]
│   ├── List all orders → alpaca_orders.sh list --status all [--limit 50]
│   ├── Get order details → alpaca_orders.sh get <ORDER_ID>
│   ├── Get order by client ID → alpaca_orders.sh get-by-client-id <CLIENT_ORDER_ID>
│   ├── Cancel an order → alpaca_orders.sh cancel <ORDER_ID>
│   ├── Cancel all orders → alpaca_orders.sh cancel-all
│   └── Replace/modify order → alpaca_orders.sh replace <ORDER_ID> --qty <N> --limit-price <P>
├── Positions
│   ├── List all positions → alpaca_positions.sh list
│   ├── Get position for symbol → alpaca_positions.sh get <SYMBOL>
│   ├── Close a position → alpaca_positions.sh close <SYMBOL> [--qty <N>] [--percentage <PCT>]
│   └── Close all positions → alpaca_positions.sh close-all
├── Assets & Market Info
│   ├── Look up an asset → alpaca_assets.sh get <SYMBOL>
│   ├── Search assets → alpaca_assets.sh list [--class us_equity] [--status active] [--exchange NYSE]
│   ├── Market open/closed? → alpaca_market.sh clock
│   └── Trading calendar → alpaca_market.sh calendar [--start <DATE>] [--end <DATE>]
├── Stock Market Data
│   ├── Current price / snapshot → alpaca_data_stocks.sh snapshot <SYMBOL> [--feed sip]
│   ├── Multi-stock snapshots → alpaca_data_stocks.sh snapshots <SYM1,SYM2,...>
│   ├── Historical bars (OHLC) → alpaca_data_stocks.sh bars <SYMBOL> --start <DATE> --end <DATE> [--timeframe 1Day]
│   ├── Latest quote → alpaca_data_stocks.sh latest-quote <SYMBOL>
│   ├── Latest trade → alpaca_data_stocks.sh latest-trade <SYMBOL>
│   ├── Latest bar → alpaca_data_stocks.sh latest-bar <SYMBOL>
│   ├── Historical trades → alpaca_data_stocks.sh trades <SYMBOL> --start <DATE> --end <DATE>
│   └── Historical quotes → alpaca_data_stocks.sh quotes <SYMBOL> --start <DATE> --end <DATE>
├── Crypto Market Data
│   ├── Current price / snapshot → alpaca_data_crypto.sh snapshot <SYMBOL>
│   ├── Multi-crypto snapshots → alpaca_data_crypto.sh snapshots <SYM1,SYM2,...>
│   ├── Historical bars → alpaca_data_crypto.sh bars <SYMBOL> --start <DATE> --end <DATE> [--timeframe 1Day]
│   ├── Latest quote → alpaca_data_crypto.sh latest-quote <SYMBOL>
│   ├── Latest trade → alpaca_data_crypto.sh latest-trade <SYMBOL>
│   ├── Latest bar → alpaca_data_crypto.sh latest-bar <SYMBOL>
│   ├── Historical trades → alpaca_data_crypto.sh trades <SYMBOL> --start <DATE> --end <DATE>
│   ├── Historical quotes → alpaca_data_crypto.sh quotes <SYMBOL> --start <DATE> --end <DATE>
│   └── Order book (bids/asks) → alpaca_data_crypto.sh orderbook <SYMBOL>
├── Options Market Data
│   ├── Options chain (with greeks) → alpaca_data_options.sh chain <UNDERLYING> [--expiration-date <DATE>] [--type call]
│   ├── Option snapshot → alpaca_data_options.sh snapshot <CONTRACT_SYMBOL>
│   ├── Multi-option snapshots → alpaca_data_options.sh snapshots <SYM1,SYM2,...>
│   ├── Historical bars → alpaca_data_options.sh bars <CONTRACT_SYMBOL> --start <DATE> --end <DATE>
│   ├── Historical trades → alpaca_data_options.sh trades <CONTRACT_SYMBOL> --start <DATE> --end <DATE>
│   ├── Latest quote → alpaca_data_options.sh latest-quote <CONTRACT_SYMBOL>
│   └── Latest trade → alpaca_data_options.sh latest-trade <CONTRACT_SYMBOL>
├── News
│   └── News articles → alpaca_news.sh list [--symbols AAPL,TSLA] [--start <DATE>] [--limit 10]
├── Screener
│   ├── Most active stocks → alpaca_screener.sh most-active [--by volume] [--top 10]
│   └── Top movers (gainers/losers) → alpaca_screener.sh movers [--top 10]
├── Corporate Actions
│   └── Dividends/splits/mergers → alpaca_corporate_actions.sh list [--symbols AAPL] [--types dividend,split] [--date-from <DATE>]
└── Watchlists
    ├── List watchlists → alpaca_watchlists.sh list
    ├── Get watchlist → alpaca_watchlists.sh get <WATCHLIST_ID>
    ├── Create watchlist → alpaca_watchlists.sh create <NAME> [--symbols AAPL,TSLA]
    ├── Add symbol → alpaca_watchlists.sh add-symbol <WATCHLIST_ID> <SYMBOL>
    ├── Remove symbol → alpaca_watchlists.sh remove-symbol <WATCHLIST_ID> <SYMBOL>
    └── Delete watchlist → alpaca_watchlists.sh delete <WATCHLIST_ID>
```

**All scripts are located at `${CLAUDE_SKILL_DIR}/scripts/`.** Always prefix script paths with `${CLAUDE_SKILL_DIR}/scripts/` when running them.

## Scripts Reference

| Script | Purpose | Key Subcommands |
|--------|---------|-----------------|
| `alpaca_account.sh` | Account info & portfolio | `info`, `history`, `config`, `activities` |
| `alpaca_orders.sh` | Order management | `submit`, `list`, `get`, `get-by-client-id`, `cancel`, `cancel-all`, `replace` |
| `alpaca_positions.sh` | Position management | `list`, `get`, `close`, `close-all` |
| `alpaca_assets.sh` | Asset lookup & search | `get`, `list` |
| `alpaca_market.sh` | Market clock & calendar | `clock`, `calendar` |
| `alpaca_data_stocks.sh` | Stock market data | `bars`, `trades`, `quotes`, `snapshot`, `snapshots`, `latest-quote`, `latest-trade`, `latest-bar` |
| `alpaca_data_crypto.sh` | Crypto market data | `bars`, `trades`, `quotes`, `snapshot`, `snapshots`, `latest-quote`, `latest-trade`, `latest-bar`, `orderbook` |
| `alpaca_data_options.sh` | Options market data | `bars`, `trades`, `snapshot`, `snapshots`, `chain`, `latest-quote`, `latest-trade` |
| `alpaca_news.sh` | News articles | `list` |
| `alpaca_screener.sh` | Screener & movers | `most-active`, `movers` |
| `alpaca_corporate_actions.sh` | Corporate actions | `list` |
| `alpaca_watchlists.sh` | Watchlist management | `list`, `get`, `create`, `add-symbol`, `remove-symbol`, `delete` |
| `alpaca_format.sh` | Format JSON for display | `--type`, `--format`, `--top` |

## Quick Start

```bash
# Check account balance and buying power
${CLAUDE_SKILL_DIR}/scripts/alpaca_account.sh info

# Buy 10 shares of AAPL at market price
${CLAUDE_SKILL_DIR}/scripts/alpaca_orders.sh submit AAPL buy market --qty 10

# Buy $500 worth of TSLA (fractional shares)
${CLAUDE_SKILL_DIR}/scripts/alpaca_orders.sh submit TSLA buy market --notional 500

# Place a limit order
${CLAUDE_SKILL_DIR}/scripts/alpaca_orders.sh submit AAPL buy limit --qty 5 --limit-price 180.00

# Place a bracket order (auto take-profit and stop-loss)
${CLAUDE_SKILL_DIR}/scripts/alpaca_orders.sh submit AAPL buy market --qty 10 --take-profit 200.00 --stop-loss 170.00

# Check current positions
${CLAUDE_SKILL_DIR}/scripts/alpaca_positions.sh list

# Get current stock price
${CLAUDE_SKILL_DIR}/scripts/alpaca_data_stocks.sh snapshot AAPL

# Get 30 days of daily bars
${CLAUDE_SKILL_DIR}/scripts/alpaca_data_stocks.sh bars AAPL --start 2026-02-15 --end 2026-03-17 --timeframe 1Day

# Get BTC/USD price
${CLAUDE_SKILL_DIR}/scripts/alpaca_data_crypto.sh snapshot BTC/USD

# Check if market is open
${CLAUDE_SKILL_DIR}/scripts/alpaca_market.sh clock

# List open orders
${CLAUDE_SKILL_DIR}/scripts/alpaca_orders.sh list --status open
```

## Behavior Rules (MANDATORY)

1. **Paper trading is the default.** `APCA_PAPER=true` unless the user explicitly requests live trading.
2. **Stock symbols are CASE-SENSITIVE.** Always use uppercase: `AAPL`, not `aapl`.
3. **Crypto symbols use slash format.** Use `BTC/USD`, `ETH/USD` — not `BTCUSD`.
4. **Dates use RFC 3339 format** (`2026-01-15T00:00:00Z`) or `YYYY-MM-DD` shorthand.
5. **Monetary values are strings.** Never parse to float — preserve as returned by the API.
6. **All responses are JSON.** Pipe through `alpaca_format.sh` for human-readable output.
7. **Rate limits: 200 req/min (free).** If you get HTTP 429, wait and retry. Scripts report this clearly.
8. **Order quantities: `--qty` is shares (integer or decimal for fractional), `--notional` is dollar amount.** Never use both.
9. **Time in force defaults to `day`** for stock orders. Use `--time-in-force gtc` for good-til-cancelled.
10. **Crypto trades 24/7.** Stock trades only during market hours (check with `alpaca_market.sh clock`).
11. **Extended hours:** Use `--extended-hours` flag on limit orders to trade in pre/post market.
12. **Pagination uses `page_token`**, not offset. The scripts handle this automatically (max 10 pages).
13. **Options contract symbols use OCC format**: `AAPL250321C00185000` (SYMBOL + YYMMDD + C/P + STRIKE*1000).
14. **News articles are paginated**. Use `--limit` to control batch size, scripts auto-paginate.

## Order Types Reference

| Type | Required Params | Description |
|------|----------------|-------------|
| `market` | `--qty` or `--notional` | Execute immediately at best available price |
| `limit` | `--qty`, `--limit-price` | Execute at limit price or better |
| `stop` | `--qty`, `--stop-price` | Trigger market order when stop price hit |
| `stop_limit` | `--qty`, `--stop-price`, `--limit-price` | Trigger limit order when stop price hit |
| `trailing_stop` | `--qty`, `--trail-percent` or `--trail-price` | Dynamic stop that trails the price |

## Time in Force Options

| Value | Description |
|-------|-------------|
| `day` | Cancelled at end of trading day (default) |
| `gtc` | Good til cancelled (max 90 days) |
| `opg` | Market/limit on open |
| `cls` | Market/limit on close |
| `ioc` | Immediate or cancel |
| `fok` | Fill or kill |

## Exit Codes

| Code | Meaning | Agent should... |
|------|---------|-----------------|
| 0 | Success — results on stdout | Format and present results |
| 1 | Error — something failed | Report the error from stderr |

## Security

All scripts source `_lib.sh` for shared HTTP functions. The library:

- Makes requests to **three endpoints only**: `paper-api.alpaca.markets`, `api.alpaca.markets`, `data.alpaca.markets`
- Uses **two credentials**: `APCA_API_KEY_ID` and `APCA_API_SECRET_KEY` (sent via HTTP headers, never in URLs)
- Writes **only** to `~/.config/alpaca-skill/`
- Does not read other environment variables (except `APCA_PAPER` and `APCA_TIMEOUT`), contact other hosts, or modify files outside its config directory
- Defaults to **paper trading** — live trading requires explicit `APCA_PAPER=false`

## Additional Resources

- For complete API endpoint documentation, see [references/api-reference.md](references/api-reference.md)
