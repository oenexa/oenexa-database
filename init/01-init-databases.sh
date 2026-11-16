#!/usr/bin/env bash
# ==============================================================================
# OENEXA Enterprise Database Platform Master Initialization Script
# Automated Least-Privilege Provisioning & Schema Migration for All 9 Domains
# ==============================================================================
set -e

echo ">>> [OENEXA DB INIT] Starting Master Enterprise Database Provisioning..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMAS_DIR="$SCRIPT_DIR/../schemas"

# Function to create user, database, extensions, permissions, and apply schema
provision_domain_db() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"
    local schema_folder="$4"

    echo "-----------------------------------------------------------------"
    echo ">>> Provisioning Domain: Database '$db_name' for User '$db_user'..."

    # 1. Create Least-Privilege Role
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$db_user') THEN
                CREATE ROLE $db_user WITH LOGIN PASSWORD '$db_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
            ELSE
                ALTER ROLE $db_user WITH PASSWORD '$db_password';
            END IF;
        END
        \$\$;

        SELECT 'CREATE DATABASE $db_name OWNER $db_user'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db_name')\gexec

        REVOKE ALL ON DATABASE $db_name FROM PUBLIC;
        GRANT CONNECT, TEMPORARY ON DATABASE $db_name TO $db_user;
EOSQL

    # 2. Configure Extensions & Permissions inside Target Database
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        CREATE EXTENSION IF NOT EXISTS "pg_trgm";
        CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
        
        -- Enable pgvector if available
        DO \$\$
        BEGIN
            CREATE EXTENSION IF NOT EXISTS "vector";
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Vector extension skipped for %', '$db_name';
        END
        \$\$;

        GRANT USAGE, CREATE ON SCHEMA public TO $db_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $db_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $db_user;
EOSQL

    # 3. Apply Complete Relational Schema
    local schema_file="$SCHEMAS_DIR/$schema_folder/01_schema.sql"
    if [ -f "$schema_file" ]; then
        echo ">>> Applying relational schema from: $schema_file..."
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" -f "$schema_file"
        
        # Ensure service user owns all newly created tables
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $db_user;
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $db_user;
EOSQL
        echo "✓ Relational schema applied successfully to '$db_name'."
    else
        echo "Notice: Schema file not found at $schema_file, skipping DDL."
    fi
}

# -------------------------------------------------------------
# 9 Decoupled Enterprise Domain Databases
# -------------------------------------------------------------
provision_domain_db "${IDENTITY_DB_NAME:-oenexa_identity_db}" "${IDENTITY_DB_USER:-oenexa_identity_app}" "${IDENTITY_DB_PASSWORD:-StrongSecretIdentity2026!}" "01_identity"
provision_domain_db "${WALLET_DB_NAME:-oenexa_wallet_db}" "${WALLET_DB_USER:-oenexa_wallet_app}" "${WALLET_DB_PASSWORD:-StrongSecretWallet2026!}" "02_wallet"
provision_domain_db "${PAY_DB_NAME:-oenexa_pay_db}" "${PAY_DB_USER:-oenexa_pay_app}" "${PAY_DB_PASSWORD:-StrongSecretPay2026!}" "03_pay"
provision_domain_db "${EXCHANGE_DB_NAME:-oenexa_exchange_db}" "${EXCHANGE_DB_USER:-oenexa_exchange_app}" "${EXCHANGE_DB_PASSWORD:-StrongSecretExchange2026!}" "04_exchange"
provision_domain_db "${LIQUIDITY_DB_NAME:-oenexa_liquidity_db}" "${LIQUIDITY_DB_USER:-oenexa_liquidity_app}" "${LIQUIDITY_DB_PASSWORD:-StrongSecretLiquidity2026!}" "05_liquidity"
provision_domain_db "${AI_DB_NAME:-oenexa_ai_db}" "${AI_DB_USER:-oenexa_ai_app}" "${AI_DB_PASSWORD:-StrongSecretAi2026!}" "06_ai"
provision_domain_db "${MARKET_DATA_DB_NAME:-oenexa_market_data_db}" "${MARKET_DATA_DB_USER:-oenexa_market_data_app}" "${MARKET_DATA_DB_PASSWORD:-StrongSecretMarketData2026!}" "07_market_data"
provision_domain_db "${VALIDATOR_DB_NAME:-oenexa_validator_db}" "${VALIDATOR_DB_USER:-oenexa_validator_app}" "${VALIDATOR_DB_PASSWORD:-StrongSecretValidator2026!}" "08_validator"
provision_domain_db "${COMMERCE_DB_NAME:-oengo_commerce_db}" "${COMMERCE_DB_USER:-oengo_app}" "${COMMERCE_DB_PASSWORD:-StrongSecretCommerce2026!}" "09_commerce"

echo "-----------------------------------------------------------------"
echo ">>> [OENEXA DB INIT] ALL 9 DOMAIN DATABASES & RELATIONAL SCHEMAS PROVISIONED SUCCESSFULLY!"
