-- ==============================================================================
-- OENEXA Pay Domain Schema (oenexa_pay_db)
-- Tri-Rail Payment Gateway (ONXC Native, SEPA Instant, Card), Settlements & Payouts
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE payment_rail_enum AS ENUM ('ONXC_NATIVE', 'SEPA_INSTANT', 'CREDIT_CARD', 'LIGHTNING');
CREATE TYPE intent_status_enum AS ENUM ('REQUIRES_PAYMENT_METHOD', 'PENDING', 'PROCESSING', 'SUCCEEDED', 'CANCELED', 'FAILED');
CREATE TYPE settlement_status_enum AS ENUM ('PENDING', 'IN_FLIGHT', 'SETTLED', 'FAILED');

-- 1. Merchants Table (Payment Identity)
CREATE TABLE IF NOT EXISTS pay_merchants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- Logical reference to Identity service
    legal_name VARCHAR(255) NOT NULL,
    settlement_currency VARCHAR(16) NOT NULL DEFAULT 'EUR',
    webhook_url TEXT,
    webhook_secret VARCHAR(128) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Payment Intents
CREATE TABLE IF NOT EXISTS payment_intents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES pay_merchants(id),
    customer_id UUID,
    amount NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    currency VARCHAR(16) NOT NULL,
    rail payment_rail_enum NOT NULL DEFAULT 'ONXC_NATIVE',
    status intent_status_enum NOT NULL DEFAULT 'REQUIRES_PAYMENT_METHOD',
    idempotency_key VARCHAR(128) UNIQUE NOT NULL,
    description TEXT,
    metadata JSONB,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Invoices
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    intent_id UUID UNIQUE REFERENCES payment_intents(id) ON DELETE SET NULL,
    invoice_number VARCHAR(64) UNIQUE NOT NULL,
    merchant_id UUID NOT NULL REFERENCES pay_merchants(id),
    total_amount NUMERIC(18, 4) NOT NULL,
    tax_amount NUMERIC(18, 4) NOT NULL DEFAULT 0.0,
    currency VARCHAR(16) NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'ISSUED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Settlements & Multi-Rail Execution Records
CREATE TABLE IF NOT EXISTS settlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    intent_id UUID NOT NULL REFERENCES payment_intents(id),
    rail payment_rail_enum NOT NULL,
    gross_amount NUMERIC(18, 4) NOT NULL,
    fee_amount NUMERIC(18, 4) NOT NULL DEFAULT 0.0,
    net_amount NUMERIC(18, 4) NOT NULL,
    currency VARCHAR(16) NOT NULL,
    external_reference VARCHAR(128), -- On-chain tx hash or SEPA End-to-End ID
    status settlement_status_enum NOT NULL DEFAULT 'PENDING',
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. Webhook Events & Delivery Audits
CREATE TABLE IF NOT EXISTS webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id UUID NOT NULL REFERENCES pay_merchants(id),
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    response_code INT,
    attempts INT NOT NULL DEFAULT 1,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_attempt_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_merchants_user ON pay_merchants(user_id);
CREATE INDEX IF NOT EXISTS idx_intents_merchant ON payment_intents(merchant_id, status);
CREATE INDEX IF NOT EXISTS idx_intents_idem ON payment_intents(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_settlements_intent ON settlements(intent_id);
CREATE INDEX IF NOT EXISTS idx_settlements_ref ON settlements(external_reference) WHERE external_reference IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_webhooks_merchant ON webhook_deliveries(merchant_id, created_at DESC);
