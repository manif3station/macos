#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.logs [-t] [-f] [--tail N|--tail=N]

Show the VM startup log. By default, print the log and exit.

Options:
  -t, --timestamps  Show UTC timestamps recorded for each log line
  -f, --follow      Continue following new log lines
      --tail N       Show only the last N lines; use "all" for every line
  -h, --help        Show this help
HELP
}

follow=false
timestamps=false
tail_set=false
tail_count=all

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -f|--follow)
      follow=true
      ;;
    -t|--timestamps)
      timestamps=true
      ;;
    --tail)
      shift
      if [ "$#" -eq 0 ]; then
        echo "macos.logs: --tail requires a line count or 'all'." >&2
        usage >&2
        exit 2
      fi
      tail_count="$1"
      tail_set=true
      ;;
    --tail=*)
      tail_count=${1#--tail=}
      tail_set=true
      ;;
    *)
      echo "macos.logs: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.logs only runs on macOS." >&2
  exit 1
fi

if [ "$tail_set" = true ] && [ "$tail_count" != all ]; then
  case "$tail_count" in
    ''|*[!0-9]*)
      echo "macos.logs: --tail must be a non-negative line count or 'all'." >&2
      exit 2
      ;;
  esac
fi

cd "$(dirname "$0")/.."
if [ "$timestamps" = true ]; then
  log_file=".vagrant/up.timestamps.log"
else
  log_file=".vagrant/up.log"
fi

if [ ! -f "$log_file" ]; then
  echo "macos.logs: no startup log found at $log_file. Run d2 macos.up first." >&2
  exit 1
fi

if [ "$follow" = true ]; then
  if [ "$tail_set" = true ] && [ "$tail_count" != all ]; then
    exec tail -n "$tail_count" -f "$log_file"
  fi
  exec tail -n +1 -f "$log_file"
fi

if [ "$tail_set" = true ] && [ "$tail_count" != all ]; then
  exec tail -n "$tail_count" "$log_file"
fi

exec cat "$log_file"
