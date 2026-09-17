#!/bin/bash
export TZ="America/Cuiaba"

set -euo pipefail

RCLONE="$HOME/bin/rclone"
BUCKET="s3:assessoriatech-backups-sispcard"

BACKUP_DIR="$HOME/backups"

DATE=$(date '+%Y-%m-%d')
DAY=$(date '+%d')
MONTH=$(date '+%m')

APP_FILE="$BACKUP_DIR/sispcard-application-${DATE}.tar.gz"

mkdir -p "$BACKUP_DIR"

cleanup() {
    rm -f "$APP_FILE"
}

trap cleanup EXIT

echo "[$(date '+%F %T')] Iniciando backup completo da aplicacao"

tar -czf "$APP_FILE" \
    -C "$HOME" \
    public_html

gzip -t "$APP_FILE"

echo "[$(date '+%F %T')] Arquivo gerado e validado"

"$RCLONE" copyto \
    "$APP_FILE" \
    "$BUCKET/application/weekly/$(basename "$APP_FILE")"

# Primeiro domingo / execucao semanal que cair no inicio do mes
if [ "$DAY" -le 7 ]; then
    "$RCLONE" copyto \
        "$APP_FILE" \
        "$BUCKET/application/monthly/$(basename "$APP_FILE")"
fi

# Janeiro, primeira semana do ano
if [ "$MONTH" = "01" ] && [ "$DAY" -le 7 ]; then
    "$RCLONE" copyto \
        "$APP_FILE" \
        "$BUCKET/application/yearly/$(basename "$APP_FILE")"
fi

echo "[$(date '+%F %T')] Backup completo concluido com sucesso"