#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Configurable paths (can be overridden for testing)
# ─────────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-/opt/HiddifyAutoBackup}"
HIDDIFY_BACKUP_DIR="${HIDDIFY_BACKUP_DIR:-/opt/hiddify-manager/hiddify-panel/backup}"
HIDDIFY_BACKUP_SCRIPT="${HIDDIFY_BACKUP_SCRIPT:-/opt/hiddify-manager/hiddify-panel/backup.sh}"
CONFIG_FILE="$BACKUP_DIR/.env"
LAST_SENT_FILE="$BACKUP_DIR/.last_sent"

# ─────────────────────────────────────────────
#  Check config file
# ─────────────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    echo "   Run the installer: bash install.sh"
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# ─────────────────────────────────────────────
#  Run Hiddify backup script
# ─────────────────────────────────────────────
echo "[*] Triggering Hiddify backup..."
if ! "$HIDDIFY_BACKUP_SCRIPT" > /dev/null 2>&1; then
    echo "❌ Hiddify backup script failed: $HIDDIFY_BACKUP_SCRIPT"
    exit 1
fi

# ─────────────────────────────────────────────
#  Find latest backup file
# ─────────────────────────────────────────────
LATEST_FILE=$(find "$HIDDIFY_BACKUP_DIR" -maxdepth 1 -type f -printf "%T@ %p\n" 2>/dev/null \
    | sort -nr | head -n1 | cut -d' ' -f2-)

if [[ -z "$LATEST_FILE" ]]; then
    echo "❌ No backup file found in: $HIDDIFY_BACKUP_DIR"
    exit 1
fi

# ─────────────────────────────────────────────
#  Deduplication — skip if already sent
# ─────────────────────────────────────────────
LAST_SENT=$(cat "$LAST_SENT_FILE" 2>/dev/null || echo "")
if [[ "$LATEST_FILE" == "$LAST_SENT" ]]; then
    echo "⏭️  Backup is already up-to-date — nothing new to send."
    exit 0
fi

# ─────────────────────────────────────────────
#  Collect timestamps (single fork)
# ─────────────────────────────────────────────
_NOW=$(date +'%Y%m%d_%H%M%S|%Y-%m-%d %H:%M:%S|%M')
TIMESTAMP="${_NOW%%|*}"
_REST="${_NOW#*|}"
HUMAN_DATE="${_REST%%|*}"
CURRENT_MINUTE="${_REST##*|}"

# ─────────────────────────────────────────────
#  Create ZIP from original backup file
# ─────────────────────────────────────────────
FILENAME=$(basename "$LATEST_FILE")
ZIP_PATH="${BACKUP_DIR}/hiddify_backup_${TIMESTAMP}.zip"

# Ensure ZIP is always removed on exit (success or failure)
trap 'rm -f "$ZIP_PATH"' EXIT

zip -j "$ZIP_PATH" "$LATEST_FILE" > /dev/null
FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo "[*] Packed: $(basename "$ZIP_PATH") ($FILE_SIZE)"

# ─────────────────────────────────────────────
#  Server metadata
# ─────────────────────────────────────────────
HOSTNAME=$(hostname)
SERVER_IP=$(hostname -I | awk '{print $1}')

# ─────────────────────────────────────────────
#  Parse admin/user info — single jq call
#  Reads directly from the original JSON file (no /tmp extraction needed)
# ─────────────────────────────────────────────
ADMIN_INFO=$(jq -r '
  (.users // []) as $u |
  (.admin_users // [])[] |
  .uuid as $id | .name as $name |
  ($u | map(select(.added_by_uuid == $id))) as $mu |
  "\($name): \($mu | length) Users (\($mu | map(select(.enable == true)) | length) Enabled)"
' "$LATEST_FILE" 2>/dev/null || true)

if [[ -z "$ADMIN_INFO" ]]; then
    ADMIN_INFO="Owner: ? Users (?)"
fi

# ─────────────────────────────────────────────
#  Build Telegram caption
# ─────────────────────────────────────────────
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

# ─────────────────────────────────────────────
#  Build curl args dynamically (topic support)
# ─────────────────────────────────────────────
TOPIC_ID="${TELEGRAM_TOPIC_ID:-}"

CURL_ARGS=(
    '-F' "chat_id=${TELEGRAM_CHAT_ID}"
    '-F' "document=@${ZIP_PATH}"
    '-F' 'parse_mode=HTML'
    '-F' "caption=${CAPTION}"
    '-F' 'disable_web_page_preview=true'
)
[[ -n "$TOPIC_ID" && "$TOPIC_ID" != "0" ]] && \
    CURL_ARGS+=('-F' "message_thread_id=${TOPIC_ID}")

# ─────────────────────────────────────────────
#  Send to Telegram (token hidden from process table)
# ─────────────────────────────────────────────
RESPONSE=$(printf 'url = "https://api.telegram.org/bot%s/sendDocument"\n' "$TELEGRAM_TOKEN" \
    | curl -s --max-time 60 -X POST -K - "${CURL_ARGS[@]}")

if [[ "$RESPONSE" == *'"ok":true'* ]]; then
    echo "✅ Backup delivered to Telegram successfully."
    echo "$LATEST_FILE" > "$LAST_SENT_FILE"
else
    ERR=$(printf '%s' "$RESPONSE" | jq -r '.description // "Unknown error"' 2>/dev/null \
        || echo "Unknown error")
    echo "❌ Telegram delivery failed: $ERR"
    echo "   Full response: $RESPONSE"
    exit 1
fi

# ─────────────────────────────────────────────
#  Cleanup old backups (once per hour, at minute :30)
# ─────────────────────────────────────────────
if [[ "$CURRENT_MINUTE" == "30" ]]; then
    echo "[🕒] Running scheduled cleanup of old backups..."
    mapfile -t OLD_FILES < <(
        find "$HIDDIFY_BACKUP_DIR" -maxdepth 1 -type f -mtime +3 \
            ! -samefile "$LATEST_FILE" -printf "%T@ %p\n" 2>/dev/null \
            | sort -n | cut -d' ' -f2-
    )
    if [[ ${#OLD_FILES[@]} -gt 0 ]]; then
        REMOVED=0
        for FILE in "${OLD_FILES[@]}"; do
            if rm -f "$FILE" 2>/dev/null; then
                echo "  🧹 Removed: $(basename "$FILE")"
                REMOVED=$((REMOVED + 1))
            else
                echo "  ⚠️  Could not remove: $FILE"
            fi
        done
        echo "  🧮 Cleanup done. Removed ${REMOVED} of ${#OLD_FILES[@]} old file(s)."
    else
        echo "  ℹ️  No old backups to clean up."
    fi
else
    echo "[⏩] Next cleanup at minute :30 (current: :${CURRENT_MINUTE})"
fi
