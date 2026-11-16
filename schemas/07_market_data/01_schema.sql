-- ==============================================================================
-- OENEXA Market Data Domain Schema (oenexa_market_data_db)
-- Real-Time Price Feeds, Tickers, 24h Aggregations & Oracle Attestations
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Real-Time Tickers
CREATE TABLE IF NOT EXISTS tickers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(32) UNIQUE NOT NULL, -- e.g. ONXC-USDT, BTC-USDT
    last_price NUMERIC(28, 8) NOT NULL CHECK (last_price > 0),
    best_bid NUMERIC(28, 8) NOT NULL,
    best_ask NUMERIC(28, 8) NOT NULL,
    price_change_24h NUMERIC(10, 4) NOT NULL DEFAULT 0.0,
    price_change_percent_24h NUMERIC(8, 4) NOT NULL DEFAULT 0.0,
    high_price_24h NUMERIC(28, 8) NOT NULL,
    low_price_24h NUMERIC(28, 8) NOT NULL,
    volume_base_24h NUMERIC(28, 8) NOT NULL DEFAULT 0.0,
    volume_quote_24h NUMERIC(28, 8) NOT NULL DEFAULT 0.0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Orderbook Depth Snapshots (L2)
CREATE TABLE IF NOT EXISTS orderbook_depth_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(32) NOT NULL,
    sequence_id BIGINT NOT NULL,
    bids JSONB NOT NULL, -- Array of [price, quantity]
    asks JSONB NOT NULL, -- Array of [price, quantity]
    captured_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Oracle Attestations (External Proofs)
CREATE TABLE IF NOT EXISTS oracle_price_attestations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    oracle_source VARCHAR(64) NOT NULL, -- e.g. CHAINLINK, INTERNAL_CONSENSUS, BINANCE
    feed_key VARCHAR(32) NOT NULL, -- e.g. ONXC/USD
    reported_price NUMERIC(28, 8) NOT NULL,
    confidence_score NUMERIC(5, 4) NOT NULL DEFAULT 1.0,
    attestation_signature TEXT,
    reported_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_depth_symbol ON orderbook_depth_snapshots(symbol, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_oracle_feed ON oracle_price_attestations(feed_key, reported_at DESC);
