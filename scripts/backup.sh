#!/usr/bin/env bash
# ==============================================================================
# OENEXA Automated Database Backup Script
# Creates compressed logical dumps for all isolated domain databases
# ==============================================================================
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/oenexa/backups/postgres}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS="${RETENTION_DAYS:-7}"

mkdir -p "$BACKUP_DIR"

DATABASES=(
    "oenexa_identity_db" "oenexa_wallet_db" "oenexa_pay_db"
    "oenexa_exchange_db" "oenexa_liquidity_db" "oenexa_ai_db"
    "oenexa_market_data_db" "oenexa_validator_db" "oengo_commerce_db"
)

echo ">>> [OENEXA BACKUP] Starting database backups at $TIMESTAMP..."

for db in "${DATABASES[@]}"; do
    TARGET_FILE="$BACKUP_DIR/${db}_${TIMESTAMP}.sql.gz"
    echo "Backing up database: $db to $TARGET_FILE..."
    
    docker exec -u postgres oenexa-postgres pg_dump -U postgres -Fc "$db" | gzip > "$TARGET_FILE"
    
    if [ $? -eq 0 ]; then
        SIZE=$(du -h "$TARGET_FILE" | cut -f1)
        echo "✓ Backup completed for $db ($SIZE)"
    else
        echo "✗ Backup FAILED for $db!"
    fi
done

echo ">>> Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo ">>> [OENEXA BACKUP] All backups completed successfully."
