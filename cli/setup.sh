#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.setup [--help]

Prepare the VM SSH key, install the Tart provider, and pull the macOS image.

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

ssh_dir="$HOME/.ssh"
private_key="$ssh_dir/d2macOs"
public_key="$private_key.pub"
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"

if [ -f "$private_key" ] && [ -f "$public_key" ]; then
  echo "Using existing SSH key pair at $private_key."
elif [ -e "$private_key" ] || [ -e "$public_key" ]; then
  echo "macos.setup: only part of the SSH key pair exists at $private_key." >&2
  echo "Restore both files or remove the incomplete pair, then run d2 macos.setup again." >&2
  exit 1
else
  ssh-keygen -q -t ed25519 -N "" -C "d2-macos-vm" -f "$private_key"
  chmod 600 "$private_key"
  chmod 644 "$public_key"
  echo "Created SSH key pair at $private_key."
fi

vagrant plugin install vagrant-tart
exec tart pull ghcr.io/cirruslabs/macos-sequoia-base:latest
