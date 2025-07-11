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
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "$TEMP_ENV"
fi

echo "[*] Cloning the repo..."
rm -rf "$INSTALL_DIR"
git clone "$REPO_URL" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh

# Restore .env if backed up
if [[ -f "$TEMP_ENV" ]]; then
    mv "$TEMP_ENV" "$CONFIG_FILE"
fi

EDIT_CONFIG="false"

# Check if config exists and prompt
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        read -p "⚙️ Existing config found. Do you want to edit it? [y/N]: " EDIT_CHOICE
        if [[ "$EDIT_CHOICE" =~ ^[Yy]$ ]]; then
            EDIT_CONFIG="true"
        else
            echo "ℹ️ Keeping existing Telegram config."
        fi
    else
        EDIT_CONFIG="true"
    fi
else
    EDIT_CONFIG="true"
fi

# Validate Telegram token using getMe
function validate_token() {
    local token="$1"
    local result
    result=$(curl -s --max-time 10 "https://api.telegram.org/bot${token}/getMe")
    if [[ "$result" == *'"ok":true'* ]]; then
        return 0
    else
        echo "❌ Invalid Telegram Token. Make sure you copy it correctly from @BotFather."
        return 1
    fi
}

# Validate Chat ID (number or @username)
function validate_chat_id() {
    local chat_id="$1"
    local token="$2"
    local check_id="$chat_id"

    if [[ "$chat_id" =~ ^[0-9-]+$ ]]; then
        check_id="$chat_id"
    elif [[ "$chat_id" =~ ^@?[a-zA-Z0-9_]+$ ]]; then
        [[ "$chat_id" =~ ^@ ]] || check_id="@$chat_id"
    else
        echo "❌ Invalid Chat ID format. Use @username or numeric ID (e.g. @telegram or 123456789)."
        return 1
    fi

    local result
    result=$(curl -s --max-time 10 "https://api.telegram.org/bot${token}/getChat?chat_id=${check_id}")
    if [[ "$result" == *'"ok":true'* ]]; then
        TELEGRAM_CHAT_ID="$check_id"
        return 0
    else
        echo "❌ Chat ID validation failed. Make sure the bot has access to this chat."
        return 1
    fi
}

# Edit config if needed
if [[ "$EDIT_CONFIG" == "true" ]]; then
    while true; do
        read -p "Enter your Telegram Bot Token: " TELEGRAM_TOKEN
        if [[ -n "$TELEGRAM_TOKEN" && ! "$TELEGRAM_TOKEN" =~ [[:space:]] ]]; then
            validate_token "$TELEGRAM_TOKEN" && break
        fi
    done

    while true; do
        read -p "Enter your Telegram Chat ID (@username or numeric ID): " TELEGRAM_CHAT_ID
        validate_chat_id "$TELEGRAM_CHAT_ID" "$TELEGRAM_TOKEN" && break
    done

    echo "TELEGRAM_TOKEN=\"$TELEGRAM_TOKEN\"" > "$CONFIG_FILE"
    echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$CONFIG_FILE"
    echo "✅ Saved config to $CONFIG_FILE"
fi

# Ask for cron interval
echo "[*] Set backup interval in minutes:"
echo "   1) Every 1 minute"
echo "   2) Every 5 minutes"
echo "   3) Every 15 minutes"
echo "   4) Every 20 minutes"
echo "   5) Every 30 minutes"
echo "   6) Every 60 minutes"
read -p "Choose [1-6]: " CHOICE

case "$CHOICE" in
    1) INTERVAL="* * * * *" ;;
    2) INTERVAL="*/5 * * * *" ;;
    3) INTERVAL="*/15 * * * *" ;;
    4) INTERVAL="*/20 * * * *" ;;
    5) INTERVAL="30 * * * *" ;;
    6) INTERVAL="0 * * * *" ;;
    *) echo "❌ Invalid choice. Exiting."; exit 1 ;;
esac

echo "[*] Creating command symlink..."
ln -sf "$INSTALL_DIR/backup_and_upload.sh" "$SYMLINK"

echo "[*] Adding root cron job for: $INTERVAL"
/usr/bin/crontab -u root -l 2>/dev/null | grep -v "$SYMLINK" > /tmp/cron_bak.txt || true
echo "$INTERVAL root $SYMLINK >> /var/log/hiddify_backup.log 2>&1" >> /tmp/cron_bak.txt
cat /tmp/cron_bak.txt | crontab -u root -

echo "✅ Installation complete!"
echo "📦 You can run a backup manually with: sudo hiddify-backup"
