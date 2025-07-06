#!/usr/bin/env bash
set -e

read -p "Enter your Telegram Bot Token: " TELEGRAM_TOKEN
read -p "Enter your Telegram Chat ID (@username or numeric ID): " TELEGRAM_CHAT_ID

REPO_URL="https://github.com/emadtoranji/HiddifyAutoBackup.git"
INSTALL_DIR="/opt/HiddifyAutoBackup"
SYMLINK="/usr/local/bin/hiddify-backup"

echo "[*] Installing dependencies..."
apt-get update && apt-get install -y git python3 zip curl

echo "[*] Cloning the repo..."
rm -rf "$INSTALL_DIR"
git clone "$REPO_URL" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/*.sh

echo "[*] Creating config..."
echo "TELEGRAM_TOKEN=\"$TELEGRAM_TOKEN\"" > "$INSTALL_DIR/.env"
echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$INSTALL_DIR/.env"

echo "[*] Creating command symlink..."
ln -sf "$INSTALL_DIR/backup_and_upload.sh" "$SYMLINK"

echo "[*] Setting up cron job every 5 minutes..."
( crontab -l 2>/dev/null | grep -v "$SYMLINK" ; echo "*/5 * * * * $SYMLINK >> /var/log/hiddify_backup.log 2>&1" ) | crontab -

echo "[*] Done. You can now run: hiddify-backup"
