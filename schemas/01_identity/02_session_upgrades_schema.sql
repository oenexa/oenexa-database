-- ==============================================================================
-- OENEXA Identity Domain: Session Security & Anti-Enumeration Upgrades (02_session_upgrades_schema.sql)
-- Features: QR Login State Machine, Refresh Token Family Rotation, Trusted Devices
-- ==============================================================================

-- 1. Extend Sessions with Device Trust & "Stay Logged In"
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS is_trusted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS remember_choice BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS device_id VARCHAR(128);

-- 2. Token Families (Replay Attack & Rotation Registry)
CREATE TABLE IF NOT EXISTS token_families (
    family_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(128) NOT NULL,
    active_token_hash VARCHAR(64) NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    revocation_reason TEXT,
    stay_logged_in BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tf_user ON token_families(user_id);
CREATE INDEX IF NOT EXISTS idx_tf_token ON token_families(active_token_hash);

-- 3. QR Login Sessions State Machine
CREATE TYPE qr_session_status_enum AS ENUM ('PENDING', 'SCANNED', 'APPROVED', 'EXPIRED');

CREATE TABLE IF NOT EXISTS qr_login_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    qr_code_hash VARCHAR(64) UNIQUE NOT NULL,
    status qr_session_status_enum NOT NULL DEFAULT 'PENDING',
    scanner_device_id VARCHAR(128),
    approving_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_qr_status ON qr_login_sessions(status);
CREATE INDEX IF NOT EXISTS idx_qr_expires ON qr_login_sessions(expires_at);
