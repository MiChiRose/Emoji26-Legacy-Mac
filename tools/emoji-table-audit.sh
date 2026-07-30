#!/bin/sh
# POSIX /bin/sh launcher; compiler/runtime are supplied by Xcode, not Homebrew.
set -eu
[ $# -eq 1 ] || { echo "usage: $0 FONT" >&2; exit 64; }
font=$1
[ -f "$font" ] || { echo "font not found: $font" >&2; exit 66; }
ROOT=`CDPATH= cd -- "$(dirname -- "$0")/.." && pwd`
mkdir -p "$ROOT/build"
if [ -x "$ROOT/prebuilt/host/sfnt-audit" ]; then
  cp "$ROOT/prebuilt/host/sfnt-audit" "$ROOT/build/sfnt-audit"
else
  cc "$ROOT/tools/sfnt-audit.c" -o "$ROOT/build/sfnt-audit"
fi
"$ROOT/build/sfnt-audit" "$font"
