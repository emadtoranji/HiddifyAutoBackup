#!/usr/bin/env bash
set -e

# Automatically get latest release tag from GitHub
LATEST_TAG=$(curl -s https://api.github.com/repos/emadtoranji/HiddifyAutoBackup/releases/latest | grep '"tag_name":' | cut -d '"' -f4)

if [[ -z "$LATEST_TAG" ]]; then
    echo "❌ Failed to fetch latest release tag. Falling back to main branch."
    bash <(curl -sSL "https://raw.githubusercontent.com/emadtoranji/HiddifyAutoBackup/main/install_release.sh")
    exit 0
fi

echo "📦 Installing HiddifyAutoBackup version: $LATEST_TAG..."

bash <(curl -sSL "https://raw.githubusercontent.com/emadtoranji/HiddifyAutoBackup/${LATEST_TAG}/install_release.sh")
