-- ==============================================================================
-- OENEXA Validator Domain Schema (oenexa_validator_db)
-- PoS Consensus Validators, Post-Quantum Keys, Staking & Slashing Records
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE validator_status_enum AS ENUM ('CANDIDATE', 'ACTIVE', 'JAILED', 'UNBONDING', 'TOMBSTONED');

-- 1. Validators Registry
CREATE TABLE IF NOT EXISTS validators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    operator_address VARCHAR(128) UNIQUE NOT NULL,
    consensus_pubkey_pqc TEXT UNIQUE NOT NULL, -- NIST ML-DSA-65 post-quantum public key
    moniker VARCHAR(100) NOT NULL,
    website VARCHAR(255),
    commission_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.0500 CHECK (commission_rate BETWEEN 0 AND 1),
    max_commission_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.2000,
    status validator_status_enum NOT NULL DEFAULT 'CANDIDATE',
    total_staked_tokens NUMERIC(36, 18) NOT NULL DEFAULT 0.0 CHECK (total_staked_tokens >= 0),
    voting_power BIGINT NOT NULL DEFAULT 0,
    jailed_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Staking Delegations
CREATE TABLE IF NOT EXISTS delegations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    validator_id UUID NOT NULL REFERENCES validators(id),
    delegator_address VARCHAR(128) NOT NULL,
    staked_amount NUMERIC(36, 18) NOT NULL CHECK (staked_amount > 0),
    shares NUMERIC(36, 18) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_val_delegator UNIQUE (validator_id, delegator_address)
);

-- 3. Epoch Rewards Distribution
CREATE TABLE IF NOT EXISTS epoch_rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    epoch_number BIGINT NOT NULL,
    validator_id UUID NOT NULL REFERENCES validators(id),
    reward_tokens NUMERIC(36, 18) NOT NULL CHECK (reward_tokens >= 0),
    commission_tokens NUMERIC(36, 18) NOT NULL DEFAULT 0.0,
    distributed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_epoch_validator UNIQUE (epoch_number, validator_id)
);

-- 4. Slashing Audit Records (Misbehavior Punishment)
CREATE TABLE IF NOT EXISTS slashing_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    validator_id UUID NOT NULL REFERENCES validators(id),
    infraction_type VARCHAR(64) NOT NULL, -- DOUBLE_SIGN, DOWNTIME
    slashed_tokens NUMERIC(36, 18) NOT NULL,
    slash_percentage NUMERIC(5, 4) NOT NULL,
    block_height BIGINT NOT NULL,
    evidence JSONB,
    slashed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_validators_status ON validators(status, voting_power DESC);
CREATE INDEX IF NOT EXISTS idx_delegations_delegator ON delegations(delegator_address);
CREATE INDEX IF NOT EXISTS idx_rewards_epoch ON epoch_rewards(epoch_number);
CREATE INDEX IF NOT EXISTS idx_slashing_validator ON slashing_events(validator_id, slashed_at DESC);
