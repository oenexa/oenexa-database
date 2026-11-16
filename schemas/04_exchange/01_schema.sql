-- ==============================================================================
-- OENEXA Exchange Domain Schema (oenexa_exchange_db)
-- High-Performance Matching Engine, Limit/Market Orders, Fills & OHLCV Bars
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE order_side_enum AS ENUM ('BUY', 'SELL');
CREATE TYPE order_type_enum AS ENUM ('LIMIT', 'MARKET', 'STOP_LIMIT');
CREATE TYPE order_status_enum AS ENUM ('NEW', 'PARTIALLY_FILLED', 'FILLED', 'CANCELED', 'REJECTED');
CREATE TYPE time_in_force_enum AS ENUM ('GTC', 'IOC', 'FOK');

-- 1. Trading Pairs
CREATE TABLE IF NOT EXISTS trading_pairs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(32) UNIQUE NOT NULL, -- e.g. ONXC/USDT, BTC/USDT
    base_asset VARCHAR(16) NOT NULL,
    quote_asset VARCHAR(16) NOT NULL,
    base_precision INT NOT NULL DEFAULT 4,
    quote_precision INT NOT NULL DEFAULT 4,
    min_order_quantity NUMERIC(28, 8) NOT NULL,
    maker_fee_rate NUMERIC(6, 4) NOT NULL DEFAULT 0.0010, -- 0.10%
    taker_fee_rate NUMERIC(6, 4) NOT NULL DEFAULT 0.0020, -- 0.20%
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- Logical reference to Identity service
    pair_id UUID NOT NULL REFERENCES trading_pairs(id),
    client_order_id VARCHAR(64) UNIQUE,
    side order_side_enum NOT NULL,
    order_type order_type_enum NOT NULL,
    time_in_force time_in_force_enum NOT NULL DEFAULT 'GTC',
    price NUMERIC(28, 8), -- NULL for pure market orders
    stop_price NUMERIC(28, 8),
    quantity NUMERIC(28, 8) NOT NULL CHECK (quantity > 0),
    executed_quantity NUMERIC(28, 8) NOT NULL DEFAULT 0.0 CHECK (executed_quantity <= quantity),
    cumulative_quote NUMERIC(28, 8) NOT NULL DEFAULT 0.0,
    status order_status_enum NOT NULL DEFAULT 'NEW',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Trade Executions (Fills)
CREATE TABLE IF NOT EXISTS trade_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pair_id UUID NOT NULL REFERENCES trading_pairs(id),
    maker_order_id UUID NOT NULL REFERENCES orders(id),
    taker_order_id UUID NOT NULL REFERENCES orders(id),
    maker_user_id UUID NOT NULL,
    taker_user_id UUID NOT NULL,
    price NUMERIC(28, 8) NOT NULL CHECK (price > 0),
    quantity NUMERIC(28, 8) NOT NULL CHECK (quantity > 0),
    quote_amount NUMERIC(28, 8) NOT NULL CHECK (quote_amount > 0),
    maker_fee NUMERIC(28, 8) NOT NULL DEFAULT 0.0,
    taker_fee NUMERIC(28, 8) NOT NULL DEFAULT 0.0,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Candlestick Aggregations (OHLCV)
CREATE TABLE IF NOT EXISTS candlestick_bars (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pair_id UUID NOT NULL REFERENCES trading_pairs(id),
    interval_unit VARCHAR(8) NOT NULL, -- 1m, 5m, 15m, 1h, 4h, 1d
    bucket_start TIMESTAMPTZ NOT NULL,
    open_price NUMERIC(28, 8) NOT NULL,
    high_price NUMERIC(28, 8) NOT NULL,
    low_price NUMERIC(28, 8) NOT NULL,
    close_price NUMERIC(28, 8) NOT NULL,
    volume NUMERIC(28, 8) NOT NULL DEFAULT 0.0,
    trade_count INT NOT NULL DEFAULT 0,
    CONSTRAINT uq_pair_interval_bucket UNIQUE (pair_id, interval_unit, bucket_start)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_pair_status ON orders(pair_id, status, side, price);
CREATE INDEX IF NOT EXISTS idx_trades_pair ON trade_executions(pair_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_trades_maker ON trade_executions(maker_user_id);
CREATE INDEX IF NOT EXISTS idx_trades_taker ON trade_executions(taker_user_id);
CREATE INDEX IF NOT EXISTS idx_candles_lookup ON candlestick_bars(pair_id, interval_unit, bucket_start DESC);
