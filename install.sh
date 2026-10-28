#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/emadtoranji/HiddifyAutoBackup.git"
INSTALL_DIR="/opt/HiddifyAutoBackup"
CONFIG_FILE="$INSTALL_DIR/.env"
SYMLINK="/usr/local/bin/hiddify-backup"

# ─────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────

print_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║               HiddifyAutoBackup Setup 1.2.0               ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
}

print_section() {
    echo ""
    echo "──────────────────────────────────────"
    echo "  $*"
    echo "──────────────────────────────────────"
    echo ""
}

validate_token() {
    local token="$1" result
    result=$(printf 'url = "https://api.telegram.org/bot%s/getMe"\n' "$token" \
        | curl -s --max-time 10 -K -)
    [[ "$result" == *'"ok":true'* ]]
}

get_bot_name() {
    local token="$1"
    printf 'url = "https://api.telegram.org/bot%s/getMe"\n' "$token" \
        | curl -s --max-time 10 -K - \
        | jq -r '.result.username // "unknown"' 2>/dev/null || echo "unknown"
}

validate_chat_id() {
    local chat_id="$1" token="$2" result
    result=$(printf 'url = "https://api.telegram.org/bot%s/getChat?chat_id=%s"\n' "$token" "$chat_id" \
        | curl -s --max-time 10 -K -)
    [[ "$result" == *'"ok":true'* ]]
}

