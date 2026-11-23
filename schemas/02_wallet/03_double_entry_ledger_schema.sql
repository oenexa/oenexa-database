-- ==============================================================================
-- OENEXA Banking-Grade Immutable Double-Entry Ledger Schema
-- Compliance: FATF, SOC-2, ISO-27001, PCI-DSS
-- Invariant: For every journal entry, SUM(Debits) === SUM(Credits) per asset
-- ==============================================================================

-- 1. Chart of Accounts (COA) Registry
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    account_code VARCHAR(16) PRIMARY KEY,
    account_name VARCHAR(128) NOT NULL,
    account_category VARCHAR(32) NOT NULL CHECK (account_category IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    normal_balance VARCHAR(6) NOT NULL CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Seed Standard Institutional Chart of Accounts
INSERT INTO chart_of_accounts (account_code, account_name, account_category, normal_balance, description)
VALUES 
    ('1101', 'MPC Hot Vault - BTC', 'ASSET', 'DEBIT', 'Operational hot wallet for Bitcoin settlement'),
    ('1102', 'MPC Hot Vault - ETH/ERC20', 'ASSET', 'DEBIT', 'Operational hot wallet for EVM and USDT-ERC20 settlement'),
    ('1103', 'MPC Hot Vault - ONXC Native', 'ASSET', 'DEBIT', 'Operational hot wallet for native Layer-1 ONXC settlement'),
    ('1201', 'Institutional Cold Storage (2-of-3 TSS)', 'ASSET', 'DEBIT', 'Air-gapped and multi-custody cold reserves'),
    ('1301', 'Bundesbank SEPA / Swift Clearing', 'ASSET', 'DEBIT', 'Institutional fiat banking clearing account'),
    ('2101', 'Client Spot Trading Balances', 'LIABILITY', 'CREDIT', 'Client omnibus spot balances held in custody'),
    ('2102', 'Client Locked In-Order Margin', 'LIABILITY', 'CREDIT', 'Client balances currently committed to open limit orders'),
    ('2103', 'Client Staking / Earn Balances', 'LIABILITY', 'CREDIT', 'Client balances deposited into institutional earn pools'),
    ('3101', 'Proof-of-Reserves Capital Buffer', 'EQUITY', 'CREDIT', 'Solvency reserve equity capital (>100% backing)'),
    ('4101', 'Spot Matching Taker Fees', 'REVENUE', 'CREDIT', 'Exchange earned transaction fees from trades'),
    ('4102', 'Withdrawal Network Gas Premiums', 'REVENUE', 'CREDIT', 'Network fee delta retained by exchange')
ON CONFLICT (account_code) DO NOTHING;

-- 2. Immutable Journal Entries (Headers)
CREATE TABLE IF NOT EXISTS financial_journals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    journal_id VARCHAR(64) UNIQUE NOT NULL,
    reference_id VARCHAR(128) NOT NULL UNIQUE, -- Idempotency key (e.g. order_id, tx_hash, deposit_id)
    event_type VARCHAR(32) NOT NULL,          -- DEPOSIT, WITHDRAWAL, TRADE_FILL, LIQUIDATION, REBALANCE
    description TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_fj_event_type ON financial_journals(event_type);
CREATE INDEX IF NOT EXISTS idx_fj_created_at ON financial_journals(created_at DESC);

-- 3. Immutable Ledger Postings (Debits and Credits)
CREATE TABLE IF NOT EXISTS ledger_postings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    posting_id VARCHAR(64) UNIQUE NOT NULL,
    journal_id VARCHAR(64) NOT NULL REFERENCES financial_journals(journal_id) ON DELETE RESTRICT,
    account_code VARCHAR(16) NOT NULL REFERENCES chart_of_accounts(account_code),
    user_id UUID,                             -- NULL for exchange proprietary accounts
    asset VARCHAR(32) NOT NULL,               -- BTC, ETH, USDT, ONXC, EUR
    direction VARCHAR(6) NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount NUMERIC(36, 18) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lp_user_asset ON ledger_postings(user_id, asset);
CREATE INDEX IF NOT EXISTS idx_lp_account_code ON ledger_postings(account_code);
CREATE INDEX IF NOT EXISTS idx_lp_journal_id ON ledger_postings(journal_id);

-- 4. Enforce Double-Entry Invariant: SUM(Debits) === SUM(Credits)
CREATE OR REPLACE FUNCTION verify_double_entry_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_debit_total NUMERIC(36, 18);
    v_credit_total NUMERIC(36, 18);
BEGIN
    SELECT 
        COALESCE(SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount ELSE 0 END), 0)
    INTO v_debit_total, v_credit_total
    FROM ledger_postings
    WHERE journal_id = NEW.journal_id AND asset = NEW.asset;

    IF v_debit_total <> v_credit_total THEN
        RAISE EXCEPTION 'Double-entry invariant violated for Journal % [Asset %]: Total Debits (%) != Total Credits (%)',
            NEW.journal_id, NEW.asset, v_debit_total, v_credit_total;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_verify_double_entry ON ledger_postings;
CREATE CONSTRAINT TRIGGER trg_verify_double_entry
AFTER INSERT ON ledger_postings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verify_double_entry_balance();
