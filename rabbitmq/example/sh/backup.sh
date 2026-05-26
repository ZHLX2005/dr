#!/bin/sh
SERVICE_NAME="$(basename "$(dirname "$(dirname "$0")")")"
SERVICE_DIR="$(dirname "$0")/../.."
BACKUP_DIR="$SERVICE_DIR/backup"
mkdir -p "$BACKUP_DIR"
tar czf "$BACKUP_DIR/backup-$(date +%Y%m%d_%H%M%S).tar.gz" -C "$SERVICE_DIR/$SERVICE_NAME" data/ logs/ 2>/dev/null || true
echo "Backup saved to $BACKUP_DIR"
