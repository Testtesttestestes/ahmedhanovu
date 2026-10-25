#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/login_watch.log"
INPUT_FILE=""

usage() {
  echo "Usage: $0 [--log-file PATH] [--input-file PATH]" >&2
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-file) LOG_FILE="${2:?missing path}"; shift 2;;
    --input-file) INPUT_FILE="${2:?missing path}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) usage; exit 2;;
  esac
done

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
running=true
stop_watcher() { running=false; }
trap stop_watcher INT TERM

notify() {
  local message="$1"
  printf '\033[1;32m[login-watch] %s\033[0m\n' "$message"
  if command -v logger >/dev/null 2>&1; then
    logger -t login-watch -- "$message" || true
  fi
}

extract_login() {
  local line="$1" timestamp user source
  # sshd: "Accepted ... for USER from IP port ..."
  if [[ "$line" =~ Accepted[[:space:]]+[^[:space:]]+[[:space:]]+for[[:space:]]+([^[:space:]]+)[[:space:]]+from[[:space:]]+([^[:space:]]+) ]]; then
    user="${BASH_REMATCH[1]}"; source="${BASH_REMATCH[2]}"
  # local login: "LOGIN ... USER ... on tty"
  elif [[ "$line" =~ user[[:space:]]+([^[:space:]]+)[[:space:]]+on[[:space:]]+([^[:space:]]+) ]]; then
    user="${BASH_REMATCH[1]}"; source="${BASH_REMATCH[2]}"
  else
    return 0
  fi
  timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
  local record="time=$timestamp user=$user source=$source"
  printf '%s\n' "$record" >> "$LOG_FILE"
  notify "$record"
}

if [[ -n "$INPUT_FILE" ]]; then
  # Test/demo mode consumes a file as a journal-like stream.
  coproc LOGIN_STREAM { tail -n 0 -F "$INPUT_FILE" 2>/dev/null; }
else
  if command -v journalctl >/dev/null 2>&1; then
    coproc LOGIN_STREAM { journalctl -f -n 0 -o short-iso 2>/dev/null; }
  elif [[ -r /var/log/auth.log ]]; then
    coproc LOGIN_STREAM { tail -n 0 -F /var/log/auth.log 2>/dev/null; }
  else
    echo "No journalctl or readable /var/log/auth.log" >&2
    exit 1
  fi
fi
source_pid="$LOGIN_STREAM_PID"
trap 'kill "$source_pid" 2>/dev/null || true; exit 0' INT TERM

while IFS= read -r line <&"${LOGIN_STREAM[0]}" && $running; do
  extract_login "$line"
done

kill "$source_pid" 2>/dev/null || true
wait "$source_pid" 2>/dev/null || true
