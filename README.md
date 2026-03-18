# alpaca-skill

Claude Agent Skill for trading stocks and crypto via [Alpaca Markets API](https://docs.alpaca.markets). Supports paper and live trading, order management, position tracking, and market data queries.

## Features

- **Trading**: Market, limit, stop, stop-limit, trailing stop, and bracket orders
- **Fractional shares**: Buy by share count or dollar amount (notional)
- **Positions**: View, close individual or all positions
- **Market Data**: Stock and crypto bars, quotes, trades, snapshots
- **Account**: Balance, buying power, portfolio history
- **Watchlists**: Create and manage watchlists
- **Market Info**: Clock, calendar, asset lookup
- **Safety**: Paper trading by default

## Quick Start

1. Get your API keys from [Alpaca Dashboard](https://app.alpaca.markets)
2. Set environment variables:
   ```bash
   export APCA_API_KEY_ID=your_key
   export APCA_API_SECRET_KEY=your_secret
   export APCA_PAPER=true  # default, use false for live trading
   ```
3. Install:
   ```bash
   make install
   # or
   bash install.sh
   ```
4. Restart Claude Code — the skill activates automatically when you ask about trading.

## Requirements

- `curl` and `jq`
- Alpaca Markets account (free tier works for paper trading)

## Usage Examples

Ask Claude naturally:
- "Buy 10 shares of AAPL"
- "What's my account balance?"
- "Show me TSLA's price history for the last month"
- "Place a limit order to buy GOOG at $170"
- "Close my position in MSFT"
- "Is the market open right now?"
- "What's the current BTC/USD price?"

## License

MIT
