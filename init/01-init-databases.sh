#!/usr/bin/env bash
# ==============================================================================
# OENEXA Enterprise Database Platform Initialization Script
# Automated Least-Privilege Provisioning for Autonomous Microservices
# ==============================================================================
set -e

echo ">>> [OENEXA DB INIT] Starting Enterprise Database Provisioning..."

# Function to create user and database with least privilege
create_service_db() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"

    echo ">>> Provisioning Isolated Domain: Database '$db_name' for User '$db_user'..."

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        -- Create user if not exists
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$db_user') THEN
                CREATE ROLE $db_user WITH LOGIN PASSWORD '$db_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
            ELSE
                ALTER ROLE $db_user WITH PASSWORD '$db_password';
            END IF;
        END
        \$\$;

        -- Create database owned by service user
        SELECT 'CREATE DATABASE $db_name OWNER $db_user'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db_name')\gexec

        -- Revoke all public privileges
        REVOKE ALL ON DATABASE $db_name FROM PUBLIC;
        GRANT CONNECT, TEMPORARY ON DATABASE $db_name TO $db_user;
EOSQL

    # Enable required extensions inside the target database
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        CREATE EXTENSION IF NOT EXISTS "pg_trgm";
        CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
        -- Enable pgvector for AI and embedding domains
        CREATE EXTENSION IF NOT EXISTS "vector";

        -- Set search path and schema permissions
        GRANT USAGE, CREATE ON SCHEMA public TO $db_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $db_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $db_user;
EOSQL

    echo ">>> Database '$db_name' successfully provisioned with extensions and least-privilege security."
}

# 1. AI Central Intelligence & Multi-Agent Swarm Database
create_service_db "${AI_DB_NAME:-oenexa_ai_db}" "${AI_DB_USER:-oenexa_ai_app}" "${AI_DB_PASSWORD:-StrongSecretAi2026!}"

# 2. OenGo Quick-Commerce & Relayer Escrow Database
create_service_db "${COMMERCE_DB_NAME:-oengo_commerce_db}" "${COMMERCE_DB_USER:-oengo_app}" "${COMMERCE_DB_PASSWORD:-StrongSecretCommerce2026!}"

# 3. Sovereign Identity & Access Management (OIDC) Database
create_service_db "${IDENTITY_DB_NAME:-oenexa_identity_db}" "${IDENTITY_DB_USER:-oenexa_identity_app}" "${IDENTITY_DB_PASSWORD:-StrongSecretIdentity2026!}"

# 4. Tri-Rail Payment & Fiat Gateway Database
create_service_db "${PAY_DB_NAME:-oenexa_pay_db}" "${PAY_DB_USER:-oenexa_pay_app}" "${PAY_DB_PASSWORD:-StrongSecretPay2026!}"

echo ">>> [OENEXA DB INIT] All enterprise domain databases provisioned successfully!"
