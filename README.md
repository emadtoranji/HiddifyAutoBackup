# HiddifyAutoBackup

📦 Automatically back up your Hiddify-Manager on schedule and deliver it straight to your Telegram Bot.

---

## ⚙️ Features
- 🗂️ **Smart Backup Packaging**  
  Compresses the latest Hiddify backup (`.json`) into a timestamped `.zip` file directly from source without unnecessary temporary extractions.
- 📬 **Flexible Telegram Destinations**  
  Send backups to your **Private Chat (DM)**, a **Telegram Group/Channel**, or a **Specific Topic (Forum Thread)** inside a Supergroup!
- ⚡ **High Performance & Smart Deduplication**  
  Single-pass `jq` parsing and automatic deduplication (`.last_sent`) — frequent cron runs skip redundant uploads instantly.
- 🔒 **Hardened Security**  
  Telegram bot tokens are masked from command-line arguments (`ps aux`) and temporary files use restricted `0600` permissions (`mktemp`).
- 🧪 **Live Connection Testing**  
  The interactive installer sends a test message to verify Telegram permissions before saving your configuration, complete with back-navigation.
- 🧹 **Automatic Expiry Cleanup**  
  Runs hourly at minute `:30` and purges backups older than 3 days, always keeping the latest one safe.
- 🔁 **Reconfigurable Wizard**  
  Rerun the installer anytime to update destinations, edit schedules, or tweak settings with full step-by-step back-navigation.

---

## 🚀 Installation

Run this one-liner on your Hiddify server as root:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/emadtoranji/HiddifyAutoBackup/main/install.sh)
```

---

## 📍 Manual Usage

Run the backup script manually anytime:

```bash
sudo hiddify-backup
```

To view automated backup logs:

```bash
tail -f /var/log/hiddify_backup.log
```

---

## 🧪 Testing

To run the automated test suite locally:

```bash
bash tests/test_logic.sh
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
