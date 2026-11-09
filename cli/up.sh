#!/bin/sh
set -eu

for vagrant_dir in /usr/local/bin /opt/vagrant/bin; do
  if [ -x "$vagrant_dir/vagrant" ]; then
    PATH="$vagrant_dir:$PATH"
  fi
done
export PATH

usage() {
  cat <<'HELP'
Usage: d2 macos.up [--gui|--no-gui] [-v HOST_PATH:NAME]... [--help]

Create and provision the macOS virtual machine in the background. Headless mode
is the default; --gui opens a VM window.

Options:
  --gui              Open the VM window
  --no-gui           Run without opening a VM window (default)
  -v HOST_PATH:NAME  Mount a host directory at /Volumes/My Shared Files/NAME
  -h, --help         Show this help
HELP
}

gui=false
gui_seen=false
volumes=""
volume_names="|"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --gui)
      if [ "$gui_seen" = true ] && [ "$gui" != true ]; then
        echo "macos.up: --gui and --no-gui cannot be used together." >&2
        exit 2
      fi
      gui=true; gui_seen=true; shift ;;
    --no-gui)
      if [ "$gui_seen" = true ] && [ "$gui" != false ]; then
        echo "macos.up: --gui and --no-gui cannot be used together." >&2
        exit 2
      fi
      gui=false; gui_seen=true; shift ;;
    -v|--volume)
      if [ "$#" -lt 2 ]; then
        echo "macos.up: $1 requires HOST_PATH:NAME." >&2; usage >&2; exit 2
      fi
      volume_spec=$2
      shift 2
      case "$volume_spec" in
        *:*) host_path=${volume_spec%:*}; volume_name=${volume_spec##*:} ;;
        *) echo "macos.up: volume must be HOST_PATH:NAME." >&2; exit 2 ;;
      esac
      if [ -z "$host_path" ] || [ -z "$volume_name" ] || [ ! -d "$host_path" ]; then
        echo "macos.up: volume host path must be an existing directory and NAME must not be empty: $volume_spec" >&2
        exit 2
      fi
      case "$volume_name" in
        *[!A-Za-z0-9._-]*) echo "macos.up: volume name may contain only letters, numbers, dot, underscore, and hyphen." >&2; exit 2 ;;
      esac
      host_path=$(cd "$host_path" && pwd -P)
      case "$volume_names" in
        *"|$volume_name|"*) echo "macos.up: volume name '$volume_name' is already in use." >&2; exit 2 ;;
      esac
      volume_names="${volume_names}${volume_name}|"
      volume_entry="${volume_name}:${host_path}"
      if [ -n "$volumes" ]; then
        volumes=$(printf '%s\n%s' "$volumes" "$volume_entry")
      else
        volumes=$volume_entry
      fi
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "macos.up: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.up only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.up: SSH public key not found. Run d2 macos.setup first." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
mkdir -p .vagrant
vm_name=$(awk -F '"' '/tart\.name[[:space:]]*=/ { print $2; exit }' Vagrantfile)
existing_state=$(tart list 2>/dev/null | awk -v name="$vm_name" '$2 == name { print $NF; exit }' || true)
case "$existing_state" in
  suspended|stopped)
    echo "macos.up: VM already exists in the $existing_state state; it will not be started or recreated." >&2
    if [ "$existing_state" = suspended ]; then
      echo "Resume it with d2 macos.start, or remove it with d2 macos.down." >&2
    else
      echo "Remove it with d2 macos.down before creating it again." >&2
    fi
    exit 1
    ;;
esac
pid_file=".vagrant/up.pid"
log_file=".vagrant/up.log"
timestamp_log_file=".vagrant/up.timestamps.log"
started_file=".vagrant/up.started"
duration_file=".vagrant/up.duration"
exit_file=".vagrant/up.exit"
last_success_duration_file=".vagrant/up.last-success.duration"
if [ -f "$pid_file" ]; then
  up_pid=$(cat "$pid_file")
  case "$up_pid" in
    ''|*[!0-9]*) up_pid="" ;;
  esac
  if [ -n "$up_pid" ] && kill -0 "$up_pid" 2>/dev/null; then
    up_command=$(ps -p "$up_pid" -o command= 2>/dev/null || true)
    case "$up_command" in
      *vagrant*up*)
        echo "macos.up: startup is already running in the background (PID $up_pid)."
        echo "Log: $log_file"
        exit 0
        ;;
    esac
  fi
  : > "$pid_file"
