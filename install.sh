#!/usr/bin/env bash
set -e

REPO="emadtoranji/HiddifyAutoBackup"
INSTALL_DIR="/opt/HiddifyAutoBackup"

LATEST_TAG=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r .tag_name)

if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
    echo "❌ Could not determine latest release tag"
    exit 1
fi

echo "📦 Installing HiddifyAutoBackup version: $LATEST_TAG"
echo "[*] Downloading release ZIP..."

TMP_DIR=$(mktemp -d)
ZIP_URL="https://github.com/$REPO/archive/refs/tags/$LATEST_TAG.zip"

curl -sSL "$ZIP_URL" -o "$TMP_DIR/release.zip"

echo "[*] Extracting release..."
unzip -qo "$TMP_DIR/release.zip" -d "$TMP_DIR"

EXTRACTED_DIR="$TMP_DIR/HiddifyAutoBackup-${LATEST_TAG#v}"

echo "[*] Installing dependencies..."
apt-get update -y >/dev/null
apt-get install -y git python3 zip curl jq >/dev/null

echo "[*] Installing to $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$EXTRACTED_DIR/." "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/install_release.sh"

cd "$INSTALL_DIR"
./install_release.sh
