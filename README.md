# HiddifyAutoBackup

📦 Auto backup your Hiddify-Manager every 5 minutes and send it to your Telegram Bot.

---

## ⚙️ Features

- Automatically compresses your latest Hiddify backup JSON into a .zip file using timestamped naming.
- Sends the backup file to your specified Telegram chat using a verified bot.
- Deletes the backup file after it's successfully uploaded — keeping your server clean.
- Choose from multiple time intervals (1m, 2m, 5m, 15m, 30m, hourly...)
- Every hour, it checks the backup folder and deletes backup files older than 3 days — only the latest is kept.
- Validates your Telegram token and chat ID during setup to avoid misconfiguration.
- Run the installer again to update your Telegram bot/token or change schedule.
- One-line install

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
