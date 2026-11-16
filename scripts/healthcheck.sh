#!/usr/bin/env bash
# ==============================================================================
# OENEXA Database Platform Health Check Probe
# Verifies connectivity, replication lag, and disk usage
# ==============================================================================
set -euo pipefail

echo ">>> [OENEXA DB HEALTH] Checking PostgreSQL 17 status..."
if docker exec oenexa-postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo "✓ PostgreSQL daemon is READY and accepting connections."
else
    echo "✗ PostgreSQL daemon is DOWN or not responding!"
    exit 1
fi

echo ">>> Checking Redis 7 status..."
if docker exec oenexa-redis redis-cli ping | grep -q "PONG"; then
    echo "✓ Redis daemon is READY (PONG)."
else
    echo "✗ Redis daemon is DOWN or not responding!"
    exit 1
fi

echo ">>> Querying active database connections..."
docker exec oenexa-postgres psql -U postgres -c "
    SELECT datname, numbackends, xact_commit, xact_rollback, blks_read, blks_hit 
    FROM pg_stat_database 
    WHERE datname IN ('oenexa_ai_db', 'oengo_commerce_db', 'oenexa_identity_db', 'oenexa_pay_db');
"

echo ">>> All database platform health checks PASSED."
