#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/emadtoranji/HiddifyAutoBackup.git"
INSTALL_DIR="/opt/HiddifyAutoBackup"
CONFIG_FILE="$INSTALL_DIR/.env"
TEMP_ENV="/tmp/hiddifyautobackup_env.tmp"
SYMLINK="/usr/local/bin/hiddify-backup"

echo "[*] Installing dependencies..."
apt-get update && apt-get install -y git python3 zip curl

# Backup .env if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "$TEMP_ENV"
fi

echo "[*] Cloning the repo..."
rm -rf "$INSTALL_DIR"
git clone "$REPO_URL" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh

# Restore .env if available
if [[ -f "$TEMP_ENV" ]]; then
    mv "$TEMP_ENV" "$CONFIG_FILE"
fi

TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        read -p "⚙️ Existing configuration found. Do you want to edit it? [y/N]: " EDIT_CHOICE
        if [[ "$EDIT_CHOICE" =~ ^[Yy]$ ]]; then
            read -p "Enter your Telegram Bot Token: " TELEGRAM_TOKEN
            read -p "Enter your Telegram Chat ID (@username or numeric ID): " TELEGRAM_CHAT_ID
        else
            echo "ℹ️ Keeping existing Telegram config."
        fi
    else
        echo "⚠️ Config file is incomplete. Asking for missing values."
        read -p "Enter your Telegram Bot Token: " TELEGRAM_TOKEN
        read -p "Enter your Telegram Chat ID (@username or numeric ID): " TELEGRAM_CHAT_ID
    fi
else
    echo "[*] Creating new config..."
    read -p "Enter your Telegram Bot Token: " TELEGRAM_TOKEN
    read -p "Enter your Telegram Chat ID (@username or numeric ID): " TELEGRAM_CHAT_ID
fi

# Save updated or fresh config
echo "TELEGRAM_TOKEN=\"$TELEGRAM_TOKEN\"" > "$CONFIG_FILE"
echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$CONFIG_FILE"

echo "[*] Creating command symlink..."
ln -sf "$INSTALL_DIR/backup_and_upload.sh" "$SYMLINK"

echo "[*] Setting up cron job every 5 minutes..."
( crontab -l 2>/dev/null | grep -v "$SYMLINK" ; echo "*/5 * * * * $SYMLINK >> /var/log/hiddify_backup.log 2>&1" ) | crontab -

echo "✅ Installation complete. Use 'hiddify-backup' to run manually."
