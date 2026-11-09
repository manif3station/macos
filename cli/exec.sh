#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.exec <command> [arguments...]

Run a command in the macOS virtual machine over SSH.

Options:
  -h, --help  Show this help

The command and its arguments are passed to the guest shell. The VM must be
running; start it with d2 macos.up.
HELP
}

if [ "${1-}" = -h ] || [ "${1-}" = --help ]; then
  usage
  exit 0
fi

if [ "$#" -eq 0 ]; then
  echo "macos.exec: a command is required." >&2
  usage >&2
  exit 2
fi

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.exec only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.exec: SSH public key not found. Run d2 macos.setup first." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
pid_file=".vagrant/up.pid"
if [ -f "$pid_file" ]; then
  up_pid=$(cat "$pid_file")
  case "$up_pid" in
    ''|*[!0-9]*) up_pid="" ;;
  esac
  if [ -n "$up_pid" ] && kill -0 "$up_pid" 2>/dev/null; then
    up_command=$(ps -p "$up_pid" -o command= 2>/dev/null || true)
    case "$up_command" in
      *vagrant*up*)
        echo "macos.exec: the VM is still starting or provisioning. Check d2 macos.ps for progress." >&2
        exit 1
        ;;
    esac
  fi
fi

state=$(vagrant status --machine-readable | awk -F, '$3 == "state" { print $4; exit }')
if [ "$state" != running ]; then
  echo "macos.exec: the VM is not running. Run d2 macos.up first." >&2
  exit 1
fi

exec vagrant ssh -c "source ~/.zprofile; $*"
