#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.cp <host-path> vm:<vm-path>
       d2 macos.cp vm:<vm-path> <host-path>

Copy a file or directory between the host and the VM. Directories are copied
recursively. Prefix the VM path with "vm:" to mark the guest side.

Examples:
  d2 macos.cp ./notes.txt vm:/Users/admin/notes.txt
  d2 macos.cp vm:/Users/admin/output.log ./output.log
  d2 macos.cp ./project vm:/Users/admin/

Options:
  -h, --help  Show this help
HELP
}

if [ "${1-}" = -h ] || [ "${1-}" = --help ]; then
  usage
  exit 0
fi

if [ "$#" -ne 2 ]; then
  echo "macos.cp: provide one host path and one vm:<path>." >&2
  usage >&2
  exit 2
fi

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.cp only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.cp: SSH public key not found. Run d2 macos.setup first." >&2
  exit 1
fi

source_path="$1"
destination_path="$2"
source_is_vm=false
destination_is_vm=false

case "$source_path" in
  vm:*) source_is_vm=true; source_path=${source_path#vm:} ;;
esac
case "$destination_path" in
  vm:*) destination_is_vm=true; destination_path=${destination_path#vm:} ;;
esac

if [ "$source_is_vm" = "$destination_is_vm" ]; then
  echo "macos.cp: exactly one path must use the vm:<path> prefix." >&2
  usage >&2
  exit 2
fi
if [ -z "$source_path" ] || [ -z "$destination_path" ]; then
  echo "macos.cp: host and VM paths must not be empty." >&2
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
        echo "macos.cp: the VM is still starting or provisioning. Check d2 macos.ps first." >&2
        exit 1
        ;;
    esac
  fi
fi

state=$(vagrant status --machine-readable | awk -F, '$3 == "state" { print $4; exit }')
if [ "$state" != running ]; then
  echo "macos.cp: the VM is not running. Run d2 macos.up first." >&2
  exit 1
fi

ssh_config=$(mktemp "${TMPDIR:-/tmp}/d2-macos-scp.XXXXXX")
trap 'rm -f "$ssh_config"' EXIT HUP INT TERM
vagrant ssh-config > "$ssh_config"

if [ "$source_is_vm" = true ]; then
  source_path="default:$source_path"
else
  case "$source_path" in -*) source_path="./$source_path" ;; esac
fi
if [ "$destination_is_vm" = true ]; then
  destination_path="default:$destination_path"
else
  case "$destination_path" in -*) destination_path="./$destination_path" ;; esac
fi

scp -r -F "$ssh_config" -- "$source_path" "$destination_path"
