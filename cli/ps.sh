#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.ps [--help]

Show VM state, startup elapsed time, a previous-startup estimate, latest log
activity, and guest processes.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.ps: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.ps only runs on macOS." >&2
  exit 1
fi

if [ -z "${MACOS_VM_SSH_KEY:-}" ] && [ ! -f "$HOME/.ssh/d2macOs.pub" ]; then
  echo "macos.ps: SSH public key not found. Run d2 macos.setup first." >&2
  exit 1
fi

cd "$(dirname "$0")/.."

pid_file=".vagrant/up.pid"
log_file=".vagrant/up.log"
started_file=".vagrant/up.started"
duration_file=".vagrant/up.duration"
exit_file=".vagrant/up.exit"
last_success_duration_file=".vagrant/up.last-success.duration"
vm_name=$(awk -F '"' '/tart\.name[[:space:]]*=/ { print $2; exit }' Vagrantfile)
if [ -z "$vm_name" ]; then
  vm_name="default"
fi

guest_exec() {
  tart exec "$vm_name" /bin/bash -lc "$1"
}

format_duration() {
  duration_value="$1"
  if [ "$duration_value" -ge 86400 ]; then
    printf '%sd %sh %sm' "$((duration_value / 86400))" "$(((duration_value % 86400) / 3600))" "$(((duration_value % 3600) / 60))"
  elif [ "$duration_value" -ge 3600 ]; then
    printf '%sh %sm %ss' "$((duration_value / 3600))" "$(((duration_value % 3600) / 60))" "$((duration_value % 60))"
  elif [ "$duration_value" -ge 60 ]; then
    printf '%sm %ss' "$((duration_value / 60))" "$((duration_value % 60))"
  else
    printf '%ss' "$duration_value"
  fi
}

last_success_duration=""
if [ -f "$last_success_duration_file" ]; then
  candidate_duration=$(cat "$last_success_duration_file")
  case "$candidate_duration" in
    ''|*[!0-9]*) ;;
    *) last_success_duration="$candidate_duration" ;;
  esac
fi

startup_started_at=""
if [ -f "$started_file" ]; then
  candidate_started_at=$(cat "$started_file")
  case "$candidate_started_at" in
    ''|*[!0-9]*) ;;
    *) startup_started_at="$candidate_started_at" ;;
  esac
fi
if [ -z "$startup_started_at" ] && [ -f ".vagrant/up.timestamps.log" ]; then
  first_log_timestamp=$(head -n 1 .vagrant/up.timestamps.log | awk '{ print $1 }')
  startup_started_at=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$first_log_timestamp" +%s 2>/dev/null || true)
fi
now=$(date +%s)
startup_elapsed_seconds=""
if [ -n "$startup_started_at" ]; then
  startup_elapsed_seconds=$((now - startup_started_at))
fi

show_last_startup_duration() {
  if [ ! -f "$duration_file" ]; then
    return
  fi
  duration_value=$(cat "$duration_file")
  exit_value=$(cat "$exit_file" 2>/dev/null || true)
  case "$duration_value" in
    ''|*[!0-9]*) return ;;
  esac
  case "$exit_value" in
    0) echo "Last startup completed in $(format_duration "$duration_value")." ;;
    ''|*[!0-9]*) ;;
    *) echo "Last startup failed after $(format_duration "$duration_value") (exit code $exit_value)." ;;
  esac
}

up_pid=""
startup_active=false
if [ -f "$pid_file" ]; then
  up_pid=$(cat "$pid_file")
  case "$up_pid" in
    ''|*[!0-9]*) up_pid="" ;;
  esac
  if [ -n "$up_pid" ] && kill -0 "$up_pid" 2>/dev/null; then
    up_command=$(ps -p "$up_pid" -o command= 2>/dev/null || true)
    case "$up_command" in
      *vagrant*up*) startup_active=true ;;
      *) up_pid="" ;;
    esac
  else
    up_pid=""
  fi
fi

tart_state=$(tart list 2>/dev/null | awk -v name="$vm_name" '$2 == name { print $NF; exit }' || true)
vm_pid=$(pgrep -f "[t]art run $vm_name" | head -n 1 || true)
vm_ip=$(tart ip "$vm_name" 2>/dev/null || true)
vagrant_state=""
if [ "$startup_active" = false ]; then
  vagrant_state=$(vagrant status --machine-readable 2>/dev/null | awk -F, '$3 == "state" { print $4; exit }' || true)
fi

last_line=""
log_age=""
if [ -f "$log_file" ]; then
  last_line=$(tail -n 1 "$log_file" | sed 's/^[[:space:]]*default: //; s/^[[:space:]]*//')
  last_line=$(printf '%s' "$last_line" | cut -c 1-220)
  log_mtime=$(stat -f %m "$log_file" 2>/dev/null || echo 0)
  if [ "$log_mtime" -gt 0 ]; then
    age=$((now - log_mtime))
    if [ "$age" -lt 60 ]; then
      log_age="${age}s ago"
    elif [ "$age" -lt 3600 ]; then
      log_age="$((age / 60))m $((age % 60))s ago"
    else
      log_age="$((age / 3600))h $(((age % 3600) / 60))m ago"
    fi
  fi
fi

