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

JSON_FILE_INSIDE_ZIP="$FILENAME"
TMP_JSON="/tmp/backup_json_extracted_$$.json"

unzip -p "$ZIP_PATH" "$JSON_FILE_INSIDE_ZIP" > "$TMP_JSON" 2>/dev/null || {
    echo "❌ Failed to extract JSON from zip for parsing user info"
    rm -f "$TMP_JSON"
    ADMIN_INFO=""
}

if [ -f "$TMP_JSON" ]; then
    ADMIN_INFO=""
    ADMIN_UUIDS=$(jq -r '.admin_users[].uuid' "$TMP_JSON")
    for UUID in $ADMIN_UUIDS; do
        NAME=$(jq -r --arg uuid "$UUID" '.admin_users[] | select(.uuid == $uuid) | .name' "$TMP_JSON")
        USER_COUNT=$(jq --arg uuid "$UUID" '[.users[] | select(.added_by_uuid==$uuid)] | length' "$TMP_JSON")
        USER_ENABLED_COUNT=$(jq --arg uuid "$UUID" '[.users[] | select(.added_by_uuid==$uuid and .enable==true)] | length' "$TMP_JSON")
        ADMIN_INFO+="${NAME}: ${USER_COUNT} Users (${USER_ENABLED_COUNT} Enabled)
"
    done
    TOTAL_ADMINS=$(jq '.admin_users | length' "$TMP_JSON")
    rm -f "$TMP_JSON"
else
    ADMIN_INFO="Owner: ? Users (?)"
    TOTAL_ADMINS="?"
fi

CAPTION="🧠 <b>Hiddify Backup</b>
📁 <b>File:</b> ${FILENAME}
💾 <b>Size≈</b> ${FILE_SIZE}
🕒 <b>Date:</b> ${HUMAN_DATE}
🖥️ <b>Host:</b> ${HOSTNAME}
🌐 <b>IP:</b> <code>${SERVER_IP}</code>

👤 <b>Admin(s):</b>
${ADMIN_INFO}
🔄 <i>Auto-uploaded via HiddifyAutoBackup</i> 🚀

⭐️ <b>Love automation?</b> Show some ❤️ by starring the <a href=\"https://github.com/emadtoranji/HiddifyAutoBackup\">repo</a>!
Your star is your backup’s karma."

RESPONSE=$(curl -s --max-time 20 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" \
    -F chat_id="${TELEGRAM_CHAT_ID}" \
    -F document=@"${ZIP_PATH}" \
    -F parse_mode="HTML" \
    -F caption="${CAPTION}" \
    -F disable_web_page_preview=true)

if [[ "$RESPONSE" == *"true"* ]]; then
    echo "[✅] Backup sent to Telegram successfully."
else
    echo "❌ Failed to send file. Response: $RESPONSE"
fi

# Remove ZIP no matter what
{
    rm -f "$ZIP_PATH"
} || {
    echo "⚠️ Failed to remove backup zip: $ZIP_PATH (Check permissions)"
}

# Only run cleanup if current minute == 30
CURRENT_MINUTE=$(date +"%M")
if [ "$CURRENT_MINUTE" == "30" ]; then
    echo "[🕒] Minute is 30 — starting cleanup..."
    BACKUP_FILES=($(find "$HIDDIFY_BACKUP_DIR" -type f -mtime +3 -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-))
    if [ ${#BACKUP_FILES[@]} -gt 0 ]; then
        KEEP_FILE=$(find "$HIDDIFY_BACKUP_DIR" -type f -printf "%T@ %p\n" | sort -nr | head -n1 | cut -d' ' -f2-)
        REMOVED_COUNT=0
        for FILE in "${BACKUP_FILES[@]}"; do
            if [[ "$FILE" != "$KEEP_FILE" ]]; then
                {
                    rm -f "$FILE"
                    echo "[🧹] Removed old backup: $FILE"
                    ((REMOVED_COUNT++))
                } || {
                    echo "⚠️ Failed to delete file: $FILE"
                }
            fi
        done
        echo "[🧮] Cleanup complete. Total removed: $REMOVED_COUNT"
    else
        echo "[ℹ️] No old backups to remove."
    fi
else
    echo "[⏩] Skipping file cleanup. Minute ($CURRENT_MINUTE) ≠ 30"
fi