fi

printf '%s\n' "$gui" > ".vagrant/runtime.gui"
printf '%s' "$volumes" > ".vagrant/runtime.volumes"
: > "$log_file"
: > "$timestamp_log_file"
started_at=$(date +%s)
printf '%s\n' "$started_at" > "$started_file"
: > "$duration_file"
: > "$exit_file"
nohup /bin/bash -c '
  set -o pipefail
  log_file="$1"
  timestamp_log_file="$2"
  started_at="$3"
  duration_file="$4"
  exit_file="$5"
  last_success_duration_file="$6"
  vm_name="$9"
  export MACOS_VM_GUI="$7"
  export MACOS_VM_VOLUMES="$8"

  vagrant up --provision 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
    printf "%s\n" "$line" >> "$log_file"
    printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$line" >> "$timestamp_log_file"
  done
  vagrant_exit=${PIPESTATUS[0]}
  provisioned_via_agent=false
  if [ "$vagrant_exit" -ne 0 ]; then
    original_vagrant_exit="$vagrant_exit"
    message="Vagrant startup failed with exit code $original_vagrant_exit; waiting for Tart Guest Agent to provision the running VM."
    printf "%s\n" "$message" >> "$log_file"
    printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$message" >> "$timestamp_log_file"

    agent_ready=false
    for attempt in {1..36}; do
      if tart exec "$vm_name" /usr/bin/true >/dev/null 2>&1; then
        agent_ready=true
        break
      fi
      if [ "$((attempt % 6))" -eq 0 ]; then
        message="Waiting for Tart Guest Agent (attempt $attempt of 36)."
        printf "%s\n" "$message" >> "$log_file"
        printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$message" >> "$timestamp_log_file"
      fi
      sleep 5
    done

    if [ "$agent_ready" = true ] && [ -f ".vagrant/provision_guest.sh" ]; then
      message="Running guest provisioning through Tart Guest Agent."
      printf "%s\n" "$message" >> "$log_file"
      printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$message" >> "$timestamp_log_file"
      tart exec -i "$vm_name" /bin/bash -s < ".vagrant/provision_guest.sh" 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
        printf "%s\n" "$line" >> "$log_file"
        printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$line" >> "$timestamp_log_file"
      done
      provision_exit=${PIPESTATUS[0]}
      if [ "$provision_exit" -eq 0 ]; then
        vagrant_exit=0
        provisioned_via_agent=true
      else
        message="Tart Guest Agent provisioning failed with exit code $provision_exit."
        printf "%s\n" "$message" >> "$log_file"
        printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$message" >> "$timestamp_log_file"
      fi
    else
      message="Tart Guest Agent or the generated provisioning script is unavailable; cannot provision the VM."
      printf "%s\n" "$message" >> "$log_file"
      printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$message" >> "$timestamp_log_file"
    fi
  fi
  finished_at=$(date +%s)
  duration=$((finished_at - started_at))
  printf "%s\n" "$duration" > "$duration_file"
  printf "%s\n" "$vagrant_exit" > "$exit_file"
  if [ "$vagrant_exit" -eq 0 ]; then
    printf "%s\n" "$duration" > "$last_success_duration_file"
    if [ "$provisioned_via_agent" = true ]; then
      summary="Startup and provisioning completed through Tart Guest Agent in ${duration}s after Vagrant SSH failed."
    else
      summary="Startup completed successfully in ${duration}s."
    fi
  else
    summary="Startup failed with exit code $vagrant_exit after ${duration}s."
  fi
  printf "%s\n" "$summary" >> "$log_file"
  printf "%s %s\n" "$(date -u "+%Y-%m-%dT%H:%M:%SZ")" "$summary" >> "$timestamp_log_file"
  exit "$vagrant_exit"
' d2-macos-up "$log_file" "$timestamp_log_file" "$started_at" "$duration_file" "$exit_file" "$last_success_duration_file" "$gui" "$volumes" "$vm_name" > /dev/null 2>&1 < /dev/null &
up_pid=$!
printf '%s\n' "$up_pid" > "$pid_file"
echo "macos.up: starting the macOS VM in the background (PID $up_pid, GUI: $gui)."
echo "Log: $log_file"
echo "Run d2 macos.ps to check progress and VM status."
