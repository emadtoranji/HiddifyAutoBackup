#!/usr/bin/env bash
set -e

BACKUP_DIR="/opt/HiddifyAutoBackup"
HIDDIFY_BACKUP_DIR="/opt/hiddify-manager/hiddify-panel/backup"
CONFIG_FILE="$BACKUP_DIR/.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Run the backup script
/opt/hiddify-manager/hiddify-panel/backup.sh || {
    echo "❌ Failed to run Hiddify backup script"
    exit 1
}

# Get the most recently created backup file
LATEST_FILE=$(find "$HIDDIFY_BACKUP_DIR" -type f -printf "%T@ %p\n" | sort -nr | head -n1 | cut -d' ' -f2-)

if [ -z "$LATEST_FILE" ]; then
    echo "❌ No backup file found in: $HIDDIFY_BACKUP_DIR"
    exit 1
fi

TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
FILENAME=$(basename "$LATEST_FILE")
ZIP_PATH="${BACKUP_DIR}/hiddify_backup_${TIMESTAMP}.zip"

# Create flat zip (no folders)
cd "$(dirname "$LATEST_FILE")"
zip -j "$ZIP_PATH" "$FILENAME"

echo "[*] Created backup zip: $ZIP_PATH"

# Gather info for caption
HOSTNAME=$(hostname)
SERVER_IP=$(hostname -I | awk '{print $1}')
FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

CAPTION="🧠 Hiddify Backup
📁 File: ${FILENAME}
💾 Size: ${FILE_SIZE}
🕒 Date: ${TIMESTAMP}
🖥️ Host: ${HOSTNAME}
🌐 IP: ${SERVER_IP}
🔁 Auto-uploaded via HiddifyAutoBackup"

# Upload to Telegram
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
    -F chat_id="${TELEGRAM_CHAT_ID}" \
    -F caption="${CAPTION}" \
    -F document=@"${ZIP_PATH}")

if [ "$RESPONSE" == "200" ]; then
    echo "[✅] Backup sent to Telegram successfully."
    rm -f "$ZIP_PATH"
else
    echo "❌ Failed to send file. HTTP code: $RESPONSE"
fi
