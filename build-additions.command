#!/bin/sh
# Computes an additive-only set. It never replaces or installs a system font.
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
DONOR=""
LEGACY=""

usage() {
  echo "Usage: $0 --font /path/macOS26/Apple\\ Color\\ Emoji.ttc --legacy-font /path/legacy/Apple\\ Color\\ Emoji.ttf"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --font) [ $# -ge 2 ] || { usage >&2; exit 64; }; DONOR=$2; shift 2 ;;
    --legacy-font) [ $# -ge 2 ] || { usage >&2; exit 64; }; LEGACY=$2; shift 2 ;;
    *) usage >&2; exit 64 ;;
  esac
done

[ -f "$DONOR" ] || { echo "Donor font not found: $DONOR" >&2; exit 66; }
[ -f "$LEGACY" ] || { echo "Legacy font not found: $LEGACY" >&2; exit 66; }

mkdir -p "$ROOT/build" "$ROOT/payload"
cc "$ROOT/tools/cmap-diff.c" -o "$ROOT/build/cmap-diff"
"$ROOT/build/cmap-diff" "$DONOR" "$LEGACY" > "$ROOT/payload/emoji26-additions.txt"

DONOR_SHA=`shasum -a 256 "$DONOR" | awk '{print $1}'`
LEGACY_SHA=`shasum -a 256 "$LEGACY" | awk '{print $1}'`
COUNT=`wc -l < "$ROOT/payload/emoji26-additions.txt" | tr -d ' '`

{
  echo "format=emoji26-additions-manifest-v1"
  echo "payload_version=0.2.0"
  echo "mode=additive-only"
  echo "donor_sha256=$DONOR_SHA"
  echo "legacy_sha256=$LEGACY_SHA"
  echo "single_codepoint_additions=$COUNT"
  echo "additions_font_sha256=UNBUILT"
  echo "additions_font_bytes=0"
  echo "system_font_replacement=false"
  echo "zwj_support=picker-only-until-legacy-renderer-is-proven"
  echo "target_os=10.8.5,10.9.5"
  echo "target_arch=x86_64"
  echo "created_utc=`date -u +%Y-%m-%dT%H:%M:%SZ`"
} > "$ROOT/manifest"

echo "Computed $COUNT donor code points absent from the legacy cmap."
echo "No font was installed or modified. This list is input for the additive font/picker builder."
