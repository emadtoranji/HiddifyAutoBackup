# HiddifyAutoBackup

📦 Automatically back up your Hiddify-Manager on schedule and deliver it straight to your Telegram Bot.

---

## ⚙️ Features
- 🗂️ Smart Backup Packaging  
  Automatically compresses the latest Hiddify backup (.json) into a timestamped (.zip) file.
- 📤 Telegram Integration  
  Securely sends the backup to your specified Telegram chat via a verified bot.
- 🧹 Cleanup After Upload  
  Deletes the (.zip) after a successful upload to keep your server clutter-free.
- 🕒 Flexible Scheduling Options  
  Choose from common intervals like 1m, 2m, 5m, 15m, 30m, hourly — tailored to your backup needs.
- 🗑️ Automatic Expiry Cleanup  
  Checks hourly and deletes backups older than 3 days — only the latest one is kept for safety.
- ✅ Setup Validation  
  Verifies your Telegram bot token and chat ID during setup to prevent errors.
- 🔁 Reconfigurable Installer  
  Rerun the installer anytime to update bot settings or tweak your backup schedule.
- 🧵 One-Line Installation  
  No fuss. Just one command to kick things off.

---

## 🚀 Installation

```bash
bash <(curl -sSL https://raw.githubusercontent.com/emadtoranji/HiddifyAutoBackup/main/install.sh)
```

---

## 📍 Manually Usage

run the backup script manually:

```bash
sudo hiddify-backup
```

---

## 💸 Donate

This tool is 100% free and open-source, built with ❤️ for sysadmins and devs who love automation.

If this saved your time or prevented disaster, feel free to buy me a ☕️ or send some crypto 🚀

**Wallets:**

- TON: `UQC85EfTOzO3Kn868mQdes5E5pnkRRBy_9DyFUyjwTazq3wT`

- TRC-20: `TSyrrScMorisqSVwBo9igtiqVfvTkSrtLc`

- BEP-20: `0xB3525f7872477dD6B004F8E2cd6413CDf3306dAd`

---

## 🧹 Uninstall

To fully remove HiddifyAutoBackup from your system:

```bash
sudo rm -rf /opt/HiddifyAutoBackup
sudo rm -f /usr/local/bin/hiddify-backup
sudo crontab -l | grep -v 'hiddify-backup' | crontab -
```
