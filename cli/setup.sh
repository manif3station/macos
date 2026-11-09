#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.setup [--help]

Install the Vagrant Tart provider plugin.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.setup: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.setup only runs on macOS." >&2
  exit 1
fi

exec vagrant plugin install vagrant-tart
