#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/emadtoranji/HiddifyAutoBackup.git"
INSTALL_DIR="/opt/HiddifyAutoBackup"
CONFIG_FILE="$INSTALL_DIR/.env"
TEMP_ENV="/tmp/hiddifyautobackup_env.tmp"
SYMLINK="/usr/local/bin/hiddify-backup"

echo "[*] Installing dependencies..."
apt-get update && apt-get install -y git python3 zip curl jq

# Backup .env if exists
[[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "$TEMP_ENV"

echo "[*] Cloning latest release..."
rm -rf "$INSTALL_DIR"
git clone --depth 1 --branch "$(basename "$(dirname "$0")")" "$REPO_URL" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh

# Restore .env if exists
[[ -f "$TEMP_ENV" ]] && mv "$TEMP_ENV" "$CONFIG_FILE"

EDIT_CONFIG="false"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        read -p "⚙️ Existing config found. Do you want to edit it? [y/N]: " EDIT_CHOICE
        [[ "$EDIT_CHOICE" =~ ^[Yy]$ ]] && EDIT_CONFIG="true" || echo "ℹ️ Keeping existing Telegram config."
    else
        EDIT_CONFIG="true"
    fi
else
    EDIT_CONFIG="true"
fi

validate_token() {
    [[ "$(curl -s --max-time 10 "https://api.telegram.org/bot${1}/getMe")" == *'"ok":true'* ]]
}

validate_chat_id() {
    [[ "$(curl -s --max-time 10 "https://api.telegram.org/bot${2}/getChat?chat_id=${1}")" == *'"ok":true'* ]]
}

if [[ "$EDIT_CONFIG" == "true" ]]; then
    while true; do
        read -p "Enter your Telegram Bot Token: " TELEGRAM_TOKEN
        [[ -n "$TELEGRAM_TOKEN" && ! "$TELEGRAM_TOKEN" =~ [[:space:]] ]] && validate_token "$TELEGRAM_TOKEN" && break
        echo "❌ Invalid token. Try again."
    done

    while true; do
        read -p "Enter your Telegram Chat ID (@username or numeric ID): " TELEGRAM_CHAT_ID
        validate_chat_id "$TELEGRAM_CHAT_ID" "$TELEGRAM_TOKEN" && break
        echo "❌ Invalid chat ID. Try again."
    done

    echo "TELEGRAM_TOKEN=\"$TELEGRAM_TOKEN\"" > "$CONFIG_FILE"
    echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$CONFIG_FILE"
    echo "✅ Saved config to $CONFIG_FILE"
fi

echo "[*] Set backup interval in minutes:"
echo "   1) Every 1 minute"
echo "   2) Every 2 minutes"
echo "   3) Every 5 minutes"
echo "   4) Every 15 minutes"
echo "   5) Every 20 minutes"
echo "   6) Every 30 minutes"
echo "   7) Every 60 minutes"

while true; do
    read -p "Choose [1-7]: " CHOICE
    case "$CHOICE" in
        1) INTERVAL="* * * * *"; break ;;
        2) INTERVAL="*/2 * * * *"; break ;;
        3) INTERVAL="*/5 * * * *"; break ;;
        4) INTERVAL="*/15 * * * *"; break ;;
        5) INTERVAL="*/20 * * * *"; break ;;
        6) INTERVAL="30 * * * *"; break ;;
        7) INTERVAL="0 * * * *"; break ;;
        *) echo "❌ Invalid choice. Please enter a number between 1 and 7." ;;
    esac
done

echo "[*] Creating symlink to $SYMLINK"
ln -sf "$INSTALL_DIR/backup_and_upload.sh" "$SYMLINK"

echo "[*] Adding root cron job for: $INTERVAL"
/usr/bin/crontab -u root -l 2>/dev/null | grep -v "$SYMLINK" > /tmp/cron_bak.txt || true
echo "$INTERVAL sudo $SYMLINK >> /var/log/hiddify_backup.log 2>&1" >> /tmp/cron_bak.txt
crontab -u root /tmp/cron_bak.txt

echo "✅ Installation complete!"
echo "📦 Run backup manually: sudo hiddify-backup"
