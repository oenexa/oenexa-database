-- ==============================================================================
-- OENEXA Liquidity Domain Schema (oenexa_liquidity_db)
-- Automated Market Maker (AMM), Liquidity Pools, LP Positions & Swaps
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Liquidity Pools
CREATE TABLE IF NOT EXISTS amm_pools (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pair_name VARCHAR(64) UNIQUE NOT NULL, -- e.g. ONXC/USDT
    token_a VARCHAR(16) NOT NULL,
    token_b VARCHAR(16) NOT NULL,
    reserve_a NUMERIC(36, 18) NOT NULL DEFAULT 0.0 CHECK (reserve_a >= 0),
    reserve_b NUMERIC(36, 18) NOT NULL DEFAULT 0.0 CHECK (reserve_b >= 0),
    total_lp_supply NUMERIC(36, 18) NOT NULL DEFAULT 0.0 CHECK (total_lp_supply >= 0),
    fee_tier_bps INT NOT NULL DEFAULT 30, -- 0.30%
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. LP Positions (Providers)
CREATE TABLE IF NOT EXISTS lp_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_id UUID NOT NULL REFERENCES amm_pools(id) ON DELETE CASCADE,
    user_id UUID NOT NULL, -- Logical reference to Identity service
    lp_tokens_held NUMERIC(36, 18) NOT NULL DEFAULT 0.0 CHECK (lp_tokens_held >= 0),
    cumulative_fees_earned NUMERIC(36, 18) NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_pool_user UNIQUE (pool_id, user_id)
);

-- 3. Swaps Execution History
CREATE TABLE IF NOT EXISTS amm_swaps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_id UUID NOT NULL REFERENCES amm_pools(id),
    user_id UUID NOT NULL,
    token_in VARCHAR(16) NOT NULL,
    token_out VARCHAR(16) NOT NULL,
    amount_in NUMERIC(36, 18) NOT NULL CHECK (amount_in > 0),
    amount_out NUMERIC(36, 18) NOT NULL CHECK (amount_out > 0),
    fee_paid NUMERIC(36, 18) NOT NULL DEFAULT 0.0,
    price_impact_bps INT NOT NULL DEFAULT 0,
    tx_hash VARCHAR(128),
    executed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Liquidity Provisioning Events (Mints / Burns)
CREATE TABLE IF NOT EXISTS liquidity_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pool_id UUID NOT NULL REFERENCES amm_pools(id),
    user_id UUID NOT NULL,
    event_type VARCHAR(16) NOT NULL, -- ADD_LIQUIDITY, REMOVE_LIQUIDITY
    amount_a NUMERIC(36, 18) NOT NULL,
    amount_b NUMERIC(36, 18) NOT NULL,
    lp_tokens_delta NUMERIC(36, 18) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pools_tokens ON amm_pools(token_a, token_b);
CREATE INDEX IF NOT EXISTS idx_lp_user ON lp_positions(user_id);
CREATE INDEX IF NOT EXISTS idx_swaps_pool ON amm_swaps(pool_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_liquidity_events ON liquidity_events(pool_id, created_at DESC);
