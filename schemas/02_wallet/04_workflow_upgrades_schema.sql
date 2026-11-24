-- ==============================================================================
-- OENEXA Wallet Domain: Workflow & Custody Safety Upgrades (04_workflow_upgrades_schema.sql)
-- Features: Transaction State Machine, Address Whitelist Cooling-off, P2P Escrow, Region Consents
-- ==============================================================================

-- 1. Extend Transactions Table with Comprehensive State Machine & Hold Links
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS hold_journal_id VARCHAR(64);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS settle_journal_id VARCHAR(64);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS required_confirmations INT NOT NULL DEFAULT 12;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS failure_reason TEXT;

-- 2. Address Whitelist with 24-Hour Cooling-Off Period
CREATE TABLE IF NOT EXISTS address_whitelist (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    asset VARCHAR(32) NOT NULL,
    network VARCHAR(32) NOT NULL,
    address VARCHAR(128) NOT NULL,
    label VARCHAR(100) NOT NULL,
    cooling_off_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_whitelist_addr UNIQUE (user_id, asset, network, address)
);

CREATE INDEX IF NOT EXISTS idx_aw_user ON address_whitelist(user_id);
CREATE INDEX IF NOT EXISTS idx_aw_cooling ON address_whitelist(cooling_off_until);

-- 3. Region Safety Gate Consents ("Things to know" consent per zone)
CREATE TABLE IF NOT EXISTS region_safety_consents (
    user_id UUID NOT NULL,
    zone VARCHAR(32) NOT NULL,
    version VARCHAR(32) NOT NULL,
    ip_address INET,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, zone)
);

-- 4. Peer-to-Peer (P2P) Escrow Orders
CREATE TYPE p2p_escrow_state_enum AS ENUM (
    'OFFER_MATCHED',
    'ASSET_LOCKED',
    'BUYER_PAID',
    'ESCROW_RELEASED',
    'TIMEOUT_CANCELLED',
    'DISPUTED',
    'RESOLVED'
);

CREATE TABLE IF NOT EXISTS p2p_escrow_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_user_id UUID NOT NULL,
    buyer_user_id UUID NOT NULL,
    asset VARCHAR(32) NOT NULL,
    asset_amount NUMERIC(36, 18) NOT NULL CHECK (asset_amount > 0),
    fiat_currency VARCHAR(8) NOT NULL,
    fiat_amount NUMERIC(18, 4) NOT NULL CHECK (fiat_amount > 0),
    state p2p_escrow_state_enum NOT NULL DEFAULT 'ASSET_LOCKED',
    escrow_hold_journal_id VARCHAR(64),
    escrow_release_journal_id VARCHAR(64),
    payment_window_seconds INT NOT NULL DEFAULT 900, -- 15 mins
    expires_at TIMESTAMPTZ NOT NULL,
    paid_at TIMESTAMPTZ,
    released_at TIMESTAMPTZ,
    dispute_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_p2p_seller ON p2p_escrow_orders(seller_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_buyer ON p2p_escrow_orders(buyer_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_state ON p2p_escrow_orders(state);
