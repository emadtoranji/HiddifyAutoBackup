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

# Restore .env
if [[ -f "$TEMP_ENV" ]]; then
    mv "$TEMP_ENV" "$CONFIG_FILE"
fi

TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        read -p "⚙️ Existing config found. Do you want to edit it? [y/N]: " EDIT_CHOICE
        if [[ "$EDIT_CHOICE" =~ ^[Yy]$ ]]; then
            TELEGRAM_TOKEN=""
            TELEGRAM_CHAT_ID=""
        else
            echo "ℹ️ Keeping existing Telegram config."
        fi
    fi
fi

# --- TELEGRAM TOKEN VALIDATION ---
while true; do
    read -p "Enter your Telegram Bot Token (cannot be empty): " TELEGRAM_TOKEN
    if [[ -z "$TELEGRAM_TOKEN" || "$TELEGRAM_TOKEN" =~ [[:space:]] ]]; then
        echo "❌ Token cannot be empty or contain spaces."
        continue
    fi

    API_RESPONSE=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getMe")
    if echo "$API_RESPONSE" | jq -e '.ok == true' >/dev/null; then
        echo "✅ Token is valid."
        break
    else
        echo "❌ Invalid token. Please double-check your Bot Token from @BotFather."
    fi
done

# --- TELEGRAM CHAT ID VALIDATION ---
while true; do
    read -p "Enter your Telegram Chat ID (@username or numeric ID): " RAW_ID

    # Check if it's numeric
    if [[ "$RAW_ID" =~ ^-?[0-9]+$ && "$RAW_ID" != "0" ]]; then
        CHAT_ID="$RAW_ID"
    else
        # Alphanumeric username validation
        if [[ "$RAW_ID" =~ ^@?[a-zA-Z0-9_]{5,}$ ]]; then
            [[ "$RAW_ID" =~ ^@ ]] && CHAT_ID="$RAW_ID" || CHAT_ID="@$RAW_ID"
        else
            echo "❌ Invalid username. Use only a-z, A-Z, 0-9 and optional starting '@'."
            echo "ℹ️ Example: @telegram"
            continue
        fi
    fi

    CHAT_RESPONSE=$(curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/getChat?chat_id=$CHAT_ID")
    if echo "$CHAT_RESPONSE" | jq -e '.ok == true' >/dev/null; then
        echo "✅ Chat ID is valid."
        break
    else
        echo "❌ Chat ID is invalid or bot does not have access to this chat."
    fi
done

# Save config
echo "TELEGRAM_TOKEN=\"$TELEGRAM_TOKEN\"" > "$CONFIG_FILE"
echo "TELEGRAM_CHAT_ID=\"$CHAT_ID\"" >> "$CONFIG_FILE"

# --- CRON INTERVAL CHOICE ---
echo "⏱️ How often should the backup run?"
select MINUTES in 1 5 15 20 30 60; do
    case $MINUTES in
        1|5|15|20|30|60) break ;;
        *) echo "❌ Invalid choice. Pick from 1, 5, 15, 20, 30, 60." ;;
    esac
done

# Create symlink
echo "[*] Creating command symlink..."
ln -sf "$INSTALL_DIR/backup_and_upload.sh" "$SYMLINK"

# Set up cron as root
CRON_CMD="*/$MINUTES * * * * root $SYMLINK >> /var/log/hiddify_backup.log 2>&1"

echo "[*] Setting up root cron job every $MINUTES minute(s)..."
# Backup root crontab before editing
CRON_FILE="/etc/cron.d/hiddify_backup"
echo "$CRON_CMD" > "$CRON_FILE"
chmod 644 "$CRON_FILE"

echo "✅ Installation complete."
echo "Run backup manually anytime using: hiddify-backup"
echo "Cron job scheduled every $MINUTES minute(s) via /etc/cron.d/hiddify_backup"
