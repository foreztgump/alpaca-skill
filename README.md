# alpaca-skill

Claude Agent Skill for trading stocks and crypto via [Alpaca Markets API](https://docs.alpaca.markets). Supports paper and live trading, order management, position tracking, and market data queries.

## Features

- **Trading**: Market, limit, stop, stop-limit, trailing stop, and bracket orders
- **Fractional shares**: Buy by share count or dollar amount (notional)
- **Positions**: View, close individual or all positions
- **Stock Market Data**: Bars, quotes, trades, snapshots, latest prices
- **Crypto Market Data**: Bars, quotes, trades, snapshots, order book
- **Options Market Data**: Chain with greeks, bars, trades, snapshots
- **News**: Market news feed filtered by symbols and date range
- **Screener**: Most active stocks, top movers (gainers/losers)
- **Corporate Actions**: Dividends, splits, mergers, spinoffs
- **Account**: Balance, buying power, portfolio history, configurations, activity log
- **Watchlists**: Create and manage watchlists
- **Market Info**: Clock, calendar, asset lookup
- **Safety**: Paper trading by default

## Quick Start

1. Get your API keys from [Alpaca Dashboard](https://app.alpaca.markets)
2. Copy `.env.example` to `.env` and fill in your keys:
   ```bash
   cp .env.example .env
   # Edit .env with your keys:
   #   APCA_PAPER_KEY=your_paper_key
   #   APCA_PAPER_SECRET_KEY=your_paper_secret
   #   APCA_REAL_KEY=your_live_key        (optional)
   #   APCA_REAL_SECRET_KEY=your_live_secret  (optional)
   ```
3. Source and export:
   ```bash
   source .env
   export APCA_PAPER_KEY APCA_PAPER_SECRET_KEY APCA_PAPER=true
   ```
4. Install:
   ```bash
   make install
   # or
   bash install.sh
   ```
5. Restart Claude Code -- the skill activates automatically when you ask about trading.

## Requirements

- `curl` and `jq`
- Alpaca Markets account (free tier works for paper trading)

## Scripts

15 scripts total: 2 shared libraries, 12 domain scripts, 1 formatter.

| Script | Purpose |
|--------|---------|
| `_lib.sh` | Shared library: auth, HTTP, URL building, pagination |
| `_data_lib.sh` | Shared library: market data helpers (bars, trades, quotes, snapshots) |
| `alpaca_account.sh` | Account info, portfolio history, config, activities |
| `alpaca_orders.sh` | Order submit, list, get, cancel, replace |
| `alpaca_positions.sh` | Position list, get, close, close-all |
| `alpaca_assets.sh` | Asset lookup and search |
| `alpaca_market.sh` | Market clock and trading calendar |
| `alpaca_data_stocks.sh` | Stock bars, trades, quotes, snapshots, latest prices |
| `alpaca_data_crypto.sh` | Crypto bars, trades, quotes, snapshots, order book |
| `alpaca_data_options.sh` | Options chain, bars, trades, snapshots, latest prices |
| `alpaca_news.sh` | Market news feed |
| `alpaca_screener.sh` | Most active stocks, top movers |
| `alpaca_corporate_actions.sh` | Corporate actions (dividends, splits, mergers) |
| `alpaca_watchlists.sh` | Watchlist CRUD |
| `alpaca_format.sh` | Format JSON output for human-readable display |

## Usage Examples

Ask Claude naturally:
- "Buy 10 shares of AAPL"
- "What's my account balance?"
- "Show me TSLA's price history for the last month"
- "Place a limit order to buy GOOG at $170"
- "Close my position in MSFT"
- "Is the market open right now?"
- "What's the current BTC/USD price?"
- "Show me the options chain for AAPL expiring this Friday"
- "What are the most active stocks today?"
- "Show me the latest news for TSLA"
- "What dividends has AAPL paid recently?"
- "Who are the top movers today?"

## License

MIT
