#!/usr/bin/env bash
set -e

REPO="emadtoranji/HiddifyAutoBackup"
INSTALL_DIR="/opt/HiddifyAutoBackup"

LATEST_TAG=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep '"tag_name":' | cut -d '"' -f4)

if [[ -z "$LATEST_TAG" ]]; then
    echo "❌ Failed to get latest release tag"
    exit 1
fi

echo "📦 Installing HiddifyAutoBackup version: $LATEST_TAG"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
rm -rf ./*

echo "[*] Downloading release ZIP..."
curl -sL "https://github.com/$REPO/archive/refs/tags/${LATEST_TAG}.zip" -o release.zip

echo "[*] Extracting release..."
unzip -qo release.zip
cp -r "$INSTALL_DIR/HiddifyAutoBackup-${LATEST_TAG#v}/." "$INSTALL_DIR/"
rm -rf "$INSTALL_DIR/HiddifyAutoBackup-${LATEST_TAG#v}" release.zip

chmod +x "$INSTALL_DIR/install_release.sh"
"$INSTALL_DIR/install_release.sh"
