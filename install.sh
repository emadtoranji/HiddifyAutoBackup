#!/usr/bin/env bash
set -e

REPO="emadtoranji/HiddifyAutoBackup"
INSTALL_DIR="/opt/HiddifyAutoBackup"

LATEST_TAG=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep '"tag_name":' | cut -d '"' -f4)

if [[ -z "$LATEST_TAG" ]]; then
    echo "❌ Could not determine latest release tag"
    exit 1
fi

echo "📦 Downloading latest release: $LATEST_TAG"

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

curl -sL "https://github.com/$REPO/archive/refs/tags/${LATEST_TAG}.zip" -o release.zip

unzip -qo release.zip
mkdir -p "$INSTALL_DIR"
cp -r "$TMP_DIR/HiddifyAutoBackup-${LATEST_TAG#v}/." "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/install_release.sh"

"$INSTALL_DIR/install_release.sh"
