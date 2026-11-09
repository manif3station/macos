#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.exec <command> [arguments...]

Run a command in the macOS virtual machine through the Tart Guest Agent.

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

vm_name=$(awk -F '"' '/tart\.name[[:space:]]*=/ { print $2; exit }' Vagrantfile)
if [ -z "$vm_name" ]; then
  echo "macos.exec: could not determine the Tart VM name from Vagrantfile." >&2
  exit 1
fi
state=$(tart list 2>/dev/null | awk -v name="$vm_name" '$2 == name { print $NF; exit }' || true)
if [ "$state" != running ]; then
  echo "macos.exec: the VM is not running. Run d2 macos.up first." >&2
  exit 1
fi

guest_command="if [ -f ~/.zprofile ]; then source ~/.zprofile; fi; $*"
if [ -t 0 ]; then
  exec tart exec -i -t "$vm_name" /bin/bash -lc "$guest_command"
fi
exec tart exec -i "$vm_name" /bin/bash -lc "$guest_command"
