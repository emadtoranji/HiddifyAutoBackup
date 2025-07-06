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
bash /opt/HiddifyAutoBackup/backup_and_upload.sh
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
