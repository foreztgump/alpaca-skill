# Alpaca API Reference

Quick-reference of every Alpaca endpoint used by this skill.

## Trading API (`paper-api.alpaca.markets` / `api.alpaca.markets`)

### Account

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v2/account` | -- | `alpaca_account.sh info` |
| GET | `/v2/account/portfolio/history` | `period`, `timeframe`, `date_end`, `extended_hours` | `alpaca_account.sh history` |
| GET | `/v2/account/configurations` | -- | `alpaca_account.sh config` |
| GET | `/v2/account/activities` | `activity_type`, `date`, `after`, `until`, `direction`, `page_size` | `alpaca_account.sh activities` |
| GET | `/v2/account/activities/{type}` | `date`, `after`, `until`, `direction`, `page_size` | `alpaca_account.sh activities <TYPE>` |

### Orders

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| POST | `/v2/orders` | body: `symbol`, `side`, `type`, `qty`/`notional`, `limit_price`, `stop_price`, `trail_percent`, `trail_price`, `time_in_force`, `extended_hours`, `take_profit`, `stop_loss` | `alpaca_orders.sh submit` |
| GET | `/v2/orders` | `status`, `limit`, `after`, `until`, `direction`, `nested`, `symbols` | `alpaca_orders.sh list` |
| GET | `/v2/orders/{id}` | -- | `alpaca_orders.sh get` |
| GET | `/v2/orders:by_client_order_id` | `client_order_id` | `alpaca_orders.sh get-by-client-id` |
| PATCH | `/v2/orders/{id}` | body: `qty`, `limit_price`, `stop_price`, `trail`, `time_in_force` | `alpaca_orders.sh replace` |
| DELETE | `/v2/orders/{id}` | -- | `alpaca_orders.sh cancel` |
| DELETE | `/v2/orders` | -- | `alpaca_orders.sh cancel-all` |

### Positions

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v2/positions` | -- | `alpaca_positions.sh list` |
| GET | `/v2/positions/{symbol}` | -- | `alpaca_positions.sh get` |
| DELETE | `/v2/positions/{symbol}` | `qty`, `percentage` | `alpaca_positions.sh close` |
| DELETE | `/v2/positions` | -- | `alpaca_positions.sh close-all` |

### Assets

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v2/assets` | `status`, `asset_class`, `exchange` | `alpaca_assets.sh list` |
| GET | `/v2/assets/{symbol}` | -- | `alpaca_assets.sh get` |

### Market

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v2/clock` | -- | `alpaca_market.sh clock` |
| GET | `/v2/calendar` | `start`, `end` | `alpaca_market.sh calendar` |

### Watchlists

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v2/watchlists` | -- | `alpaca_watchlists.sh list` |
| GET | `/v2/watchlists/{id}` | -- | `alpaca_watchlists.sh get` |
| POST | `/v2/watchlists` | body: `name`, `symbols` | `alpaca_watchlists.sh create` |
| POST | `/v2/watchlists/{id}` | body: `symbol` | `alpaca_watchlists.sh add-symbol` |
| DELETE | `/v2/watchlists/{id}/{symbol}` | -- | `alpaca_watchlists.sh remove-symbol` |
| DELETE | `/v2/watchlists/{id}` | -- | `alpaca_watchlists.sh delete` |

## Market Data API (`data.alpaca.markets`)

### Stocks (`/v2/stocks`)

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v2/stocks/{symbol}/bars` | `start`, `end`, `timeframe`, `limit`, `sort`, `feed`, `currency` | `alpaca_data_stocks.sh bars` |
| GET | `/v2/stocks/{symbol}/trades` | `start`, `end`, `limit`, `sort`, `feed`, `currency` | `alpaca_data_stocks.sh trades` |
| GET | `/v2/stocks/{symbol}/quotes` | `start`, `end`, `limit`, `sort`, `feed`, `currency` | `alpaca_data_stocks.sh quotes` |
| GET | `/v2/stocks/{symbol}/snapshot` | `feed`, `currency` | `alpaca_data_stocks.sh snapshot` |
| GET | `/v2/stocks/snapshots` | `symbols`, `feed`, `currency` | `alpaca_data_stocks.sh snapshots` |
| GET | `/v2/stocks/{symbol}/trades/latest` | -- | `alpaca_data_stocks.sh latest-trade` |
| GET | `/v2/stocks/{symbol}/quotes/latest` | -- | `alpaca_data_stocks.sh latest-quote` |
| GET | `/v2/stocks/{symbol}/bars/latest` | -- | `alpaca_data_stocks.sh latest-bar` |

