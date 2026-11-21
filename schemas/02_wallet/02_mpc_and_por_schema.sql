-- ==============================================================================
-- OENEXA Wallet Domain Migration: Institutional MPC Custody & Proof of Reserves
-- Schema: oenexa_wallet_db
-- ==============================================================================

-- 1. Institutional MPC Derived Addresses
CREATE TABLE IF NOT EXISTS mpc_derived_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    asset VARCHAR(32) NOT NULL,
    network VARCHAR(64) NOT NULL,
    address VARCHAR(128) NOT NULL UNIQUE,
    derivation_path VARCHAR(128) NOT NULL,
    post_quantum_key_binding VARCHAR(128),
    vault_tier VARCHAR(16) NOT NULL DEFAULT 'HOT', -- HOT, WARM, COLD
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_account_asset_network UNIQUE (account_id, asset, network)
);

CREATE INDEX IF NOT EXISTS idx_mpc_address_lookup ON mpc_derived_addresses(address);
CREATE INDEX IF NOT EXISTS idx_mpc_account_asset ON mpc_derived_addresses(account_id, asset);

-- 2. Multi-Chain Blockchain Deposit Confirmation Events (Strict Idempotency)
CREATE TABLE IF NOT EXISTS blockchain_deposit_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network VARCHAR(32) NOT NULL, -- BITCOIN, ETHEREUM, TRON, SOLANA, ONXC_L1
    asset VARCHAR(32) NOT NULL,
    tx_hash VARCHAR(128) NOT NULL,
    log_index INT NOT NULL DEFAULT 0,
    block_number BIGINT NOT NULL,
    block_hash VARCHAR(128) NOT NULL,
    destination_address VARCHAR(128) NOT NULL,
    amount NUMERIC(36, 18) NOT NULL CHECK (amount > 0),
    confirmations INT NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'DETECTED', -- DETECTED, CONFIRMING, CONFIRMED, REORGED
    detected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    settled_at TIMESTAMPTZ,
    CONSTRAINT uq_network_tx_log UNIQUE (network, tx_hash, log_index)
);

CREATE INDEX IF NOT EXISTS idx_bde_status ON blockchain_deposit_events(status);
CREATE INDEX IF NOT EXISTS idx_bde_destination ON blockchain_deposit_events(destination_address);
CREATE INDEX IF NOT EXISTS idx_bde_block ON blockchain_deposit_events(network, block_number);

-- 3. Proof of Reserves (PoR) Merkle Attestations
CREATE TABLE IF NOT EXISTS proof_of_reserves_epochs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    epoch_id VARCHAR(64) UNIQUE NOT NULL,
    merkle_root VARCHAR(128) NOT NULL,
    total_liabilities_usd NUMERIC(36, 2) NOT NULL CHECK (total_liabilities_usd > 0),
    total_reserves_usd NUMERIC(36, 2) NOT NULL CHECK (total_reserves_usd >= total_liabilities_usd),
    reserve_ratio_percentage NUMERIC(6, 2) NOT NULL CHECK (reserve_ratio_percentage >= 100.0),
    on_chain_contract_address VARCHAR(128) NOT NULL,
    auditor_signature TEXT NOT NULL,
    attested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_por_epoch ON proof_of_reserves_epochs(epoch_id);
CREATE INDEX IF NOT EXISTS idx_por_date ON proof_of_reserves_epochs(attested_at DESC);
