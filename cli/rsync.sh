#!/bin/bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: d2 macos.rsync [rsync-options...] <host-path> vm:<vm-path>
       d2 macos.rsync [rsync-options...] vm:<vm-path> <host-path>

Synchronise files between the host and the VM. Options are passed to rsync;
archive mode is enabled by default. A trailing slash on a directory source
keeps standard rsync behaviour.

Examples:
  d2 macos.rsync -av ./project/ vm:/Users/admin/project/
  d2 macos.rsync -av vm:/Users/admin/output/ ./output/
  d2 macos.rsync --delete -av ./project/ vm:/Users/admin/project/

The -e/--rsh option is reserved for the VM SSH connection.

Options:
  -h, --help  Show this help
HELP
}

if [ "$#" -eq 1 ] && { [ "$1" = -h ] || [ "$1" = --help ]; }; then
  usage
  exit 0
fi

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.rsync only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.rsync: SSH public key not found. Run d2 macos.setup first." >&2
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "macos.rsync: provide rsync options followed by a host path and vm:<path>." >&2
  usage >&2
  exit 2
fi

arguments=("$@")
argument_count=${#arguments[@]}
source_path=${arguments[$((argument_count - 2))]}
destination_path=${arguments[$((argument_count - 1))]}
rsync_options=("${arguments[@]:0:argument_count-2}")

for option in "${rsync_options[@]}"; do
  case "$option" in
    -e|--rsh|-e?*|--rsh=*)
      echo "macos.rsync: -e/--rsh is reserved for the VM SSH connection." >&2
      exit 2
      ;;
  esac
done

source_is_vm=false
destination_is_vm=false
case "$source_path" in
  vm:*) source_is_vm=true; source_path=${source_path#vm:} ;;
esac
case "$destination_path" in
  vm:*) destination_is_vm=true; destination_path=${destination_path#vm:} ;;
esac

if [ "$source_is_vm" = "$destination_is_vm" ]; then
  echo "macos.rsync: exactly one path must use the vm:<path> prefix." >&2
  usage >&2
  exit 2
fi
if [ -z "$source_path" ] || [ -z "$destination_path" ]; then
  echo "macos.rsync: host and VM paths must not be empty." >&2
  exit 2
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
        echo "macos.rsync: the VM is still starting or provisioning. Check d2 macos.ps first." >&2
        exit 1
        ;;
    esac
  fi
fi

state=$(vagrant status --machine-readable | awk -F, '$3 == "state" { print $4; exit }')
if [ "$state" != running ]; then
  echo "macos.rsync: the VM is not running. Run d2 macos.up first." >&2
  exit 1
fi

ssh_config=$(mktemp "${TMPDIR:-/tmp}/d2-macos-rsync.XXXXXX")
trap 'rm -f "$ssh_config"' EXIT HUP INT TERM
vagrant ssh-config > "$ssh_config"

if [ "$source_is_vm" = true ]; then
  source_path="default:$source_path"
fi
if [ "$destination_is_vm" = true ]; then
  destination_path="default:$destination_path"
fi

ssh_config_quoted=$(printf '%s' "$ssh_config" | sed "s/'/'\\\\''/g")
rsync_shell="ssh -F '$ssh_config_quoted'"
rsync -a "${rsync_options[@]}" -e "$rsync_shell" -- "$source_path" "$destination_path"