### Crypto (`/v1beta3/crypto/us`)

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v1beta3/crypto/us/{symbol}/bars` | `start`, `end`, `timeframe`, `limit`, `sort`, `feed`, `currency` | `alpaca_data_crypto.sh bars` |
| GET | `/v1beta3/crypto/us/{symbol}/trades` | `start`, `end`, `limit`, `sort`, `feed`, `currency` | `alpaca_data_crypto.sh trades` |
| GET | `/v1beta3/crypto/us/{symbol}/quotes` | `start`, `end`, `limit`, `sort`, `feed`, `currency` | `alpaca_data_crypto.sh quotes` |
| GET | `/v1beta3/crypto/us/{symbol}/snapshot` | `feed`, `currency` | `alpaca_data_crypto.sh snapshot` |
| GET | `/v1beta3/crypto/us/snapshots` | `symbols`, `feed`, `currency` | `alpaca_data_crypto.sh snapshots` |
| GET | `/v1beta3/crypto/us/{symbol}/trades/latest` | -- | `alpaca_data_crypto.sh latest-trade` |
| GET | `/v1beta3/crypto/us/{symbol}/quotes/latest` | -- | `alpaca_data_crypto.sh latest-quote` |
| GET | `/v1beta3/crypto/us/{symbol}/bars/latest` | -- | `alpaca_data_crypto.sh latest-bar` |
| GET | `/v1beta3/crypto/us/latest/orderbooks` | `symbols` | `alpaca_data_crypto.sh orderbook` |

### Options (`/v1beta1/options`)

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v1beta1/options/bars` | `symbols`, `start`, `end`, `timeframe`, `limit`, `sort` | `alpaca_data_options.sh bars` |
| GET | `/v1beta1/options/trades` | `symbols`, `start`, `end`, `limit`, `sort` | `alpaca_data_options.sh trades` |
| GET | `/v1beta1/options/quotes/latest` | `symbols` | `alpaca_data_options.sh latest-quote` |
| GET | `/v1beta1/options/trades/latest` | `symbols` | `alpaca_data_options.sh latest-trade` |
| GET | `/v1beta1/options/snapshots/{symbol}` | -- | `alpaca_data_options.sh snapshot` |
| GET | `/v1beta1/options/snapshots` | `symbols` | `alpaca_data_options.sh snapshots` |
| GET | `/v1beta1/options/snapshots/{underlying}` | `expiration_date`, `type`, `strike_price_gte`, `strike_price_lte`, `root_symbol` | `alpaca_data_options.sh chain` |

### News

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v1beta1/news` | `symbols`, `start`, `end`, `limit`, `sort`, `include_content`, `exclude_contentless` | `alpaca_news.sh list` |

### Screener

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v1beta1/screener/stocks/most-actives` | `by`, `top` | `alpaca_screener.sh most-active` |
| GET | `/v1beta1/screener/{market_type}/movers` | `top` | `alpaca_screener.sh movers` |

### Corporate Actions

| Method | Path | Key Params | Script |
|--------|------|------------|--------|
| GET | `/v1beta1/corporate-actions` | `symbols`, `types`, `date_from`, `date_to`, `limit`, `sort` | `alpaca_corporate_actions.sh list` |
