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

/opt/hiddify-manager/hiddify-panel/backup.sh || {
    echo "❌ Failed to run Hiddify backup script"
    exit 1
}

LATEST_FILE=$(find "$HIDDIFY_BACKUP_DIR" -type f -printf "%T@ %p\n" | sort -nr | head -n1 | cut -d' ' -f2-)

if [ -z "$LATEST_FILE" ]; then
    echo "❌ No backup file found in: $HIDDIFY_BACKUP_DIR"
    exit 1
fi

TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
HUMAN_DATE=$(date "+%Y-%m-%d %H:%M:%S")
FILENAME=$(basename "$LATEST_FILE")
ZIP_PATH="${BACKUP_DIR}/hiddify_backup_${TIMESTAMP}.zip"

cd "$(dirname "$LATEST_FILE")"
zip -j "$ZIP_PATH" "$FILENAME"

echo "[*] Created backup zip: $ZIP_PATH"

HOSTNAME=$(hostname)
SERVER_IP=$(hostname -I | awk '{print $1}')
FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

CAPTION="🧠 <b>Hiddify Backup</b>
📁 <b>File:</b> <code>${FILENAME}</code>
💾 <b>Size:</b> ${FILE_SIZE}
🕒 <b>Date:</b> ${HUMAN_DATE}
🖥️ <b>Host:</b> ${HOSTNAME}
🌐 <b>IP:</b> ${SERVER_IP}

🔄 <i>Auto-uploaded via</i> <a href=\"https://github.com/emadtoranji/HiddifyAutoBackup\">HiddifyAutoBackup</a> 🚀

⭐️ <b>Love automation?</b> Show some ❤️ by starring the repo! Your star is your backup’s karma."

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
    -F chat_id="${TELEGRAM_CHAT_ID}" \
    -F document=@"${ZIP_PATH}" \
    -F parse_mode="HTML" \
    -F caption="${CAPTION}")

if [[ "$RESPONSE" == *"true"* ]]; then
    echo "[✅] Backup sent to Telegram successfully."
    rm -f "$ZIP_PATH"

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
         -F chat_id="${TELEGRAM_CHAT_ID}" \
         -F parse_mode="HTML" \
         -F text="👤 Reminder: As admin, you're responsible for multiple users. 🧍‍♂️🧍‍♀️🧍‍♂️  
Keep your backups tight, your configs clean, and your stars shining at <a href='https://github.com/emadtoranji/HiddifyAutoBackup'>this repo</a> 💫"
else
    echo "❌ Failed to send file. Response: $RESPONSE"
fi
