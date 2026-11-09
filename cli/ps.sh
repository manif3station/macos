#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.ps [--help]

Show VM startup or running status, the macOS version, process start time,
elapsed time, and the guest's highest CPU and memory processes.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.ps: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.ps only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.ps: SSH public key not found. Run d2 macos.setup first." >&2
  exit 1
fi

cd "$(dirname "$0")/.."

pid_file=".vagrant/up.pid"
log_file=".vagrant/up.log"
if [ -f "$pid_file" ]; then
  up_pid=$(cat "$pid_file")
  case "$up_pid" in
    ''|*[!0-9]*) up_pid="" ;;
  esac
  if [ -n "$up_pid" ] && kill -0 "$up_pid" 2>/dev/null; then
    up_command=$(ps -p "$up_pid" -o command= 2>/dev/null || true)
    case "$up_command" in
      *vagrant*up*)
        echo "VM status: starting or provisioning"
        echo "Setup process PID: $up_pid"
        echo "Log: $log_file"
        exit 0
        ;;
    esac
  fi
fi

state=$(vagrant status --machine-readable 2>/dev/null | awk -F, '$3 == "state" { print $4; exit }')
if [ "$state" != running ]; then
  echo "VM status: ${state:-unknown}"
  if [ -f "$log_file" ]; then
    echo "Startup log: $log_file"
  fi
  echo "Start it with d2 macos.up."
  exit 0
fi

vm_name="my-custom-mac-vm"
vm_pid=$(pgrep -f "[t]art run $vm_name" | head -n 1 || true)
echo "VM status: running"
if [ -n "$vm_pid" ]; then
  started=$(ps -p "$vm_pid" -o lstart= | sed 's/^[[:space:]]*//')
  elapsed=$(ps -p "$vm_pid" -o etime= | sed 's/^[[:space:]]*//')
  echo "VM process PID: $vm_pid"
  echo "Started: $started"
  echo "Running for: $elapsed"
else
  echo "VM process PID: unavailable"
fi

mac_version=$(d2 macos.exec sw_vers -productVersion 2>/dev/null || true)
if [ -n "$mac_version" ]; then
  echo "macOS version: $mac_version"
else
  echo "macOS version: unavailable over SSH"
fi

echo
echo "Top guest processes by CPU:"
d2 macos.exec 'ps -A -o %cpu,%mem,pid,command | tail -n +2 | sort -nr -k1,1 | head -n 10'

echo
echo "Top guest processes by memory:"
d2 macos.exec 'ps -A -o %cpu,%mem,pid,command | tail -n +2 | sort -nr -k2,2 | head -n 10'
