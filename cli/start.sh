#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.start [--help]

Resume the macOS VM from its paused state.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.start: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.start only runs on macOS." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
MACOS_VM_GUI=$(cat .vagrant/runtime.gui 2>/dev/null || printf false)
MACOS_VM_VOLUMES=$(cat .vagrant/runtime.volumes 2>/dev/null || true)
export MACOS_VM_GUI MACOS_VM_VOLUMES
vm_name=$(awk -F '"' '/tart\.name[[:space:]]*=/ { print $2; exit }' Vagrantfile)
vm_state=$(tart list 2>/dev/null | awk -v name="$vm_name" '$2 == name { print $NF; exit }' || true)
case "$vm_state" in
  suspended) exec vagrant resume ;;
  running) echo "macos.start: VM is already running." ;;
  stopped)
    echo "macos.start: VM is stopped without a saved paused state. Remove it with d2 macos.down, then create it with d2 macos.up." >&2
    exit 1
    ;;
  *) echo "macos.start: VM is not available (state: ${vm_state:-not_created})." >&2; exit 1 ;;
esac
