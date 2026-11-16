#!/usr/bin/env bash
# ==============================================================================
# OENEXA Database Restoration Script
# Restores a compressed PostgreSQL custom-format dump into target database
# ==============================================================================
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <target_database> <backup_file.sql.gz>"
    echo "Example: $0 oengo_commerce_db /opt/oenexa/backups/postgres/oengo_commerce_db_20261116.sql.gz"
    exit 1
fi

TARGET_DB="$1"
BACKUP_FILE="$2"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' does not exist!"
    exit 1
fi

echo ">>> [OENEXA RESTORE] Restoring '$BACKUP_FILE' into database '$TARGET_DB'..."
read -p "WARNING: This will drop existing data in '$TARGET_DB'. Continue? (y/N): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    docker exec -i oenexa-postgres pg_restore -U postgres -d "$TARGET_DB" --clean --if-exists < "$BACKUP_FILE"
    echo "✓ Database '$TARGET_DB' restored successfully."
else
    echo "Restoration aborted by operator."
fi
