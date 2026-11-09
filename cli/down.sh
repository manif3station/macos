#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.down [--help]

Destroy the macOS virtual machine and remove its local VM state.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.down: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.down only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.down: SSH public key not found. Run d2 macos.setup first." >&2
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
        echo "macos.down: the VM is still starting or provisioning. Check d2 macos.ps for progress." >&2
        exit 1
        ;;
    esac
  fi
fi

vagrant_state=$(vagrant status --machine-readable 2>/dev/null | awk -F, '$3 == "state" { print $4; exit }' || true)
if [ "$vagrant_state" = not_created ]; then
  vm_name=$(awk -F '"' '/tart\.name[[:space:]]*=/ { print $2; exit }' Vagrantfile)
  tart_state=$(tart list 2>/dev/null | awk -v name="$vm_name" '$2 == name { print $NF; exit }' || true)
  case "$tart_state" in
    running)
      echo "macos.down: stopping the untracked Tart VM before removing it."
      tart stop "$vm_name"
      ;;
    stopped|suspended) ;;
    *)
      echo "macos.down: no VM is registered with Vagrant or present in Tart."
      exit 0
      ;;
  esac
  echo "macos.down: removing the untracked Tart VM '$vm_name'."
  exec tart delete "$vm_name"
fi

exec vagrant destroy -f
