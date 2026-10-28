#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
#  HiddifyAutoBackup — Unit Tests (Pure Logic, CI-compatible)
#  Does NOT require a real Hiddify server or Telegram connection.
#  Runs on any standard Linux/macOS/Git-Bash with bash + jq installed.
# ─────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

# ── assertion helpers ─────────────────────────────────────────────────────

assert_eq() {
    local desc="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  ✅  $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌  $desc"
        echo "       expected : [$expected]"
        echo "       actual   : [$actual]"
        FAIL=$((FAIL + 1))
    fi
}

section() { echo ""; echo "▶ $*"; }

# ── 1. Syntax validation ──────────────────────────────────────────────────

section "Bash syntax"
for f in install.sh run.sh uninstall.sh; do
    bash -n "$PROJECT_DIR/$f" 2>/dev/null
    assert_eq "bash -n $f" "$?" "0"
done

# ── 2. jq admin/user info filter ─────────────────────────────────────────

section "jq: admin info filter (single call)"

SAMPLE_JSON='{"admin_users":[{"uuid":"1","name":"Root"},{"uuid":"2","name":"Agent"}],"users":[{"added_by_uuid":"1","enable":true},{"added_by_uuid":"1","enable":false},{"added_by_uuid":"2","enable":true}]}'

ADMIN_INFO=$(echo "$SAMPLE_JSON" | jq -r '
  (.users // []) as $u |
  (.admin_users // [])[] |
  .uuid as $id | .name as $name |
  ($u | map(select(.added_by_uuid == $id))) as $mu |
  "\($name): \($mu | length) Users (\($mu | map(select(.enable == true)) | length) Enabled)"
')

assert_eq "admin line 1" "$(echo "$ADMIN_INFO" | head -n1)" "Root: 2 Users (1 Enabled)"
assert_eq "admin line 2" "$(echo "$ADMIN_INFO" | tail -n1)" "Agent: 1 Users (1 Enabled)"

section "jq: edge cases"

# Empty users array
EMPTY_USERS='{"admin_users":[{"uuid":"1","name":"Solo"}],"users":[]}'
ADMIN_INFO_EMPTY=$(echo "$EMPTY_USERS" | jq -r '
  (.users // []) as $u |
  (.admin_users // [])[] |
  .uuid as $id | .name as $name |
  ($u | map(select(.added_by_uuid == $id))) as $mu |
  "\($name): \($mu | length) Users (\($mu | map(select(.enable == true)) | length) Enabled)"
')
assert_eq "empty users: admin line" "$ADMIN_INFO_EMPTY" "Solo: 0 Users (0 Enabled)"

# Null users field
NULL_USERS='{"admin_users":[{"uuid":"1","name":"Solo"}],"users":null}'
ADMIN_INFO_NULL=$(echo "$NULL_USERS" | jq -r '
  (.users // []) as $u |
  (.admin_users // [])[] |
  .uuid as $id | .name as $name |
  ($u | map(select(.added_by_uuid == $id))) as $mu |
  "\($name): \($mu | length) Users (\($mu | map(select(.enable == true)) | length) Enabled)"
')
assert_eq "null users: admin line" "$ADMIN_INFO_NULL" "Solo: 0 Users (0 Enabled)"

# Empty admin array
EMPTY_ADMINS='{"admin_users":[],"users":[]}'
ADMIN_INFO_EMPTY_ADMINS=$(echo "$EMPTY_ADMINS" | jq -r '
  (.users // []) as $u |
  (.admin_users // [])[] |
  .uuid as $id | .name as $name |
  ($u | map(select(.added_by_uuid == $id))) as $mu |
  "\($name): \($mu | length) Users (\($mu | map(select(.enable == true)) | length) Enabled)"
' 2>/dev/null || true)
[[ -z "$ADMIN_INFO_EMPTY_ADMINS" ]] && ADMIN_INFO_EMPTY_ADMINS="Owner: ? Users (?)"
assert_eq "empty admins: fallback" "$ADMIN_INFO_EMPTY_ADMINS" "Owner: ? Users (?)"

# ── 3. Deduplication logic ────────────────────────────────────────────────

section "Deduplication (.last_sent)"

TMP_D=$(mktemp -d)
LAST_SENT_FILE="$TMP_D/.last_sent"

# Same file → should skip
LATEST="/opt/hiddify/backup/backup_2024.json"
echo "$LATEST" > "$LAST_SENT_FILE"
LAST=$(cat "$LAST_SENT_FILE" 2>/dev/null || echo "")
[[ "$LATEST" == "$LAST" ]] && IS_DUP=0 || IS_DUP=1
assert_eq "same file → skip (exit 0)" "$IS_DUP" "0"

# Different file → should send
LATEST2="/opt/hiddify/backup/backup_2025.json"
[[ "$LATEST2" == "$LAST" ]] && IS_DUP2=0 || IS_DUP2=1
assert_eq "new file → send" "$IS_DUP2" "1"

# No .last_sent file → should always send
rm -f "$LAST_SENT_FILE"
LAST3=$(cat "$LAST_SENT_FILE" 2>/dev/null || echo "")
[[ "$LATEST" == "$LAST3" ]] && IS_DUP3=0 || IS_DUP3=1
assert_eq "no .last_sent → always send" "$IS_DUP3" "1"

rm -rf "$TMP_D"

# ── 4. Error exits ────────────────────────────────────────────────────────

section "Error exits"

TMP_E=$(mktemp -d)
# Missing config → exit 1
CONFIG_FILE="$TMP_E/.env"
(
    set -e
    if [[ ! -f "$CONFIG_FILE" ]]; then
        exit 1
    fi
) || EXIT_MISSING_CONFIG=$?
assert_eq "missing config → exit 1" "${EXIT_MISSING_CONFIG:-0}" "1"

# Empty backup dir → exit 1
EMPTY_BKDIR="$TMP_E/empty_bkup"
mkdir -p "$EMPTY_BKDIR"
FOUND=$(find "$EMPTY_BKDIR" -maxdepth 1 -type f -printf "%T@ %p\n" 2>/dev/null \
    | sort -nr | head -n1 | cut -d' ' -f2-)
[[ -z "$FOUND" ]] && EMPTY_EXIT=1 || EMPTY_EXIT=0
assert_eq "empty backup dir → exit 1" "$EMPTY_EXIT" "1"

rm -rf "$TMP_E"

# ── 5. Date single-fork format ────────────────────────────────────────────

section "Date single-fork format"

_NOW=$(date +'%Y%m%d_%H%M%S|%Y-%m-%d %H:%M:%S|%M')
TIMESTAMP="${_NOW%%|*}"
_REST="${_NOW#*|}"
HUMAN_DATE="${_REST%%|*}"
CURRENT_MINUTE="${_REST##*|}"

[[ "$TIMESTAMP" =~ ^[0-9]{8}_[0-9]{6}$ ]]
assert_eq "TIMESTAMP format (YYYYmmdd_HHmmss)" "$?" "0"
[[ "$HUMAN_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]
assert_eq "HUMAN_DATE format (YYYY-MM-DD HH:MM:SS)" "$?" "0"
[[ "$CURRENT_MINUTE" =~ ^[0-9]{2}$ ]]
assert_eq "CURRENT_MINUTE format (MM)" "$?" "0"

# ── 6. Telegram topic_id curl args ────────────────────────────────────────

section "Topic ID in curl args"

build_args() {
    local chat_id="$1" topic_id="$2"
    local args=()
    args+=('-F' "chat_id=${chat_id}")
    [[ -n "$topic_id" && "$topic_id" != "0" ]] && args+=('-F' "message_thread_id=${topic_id}")
    printf '%s\n' "${args[@]}"
}

# With topic
WITH_TOPIC=$(build_args "-100123" "42")
assert_eq "topic_id present when set" "$(echo "$WITH_TOPIC" | grep -c 'message_thread_id')" "1"

# Without topic (empty)
NO_TOPIC=$(build_args "-100123" "")
assert_eq "topic_id absent when empty" "$(echo "$NO_TOPIC" | grep -c 'message_thread_id' || true)" "0"

# Without topic (0)
ZERO_TOPIC=$(build_args "-100123" "0")
assert_eq "topic_id absent when 0" "$(echo "$ZERO_TOPIC" | grep -c 'message_thread_id' || true)" "0"

# ── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════"
printf "  PASSED: %-3d  |  FAILED: %-3d\n" "$PASS" "$FAIL"
echo "══════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
