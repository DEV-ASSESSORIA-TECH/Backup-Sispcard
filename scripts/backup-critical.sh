#!/bin/bash
export TZ="America/Cuiaba"

set -euo pipefail

RCLONE="$HOME/bin/rclone"
BUCKET="s3:assessoriatech-backups-sispcard"

BACKUP_DIR="$HOME/backups"
UPLOAD_DIR="$HOME/public_html/upload"

DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H%M')
DOW=$(date '+%u')       # 1=segunda ... 7=domingo
DAY=$(date '+%d')
MONTH=$(date '+%m')
YEAR=$(date '+%Y')

DB_FILE="$BACKUP_DIR/sispcard-db-${DATE}-${TIME}.sql.gz"
FILES_FILE="$BACKUP_DIR/sispcard-files-${DATE}-${TIME}.tar.gz"

mkdir -p "$BACKUP_DIR"

cleanup() {
    rm -f "$DB_FILE" "$FILES_FILE"
}

trap cleanup EXIT

echo "[$(date '+%F %T')] Iniciando backup critico"

# -------------------------------------------------
# Banco MySQL
# -------------------------------------------------

mysqldump \
    --single-transaction \
    --quick \
    --no-tablespaces \
    --routines \
    --triggers \
    --events \
    sispcard \
    | gzip > "$DB_FILE"

gzip -t "$DB_FILE"

echo "[$(date '+%F %T')] Dump MySQL OK"

# -------------------------------------------------
# Arquivos persistentes
# -------------------------------------------------

tar -czf "$FILES_FILE" \
    -C "$HOME/public_html" \
    upload

gzip -t "$FILES_FILE"

echo "[$(date '+%F %T')] Backup de uploads OK"

# -------------------------------------------------
# Funcao de upload
# -------------------------------------------------

upload_backup() {
    TIER="$1"

    echo "[$(date '+%F %T')] Enviando para $TIER"

    "$RCLONE" copyto \
        "$DB_FILE" \
        "$BUCKET/database/$TIER/$(basename "$DB_FILE")"

    "$RCLONE" copyto \
        "$FILES_FILE" \
        "$BUCKET/files/$TIER/$(basename "$FILES_FILE")"
}

# Sempre guarda como intraday
upload_backup "intraday"

# Backup das 20h vira copia diaria
if [ "$TIME" = "2000" ]; then
    upload_backup "daily"

    # Domingo
    if [ "$DOW" = "7" ]; then
        upload_backup "weekly"
    fi

    # Primeiro dia do mes
    if [ "$DAY" = "01" ]; then
        upload_backup "monthly"
    fi

    # Primeiro dia do ano
    if [ "$DAY" = "01" ] && [ "$MONTH" = "01" ]; then
        upload_backup "yearly"
    fi
fi

echo "[$(date '+%F %T')] Backup critico concluido com sucesso"