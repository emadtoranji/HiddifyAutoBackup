#!/usr/bin/env bash
set -e

REPO="emadtoranji/HiddifyAutoBackup"
INSTALL_DIR="/opt/HiddifyAutoBackup"
SYMLINK="/usr/local/bin/hiddify-backup"

# 📦 گرفتن آخرین نسخه Release
LATEST_TAG=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r .tag_name)

if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
    echo "❌ Could not determine latest release tag"
    exit 1
fi

echo "📦 Installing HiddifyAutoBackup version: $LATEST_TAG"

# 🚧 ساخت دایرکتوری نصب
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "[*] Downloading release ZIP..."
ZIP_URL="https://github.com/${REPO}/archive/refs/tags/${LATEST_TAG}.zip"
TMP_ZIP="/tmp/hiddify_backup_release.zip"
curl -sSL "$ZIP_URL" -o "$TMP_ZIP"

echo "[*] Extracting release..."
unzip -qo "$TMP_ZIP" -d /tmp

EXTRACTED_DIR="/tmp/HiddifyAutoBackup-${LATEST_TAG#v}"

echo "[*] Installing dependencies..."
apt-get update -y >/dev/null
apt-get install -y git python3 zip curl jq cron unzip >/dev/null

echo "[*] Moving files to $INSTALL_DIR"
rm -rf "$INSTALL_DIR/*"
cp -r "$EXTRACTED_DIR/." "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/install_release.sh"

echo "[*] Running release installer..."
cd "$INSTALL_DIR"
./install_release.sh

echo "✅ HiddifyAutoBackup $LATEST_TAG installed successfully!"