send_test_message() {
    local token="$1" chat_id="$2" topic_id="${3:-}"
    local result
    local CURL_ARGS=(
        '-F' "chat_id=${chat_id}"
        '-F' 'text=🔧 <b>HiddifyAutoBackup</b> — Test successful! ✅

Backups will be delivered here automatically.'
        '-F' 'parse_mode=HTML'
    )
    [[ -n "$topic_id" && "$topic_id" != "0" ]] && CURL_ARGS+=('-F' "message_thread_id=${topic_id}")
    result=$(printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$token" \
        | curl -s --max-time 15 -X POST -K - "${CURL_ARGS[@]}")
    if [[ "$result" == *'"ok":true'* ]]; then
        echo "ok"
    else
        local desc
        desc=$(printf '%s' "$result" \
            | jq -r '.description // "Unknown error"' 2>/dev/null || echo "Unknown error")
        echo "error:${desc}"
    fi
}

# ─────────────────────────────────────────────
#  Install dependencies
# ─────────────────────────────────────────────

print_banner
echo "[1/4] Installing dependencies..."
apt-get update -qq && apt-get install -y -qq git zip curl jq
echo "  ✅ Done."

# ─────────────────────────────────────────────
#  Clone / update repository
# ─────────────────────────────────────────────

echo ""
echo "[2/4] Fetching the latest version..."

# Back up existing config securely before wiping the install dir
TEMP_ENV=""
if [[ -f "$CONFIG_FILE" ]]; then
    TEMP_ENV=$(mktemp)
    chmod 600 "$TEMP_ENV"
    cp "$CONFIG_FILE" "$TEMP_ENV"
fi

rm -rf "$INSTALL_DIR"
if ! git clone -q "$REPO_URL" "$INSTALL_DIR"; then
    echo "  ❌ Failed to clone repository. Check your internet connection."
    if [[ -n "$TEMP_ENV" && -f "$TEMP_ENV" ]]; then
        mkdir -p "$INSTALL_DIR"
        mv "$TEMP_ENV" "$CONFIG_FILE"
        echo "  ✅ Your previous config has been restored."
    fi
    exit 1
fi
chmod +x "$INSTALL_DIR"/*.sh

# Restore backed-up config
if [[ -n "$TEMP_ENV" && -f "$TEMP_ENV" ]]; then
    mv "$TEMP_ENV" "$CONFIG_FILE"
fi

echo "  ✅ Installed to $INSTALL_DIR"

# ─────────────────────────────────────────────
#  Telegram configuration
# ─────────────────────────────────────────────

EDIT_CONFIG="false"

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        echo ""
        echo "  ✅ Existing Telegram config found."
        read -rp "  ⚙️  Update Telegram settings? [y/N]: " EDIT_CHOICE
        if [[ "$EDIT_CHOICE" =~ ^[Yy]$ ]]; then
            EDIT_CONFIG="true"
        else
            echo "  ℹ️  Keeping existing config."
        fi
    else
        EDIT_CONFIG="true"
    fi
else
    EDIT_CONFIG="true"
fi

if [[ "$EDIT_CONFIG" == "true" ]]; then

    print_section "📡 Telegram Setup"
    echo "  You'll need a bot token from @BotFather."
    echo ""

    TELEGRAM_TOKEN=""
    TELEGRAM_CHAT_ID=""
    TELEGRAM_TOPIC_ID=""
    DEST_CHOICE=""
    STEP="token"

    # ── State-machine interactive wizard ──────────────────────────────
    while true; do
        case "$STEP" in

            # ── Step 1: Bot Token ──────────────────────────────────────
            token)
                while true; do
                    read -rp "  🤖 Bot Token: " TELEGRAM_TOKEN
                    if [[ -z "$TELEGRAM_TOKEN" || "$TELEGRAM_TOKEN" =~ [[:space:]] ]]; then
                        echo "  ❌ Token cannot be empty or contain spaces."
                        continue
                    fi
                    printf "  ⏳ Verifying token..."
                    if validate_token "$TELEGRAM_TOKEN"; then
                        BOT_NAME=$(get_bot_name "$TELEGRAM_TOKEN")
                        printf "\r  ✅ Bot verified: @%s                  \n" "$BOT_NAME"
                        STEP="dest"
                        break
                    else
                        printf "\r  ❌ Invalid token. Copy it carefully from @BotFather.\n"
                    fi
                done
                ;;

            # ── Step 2: Destination type ───────────────────────────────
            dest)
                echo ""
                echo "  📬 Where should your backups be delivered?"
                echo ""
                echo "    1) 📩  Private Chat   — Your personal DM with the bot"
                echo "    2) 👥  Group Chat     — A Telegram group"
                echo "    3) 🗂️   Group + Topic  — A specific topic inside a group"
                echo ""
                echo "    b) ← Change bot token"
                echo ""
                while true; do
                    read -rp "  Choose [1/2/3] or [b]: " DEST_CHOICE
                    case "$DEST_CHOICE" in
                        1|2|3) STEP="chat_id"; break ;;
                        b)     STEP="token"; break ;;
                        *)     echo "  ❌ Please enter 1, 2, 3, or b." ;;
                    esac
                done
                ;;

            # ── Step 3: Chat ID ────────────────────────────────────────
            chat_id)
                echo ""
                case "$DEST_CHOICE" in
                    1)
                        echo "  💬 First, send /start to your bot in Telegram."
                        echo "     Then find your user ID via @userinfobot or @RawDataBot."
                        CHAT_LABEL="Your User ID or @username"
                        ;;
                    2|3)
                        echo "  👥 Add the bot to your group as Admin first."
                        echo "     Forward any group message to @RawDataBot to get the Chat ID."
                        CHAT_LABEL="Group Chat ID (e.g. -100123456789)"
                        ;;
                esac
                echo "    b) ← Change delivery destination"
                echo ""
                while true; do
                    read -rp "  ${CHAT_LABEL}: " TELEGRAM_CHAT_ID
                    case "$TELEGRAM_CHAT_ID" in
                        b) STEP="dest"; break ;;
                        "")
                            echo "  ❌ Chat ID cannot be empty."
                            ;;
                        *)
                            printf "  ⏳ Verifying chat..."
                            if validate_chat_id "$TELEGRAM_CHAT_ID" "$TELEGRAM_TOKEN"; then
                                printf "\r  ✅ Chat verified!                       \n"
                                if [[ "$DEST_CHOICE" == "3" ]]; then
                                    STEP="topic_id"
                                else
                                    STEP="test_send"
                                fi
                                break
                            else
                                printf "\r  ❌ Could not verify this Chat ID.       \n"
                                echo "     Make sure the bot is added to the chat."
                            fi
                            ;;
                    esac
                done
                ;;

            # ── Step 4: Topic ID (Group + Topic only) ──────────────────
            topic_id)
                echo ""
                echo "  🗂️  Enter the Topic (Thread) ID inside the group."
                echo "     How to find it: Forward any message from the topic to @RawDataBot"
                echo "     and look for 'message_thread_id' in the result."
                echo ""
                echo "    b) ← Change Chat ID"
                echo ""
                while true; do
                    read -rp "  Topic ID (positive number): " TELEGRAM_TOPIC_ID
                    case "$TELEGRAM_TOPIC_ID" in
                        b)
                            TELEGRAM_TOPIC_ID=""
                            STEP="chat_id"
                            break
                            ;;
                        ""|*[!0-9]*)
                            echo "  ❌ Topic ID must be a positive number (e.g. 42)."
                            ;;
                        *)
                            if [[ "$TELEGRAM_TOPIC_ID" -gt 0 ]]; then
                                STEP="test_send"
                                break
                            else
                                echo "  ❌ Topic ID must be greater than 0."
                            fi
                            ;;
                    esac
                done
                ;;

            # ── Step 5: Send test message ──────────────────────────────
            test_send)
                echo ""
                printf "  📤 Sending a test message to Telegram..."
                TEST_RESULT=$(send_test_message "$TELEGRAM_TOKEN" "$TELEGRAM_CHAT_ID" "$TELEGRAM_TOPIC_ID")
                if [[ "$TEST_RESULT" == "ok" ]]; then
                    printf "\r  ✅ Test message delivered!                 \n"
                    echo "     Check your Telegram — you should see a confirmation message. 👆"
                    STEP="save"
                else
                    ERR_DESC="${TEST_RESULT#error:}"
                    printf "\r  ❌ Test message failed!                    \n"
                    echo "     Telegram says: \"${ERR_DESC}\""
                    echo ""
                    echo "  What would you like to fix?"
                    echo ""
                    echo "    1) ← Change Chat ID"
                    if [[ -n "$TELEGRAM_TOPIC_ID" ]]; then
                        echo "    2) ← Change Topic ID"
                    fi
                    echo "    3) ← Change delivery destination"
                    echo "    4) ← Change bot token"
                    echo ""
                    while true; do
                        read -rp "  Choose: " BACK_CHOICE
                        case "$BACK_CHOICE" in
                            1)
                                TELEGRAM_CHAT_ID=""
                                TELEGRAM_TOPIC_ID=""
                                STEP="chat_id"
                                break
                                ;;
                            2)
                                if [[ -n "$TELEGRAM_TOPIC_ID" ]]; then
                                    TELEGRAM_TOPIC_ID=""
                                    STEP="topic_id"
                                    break
                                else
                                    echo "  ❌ Invalid choice."
                                fi
                                ;;
                            3)
                                TELEGRAM_CHAT_ID=""
                                TELEGRAM_TOPIC_ID=""
                                STEP="dest"
                                break
                                ;;
                            4)
                                TELEGRAM_TOKEN=""
                                TELEGRAM_CHAT_ID=""
                                TELEGRAM_TOPIC_ID=""
                                STEP="token"
                                break
                                ;;
                            *)
                                echo "  ❌ Invalid choice."
                                ;;
                        esac
                    done
                fi
                ;;

            # ── Step 6: Save configuration ─────────────────────────────
            save)
                {
                    printf 'TELEGRAM_TOKEN="%s"\n'   "$TELEGRAM_TOKEN"
                    printf 'TELEGRAM_CHAT_ID="%s"\n' "$TELEGRAM_CHAT_ID"
                    printf 'TELEGRAM_TOPIC_ID="%s"\n' "$TELEGRAM_TOPIC_ID"
                } > "$CONFIG_FILE"
                chmod 600 "$CONFIG_FILE"
                echo ""
                echo "  💾 Configuration saved."
                break
                ;;
        esac
    done

fi  # end EDIT_CONFIG

# ─────────────────────────────────────────────
#  Cron schedule
# ─────────────────────────────────────────────

print_section "🕒 Backup Schedule"
echo "  How often should backups run?"
echo "  (Duplicates are skipped automatically — frequent runs are safe)"
echo ""
echo "    1) Every 1 minute   (testing/debug)"
echo "    2) Every 2 minutes"
echo "    3) Every 5 minutes"
echo "    4) Every 15 minutes"
echo "    5) Every 20 minutes"
echo "    6) Every 30 minutes"
echo "    7) Every 60 minutes  (recommended)"
echo ""

while true; do
    read -rp "  Choose [1-7]: " CHOICE
    case "$CHOICE" in
        1) INTERVAL="* * * * *";    LABEL="every 1 minute";   break ;;
        2) INTERVAL="*/2 * * * *";  LABEL="every 2 minutes";  break ;;
        3) INTERVAL="*/5 * * * *";  LABEL="every 5 minutes";  break ;;
        4) INTERVAL="*/15 * * * *"; LABEL="every 15 minutes"; break ;;
        5) INTERVAL="*/20 * * * *"; LABEL="every 20 minutes"; break ;;
        6) INTERVAL="*/30 * * * *"; LABEL="every 30 minutes"; break ;;
        7) INTERVAL="0 * * * *";    LABEL="every 60 minutes"; break ;;
        *) echo "  ❌ Please enter a number between 1 and 7." ;;
    esac
