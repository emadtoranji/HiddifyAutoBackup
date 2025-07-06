#!/usr/bin/env bash
set -e

BACKUP_DIR="/opt/HiddifyAutoBackup"
HIDDIFY_DIR="/opt/hiddify-manager/hiddify-panel"
CONFIG_FILE="$BACKUP_DIR/.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
ZIP_PATH="${BACKUP_DIR}/hiddify_backup_${TIMESTAMP}.zip"

[ ! -d "$HIDDIFY_DIR" ] && echo "❌ Hiddify directory not found: $HIDDIFY_DIR" && exit 1

/opt/hiddify-manager/hiddify-panel/backup.sh || {
    echo "❌ Failed to run Hiddify backup script"
    exit 1
}

zip -r "$ZIP_PATH" "$HIDDIFY_DIR"
echo "[*] Created backup: $ZIP_PATH"

RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
     -F chat_id="${TELEGRAM_CHAT_ID}" \
     -F document=@"${ZIP_PATH}")

if [ "$RESPONSE" == "200" ]; then
    echo "[✓] Backup sent to Telegram successfully."
    rm -f "$ZIP_PATH"
else
    echo "❌ Failed to send file. HTTP code: $RESPONSE"
fi
