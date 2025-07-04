#!/usr/bin/env bash
set -e

SYMLINK="/usr/local/bin/hiddify-backup"
INSTALL_DIR="/opt/HiddifyAutoBackup"

crontab -l 2>/dev/null | grep -v "$SYMLINK" | crontab -
rm -f "$SYMLINK"
rm -rf "$INSTALL_DIR"

echo "✅ Uninstalled HiddifyAutoBackup"
