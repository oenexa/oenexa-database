-- ==============================================================================
-- OENEXA Wallet Domain Schema (oenexa_wallet_db)
-- Multi-Asset Custody, Double-Entry General Ledger, Shielded Notes & Sweeps
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE account_type_enum AS ENUM ('SETTLEMENT', 'CUSTODY', 'TRADING', 'SHIELDED', 'ESCROW');
CREATE TYPE entry_direction_enum AS ENUM ('DEBIT', 'CREDIT');
CREATE TYPE transfer_status_enum AS ENUM ('PENDING', 'PROCESSING', 'SETTLED', 'FAILED', 'REVERSED');

-- 1. Wallet Accounts
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- Logical reference to Identity service
    account_number VARCHAR(64) UNIQUE NOT NULL,
    account_type account_type_enum NOT NULL DEFAULT 'TRADING',
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Balances per Asset
CREATE TABLE IF NOT EXISTS account_balances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    asset VARCHAR(32) NOT NULL, -- e.g. ONXC, USDT, BTC, EUR
    available_balance NUMERIC(36, 18) NOT NULL DEFAULT 0.0 CHECK (available_balance >= 0),
    locked_balance NUMERIC(36, 18) NOT NULL DEFAULT 0.0 CHECK (locked_balance >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_account_asset UNIQUE (account_id, asset)
);

-- 3. General Ledger Journal Entries (Double-Entry Bookkeeping)
CREATE TABLE IF NOT EXISTS journal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    correlation_id VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    posted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ledger_postings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    journal_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id),
    asset VARCHAR(32) NOT NULL,
    direction entry_direction_enum NOT NULL,
    amount NUMERIC(36, 18) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Shielded Notes (Zero-Knowledge Privacy Layer)
CREATE TABLE IF NOT EXISTS shielded_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id),
    asset VARCHAR(32) NOT NULL,
    amount NUMERIC(36, 18) NOT NULL CHECK (amount > 0),
    commitment_hash VARCHAR(128) UNIQUE NOT NULL,
    nullifier_hash VARCHAR(128) UNIQUE,
    is_spent BOOLEAN NOT NULL DEFAULT FALSE,
    spent_tx_hash VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    spent_at TIMESTAMPTZ
);

-- 5. Deposits & Withdrawals
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id UUID NOT NULL REFERENCES accounts(id),
    tx_type VARCHAR(32) NOT NULL, -- DEPOSIT, WITHDRAWAL, INTERNAL_TRANSFER
    asset VARCHAR(32) NOT NULL,
    amount NUMERIC(36, 18) NOT NULL CHECK (amount > 0),
    fee NUMERIC(36, 18) NOT NULL DEFAULT 0.0,
    status transfer_status_enum NOT NULL DEFAULT 'PENDING',
    tx_hash VARCHAR(128),
    destination_address VARCHAR(128),
    confirmations INT NOT NULL DEFAULT 0,
    idempotency_key VARCHAR(128) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_balances_account ON account_balances(account_id);
CREATE INDEX IF NOT EXISTS idx_ledger_journal ON ledger_postings(journal_id);
CREATE INDEX IF NOT EXISTS idx_ledger_account ON ledger_postings(account_id, asset);
CREATE INDEX IF NOT EXISTS idx_shielded_commitment ON shielded_notes(commitment_hash);
CREATE INDEX IF NOT EXISTS idx_shielded_nullifier ON shielded_notes(nullifier_hash) WHERE nullifier_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_hash ON transactions(tx_hash) WHERE tx_hash IS NOT NULL;
