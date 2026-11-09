#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.down [--help]

Stop the macOS virtual machine and keep it available for the next start.

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

cd "$(dirname "$0")/.."
exec vagrant halt
