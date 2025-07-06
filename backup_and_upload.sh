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

# Extract JSON filename from zip (assumed json name is the original backup json file)
# اگر اسم json داخل zip متغیره، اینجا اصلاح کن به اسم واقعی
JSON_FILE_INSIDE_ZIP="$FILENAME"
TMP_JSON="/tmp/backup_json_extracted_$$.json"

unzip -p "$ZIP_PATH" "$JSON_FILE_INSIDE_ZIP" > "$TMP_JSON" 2>/dev/null || {
    echo "❌ Failed to extract JSON from zip for parsing user info"
    rm -f "$TMP_JSON"
    echo "[⚠️] Skipping user info details in caption."
    ADMIN_INFO=""
}


ADMIN_INFO=""
for UUID in $ADMIN_UUIDS; do
    NAME=$(jq -r --arg uuid "$UUID" '.admin_users[] | select(.uuid == $uuid) | .name' "$TMP_JSON")
    USER_COUNT=$(jq --arg uuid "$UUID" '[.users[] | select(.added_by_uuid==$uuid)] | length' "$TMP_JSON")
    USER_ENABLED_COUNT=$(jq --arg uuid "$UUID" '[.users[] | select(.added_by_uuid==$uuid and .enable==true)] | length' "$TMP_JSON")
    ADMIN_INFO+="${NAME}: ${USER_COUNT} Users (${USER_ENABLED_COUNT} Enabled)&#10;"
done

CAPTION="🧠 <b>Hiddify Backup</b>&#10;
📁 <b>File:</b> ${FILENAME}&#10;
💾 <b>Size:</b> ${FILE_SIZE}&#10;
🕒 <b>Date:</b> ${HUMAN_DATE}&#10;
🖥️ <b>Host:</b> ${HOSTNAME}&#10;
🌐 <b>IP:</b> <code>${SERVER_IP}</code>&#10;&#10;

👤 <b>Admin(s):</b> ${TOTAL_ADMINS}&#10;
${ADMIN_INFO}
🔄 <i>Auto-uploaded via HiddifyAutoBackup</i> 🚀&#10;&#10;

⭐️ <b>Love automation?</b> Show some ❤️ by starring the <a href=\"https://github.com/emadtoranji/HiddifyAutoBackup\">repo</a>! Your star is your backup’s karma."

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
    -F chat_id="${TELEGRAM_CHAT_ID}" \
    -F document=@"${ZIP_PATH}" \
    -F parse_mode="HTML" \
    -F caption="${CAPTION}" \
    -F disable_web_page_preview=true)

if [[ "$RESPONSE" == *"true"* ]]; then
    echo "[✅] Backup sent to Telegram successfully."
    rm -f "$ZIP_PATH"
else
    echo "❌ Failed to send file. Response: $RESPONSE"
fi
