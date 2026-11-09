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

cd "$(dirname "$0")/.."
exec vagrant ssh -c "$*"
