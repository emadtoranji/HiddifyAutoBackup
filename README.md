# HiddifyAutoBackup

📦 Auto backup your Hiddify panel (`/etc/hiddify`) every 5 minutes and send it to your Telegram via bot.

---

## ⚙️ Features

- Automatic zip backup of `/etc/hiddify`
- Sends `.zip` file to Telegram
- Deletes backup file after successful upload
- Cron runs every 5 minutes
- One-line install

---

## 🚀 Installation

```bash
bash <(curl -sSL https://raw.githubusercontent.com/emadtoranji/HiddifyAutoBackup/main/install.sh)
```

---

## 📍 Manually Usage

Navigate into the installation folder and run the backup script manually:

```bash
cd /opt/HiddifyAutoBackup
bash backup_and_upload.sh
```

---

## 🧹 Uninstall

To fully remove HiddifyAutoBackup from your system:

```bash
sudo rm -rf /opt/HiddifyAutoBackup
sudo rm -f /usr/local/bin/hiddify-backup
sudo crontab -l | grep -v 'hiddify-backup' | crontab -