done
echo "  ✅ Schedule: $LABEL"

# ─────────────────────────────────────────────
#  Symlink + Cron
# ─────────────────────────────────────────────

echo ""
echo "[3/4] Creating command symlink..."
ln -sf "$INSTALL_DIR/run.sh" "$SYMLINK"
echo "  ✅ hiddify-backup → $INSTALL_DIR/run.sh"

echo ""
echo "[4/4] Setting up cron job..."
CRON_TMP=$(mktemp)
chmod 600 "$CRON_TMP"
trap 'rm -f "$CRON_TMP"' EXIT
/usr/bin/crontab -u root -l 2>/dev/null | grep -v "$SYMLINK" > "$CRON_TMP" || true
echo "$INTERVAL $SYMLINK >> /var/log/hiddify_backup.log 2>&1" >> "$CRON_TMP"
crontab -u root "$CRON_TMP"
echo "  ✅ Cron job registered ($LABEL)"

# ─────────────────────────────────────────────
#  Done
# ─────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════╗"
echo "║   🎉 Installation Complete!      ║"
echo "╚══════════════════════════════════╝"
echo ""
echo "  📦 Manual backup:  sudo hiddify-backup"
echo "  📋 View logs:      tail -f /var/log/hiddify_backup.log"
echo "  🔄 Reinstall:      bash <(curl -sSL https://raw.githubusercontent.com/emadtoranji/HiddifyAutoBackup/main/install.sh)"
echo ""
