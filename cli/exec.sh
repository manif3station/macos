#!/bin/sh
cd "$(dirname "$0")/.."
exec vagrant ssh dev -c "$@"
