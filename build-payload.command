#!/bin/sh
# Compatibility entry point. Full Apple TTC payloads are intentionally forbidden.
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`

echo "Building in additive-only mode; the donor TTC will not enter payload."
exec "$ROOT/build-additions.command" "$@"
