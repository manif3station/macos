#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.up [--help]

Start the macOS virtual machine and provision it in the background.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.up: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.up only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.up: SSH public key not found. Run d2 macos.setup first." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
mkdir -p .vagrant
pid_file=".vagrant/up.pid"
log_file=".vagrant/up.log"
timestamp_log_file=".vagrant/up.timestamps.log"

if [ -f "$pid_file" ]; then
  up_pid=$(cat "$pid_file")
  case "$up_pid" in
    ''|*[!0-9]*) up_pid="" ;;
  esac
  if [ -n "$up_pid" ] && kill -0 "$up_pid" 2>/dev/null; then
    up_command=$(ps -p "$up_pid" -o command= 2>/dev/null || true)
    case "$up_command" in
      *vagrant*up*)
        echo "macos.up: startup is already running in the background (PID $up_pid)."
        echo "Log: $log_file"
        exit 0
        ;;
    esac
  fi
  : > "$pid_file"
fi

: > "$log_file"
: > "$timestamp_log_file"
nohup /bin/bash -c '
  set -o pipefail
  vagrant up --provision 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
    printf "%s\n" "$line" >> "$1"
    printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$line" >> "$2"
  done
' d2-macos-up "$log_file" "$timestamp_log_file" > /dev/null 2>&1 < /dev/null &
up_pid=$!
printf '%s\n' "$up_pid" > "$pid_file"
echo "macos.up: starting the macOS VM in the background (PID $up_pid)."
echo "Log: $log_file"
echo "Run d2 macos.ps to check progress and VM status."