if [ "$startup_active" = true ]; then
  elapsed=$(ps -p "$up_pid" -o etime= | sed 's/^[[:space:]]*//')
  echo "VM: $vm_name"
  echo "Startup: in progress (PID $up_pid)"
  if [ -n "$startup_elapsed_seconds" ]; then
    echo "Startup elapsed: $(format_duration "$startup_elapsed_seconds")"
  else
    echo "Startup elapsed: $elapsed"
  fi
  if [ -n "$last_success_duration" ] && [ -n "$startup_elapsed_seconds" ]; then
    echo "Previous successful startup took $(format_duration "$last_success_duration")."
    if [ "$startup_elapsed_seconds" -lt "$last_success_duration" ]; then
      estimate_remaining=$((last_success_duration - startup_elapsed_seconds))
      echo "Estimated remaining: about $(format_duration "$estimate_remaining"), based on that startup. Actual time can vary."
    else
      estimate_overrun=$((startup_elapsed_seconds - last_success_duration))
      echo "Current startup has exceeded that time by $(format_duration "$estimate_overrun"); no reliable remaining-time estimate is available."
    fi
  elif [ -z "$last_success_duration" ]; then
    echo "No previous successful startup duration is recorded yet."
  fi
  case "$last_line" in
    *"Waiting for machine to boot"*)
      echo "Waiting for: macOS to boot and accept SSH connections."
      ;;
    *"SSH address:"*)
      echo "Waiting for: SSH connection or authentication to succeed."
      ;;
    *"Running provisioner:"*)
      echo "Waiting for: VM provisioning."
      ;;
    *"Downloading"*|*"In progress"*|*"Fetching"*)
      echo "Waiting for: a download or package installation to finish."
      ;;
    *)
      echo "Current step: see the latest startup log line below."
      ;;
  esac
  [ -n "$vm_pid" ] && echo "Tart process: $vm_pid" || true
  [ -n "$vm_ip" ] && echo "VM IP: $vm_ip" || true
  [ -n "$log_age" ] && echo "Last log output: $log_age" || true
  [ -n "$last_line" ] && echo "Last log line: $last_line" || true
  echo "Follow progress: d2 macos.logs -t -f --tail=20"
  exit 0
fi

if [ -n "$vm_pid" ] || [ "$tart_state" = running ]; then
  echo "VM: $vm_name"
  echo "VM status: running in Tart"
  if [ -n "$vm_pid" ]; then
    started=$(ps -p "$vm_pid" -o lstart= | sed 's/^[[:space:]]*//')
    elapsed=$(ps -p "$vm_pid" -o etime= | sed 's/^[[:space:]]*//')
    echo "VM process PID: $vm_pid"
    echo "Started: $started"
    echo "Running for: $elapsed"
  else
    echo "VM process PID: unavailable"
  fi
  [ -n "$vm_ip" ] && echo "VM IP: $vm_ip" || true
  show_last_startup_duration

  if [ "$vagrant_state" = running ]; then
    echo "Vagrant state: running"
    mac_version=$(guest_exec 'sw_vers -productVersion' 2>/dev/null || true)
    if [ -n "$mac_version" ]; then
      echo "macOS version: $mac_version"
    else
      echo "macOS version: SSH command failed"
    fi
    echo
    echo "Top guest processes by CPU:"
    guest_exec 'ps -A -o %cpu,%mem,pid,command | tail -n +2 | sort -nr -k1,1 | head -n 10' || true
    echo
    echo "Top guest processes by memory:"
    guest_exec 'ps -A -o %cpu,%mem,pid,command | tail -n +2 | sort -nr -k2,2 | head -n 10' || true
  else
    if [ -n "$vm_ip" ] && nc -G 2 -z "$vm_ip" 22 >/dev/null 2>&1; then
      echo "SSH port: reachable, but the VM manager has not completed its boot check."
      echo "Last reported Vagrant state: ${vagrant_state:-unknown}"
      echo "Inspect the startup log for an SSH authentication or boot timeout error."
    else
      echo "SSH port: not reachable yet; macOS may still be booting."
      echo "Last reported Vagrant state: ${vagrant_state:-unknown}"
    fi
    if grep -q 'Timed out while waiting for the machine to boot' "$log_file" 2>/dev/null; then
      echo "Startup result: timed out waiting for the guest to become ready."
    fi
    [ -n "$log_age" ] && echo "Last log output: $log_age" || true
    [ -n "$last_line" ] && echo "Last log line: $last_line" || true
    echo "Logs: d2 macos.logs -t --tail=30"
  fi
  exit 0
fi

echo "VM: $vm_name"
echo "VM status: ${vagrant_state:-${tart_state:-not_created}}"
if [ "$tart_state" = suspended ]; then
  echo "VM is paused. Resume it with d2 macos.start, or destroy it with d2 macos.down."
elif [ "$tart_state" = stopped ]; then
  echo "VM is stopped. Destroy it with d2 macos.down before creating a new VM with d2 macos.up."
fi
if [ -f "$log_file" ]; then
  show_last_startup_duration
  if grep -q 'Timed out while waiting for the machine to boot' "$log_file"; then
    echo "Startup result: timed out waiting for the guest to become ready."
  fi
  [ -n "$log_age" ] && echo "Last log output: $log_age" || true
  [ -n "$last_line" ] && echo "Last log line: $last_line" || true
  echo "Logs: d2 macos.logs -t --tail=30"
fi
echo "Start it with d2 macos.up."
