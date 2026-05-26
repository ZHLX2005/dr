#!/bin/sh
STACK_DIR="$(dirname "$0")/../.."
BACKUP_DIR="$STACK_DIR/backup"
mkdir -p "$BACKUP_DIR"
for svc in cloud-grafana; do
  if [ -d "$STACK_DIR/cloud-grafana/data" ]; then
    tar czf "$BACKUP_DIR/${svc}-$(date +%Y%m%d_%H%M%S).tar.gz" -C "$STACK_DIR/cloud-grafana" data/ 2>/dev/null || true
  fi
done
echo "Stack backup saved to $BACKUP_DIR"
