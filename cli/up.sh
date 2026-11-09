#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.up [--help]

Start the macOS virtual machine with Vagrant and Tart.

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
exec vagrant up
