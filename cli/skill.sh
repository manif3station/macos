#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.skill [--help]

Print the VM control instructions for agents from SKILLS.md.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.skill: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

cd "$(dirname "$0")/.."
if [ ! -f SKILLS.md ]; then
  echo "macos.skill: SKILLS.md was not found in the skill directory." >&2
  exit 1
fi

exec cat SKILLS.md
