#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.stop [--help]

Pause the running macOS VM and preserve its current state.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.stop: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.stop only runs on macOS." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
pid_file=".vagrant/up.pid"
if [ -f "$pid_file" ]; then
  up_pid=$(cat "$pid_file")
  case "$up_pid" in ''|*[!0-9]*) up_pid="" ;; esac
  if [ -n "$up_pid" ] && kill -0 "$up_pid" 2>/dev/null; then
    up_command=$(ps -p "$up_pid" -o command= 2>/dev/null || true)
    case "$up_command" in
      *vagrant*up*)
        echo "macos.stop: VM startup is still in progress. Check d2 macos.ps first." >&2
        exit 1
        ;;
    esac
  fi
fi

vm_name=$(awk -F '"' '/tart\.name[[:space:]]*=/ { print $2; exit }' Vagrantfile)
vm_state=$(tart list 2>/dev/null | awk -v name="$vm_name" '$2 == name { print $NF; exit }' || true)
case "$vm_state" in
  running) exec vagrant suspend ;;
  suspended) echo "macos.stop: VM is already paused." ;;
  stopped) echo "macos.stop: VM is stopped and has no saved paused state." >&2; exit 1 ;;
  *) echo "macos.stop: VM is not available (state: ${vm_state:-not_created})." >&2; exit 1 ;;
esac
