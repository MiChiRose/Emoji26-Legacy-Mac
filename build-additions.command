#!/bin/sh
# Computes an additive-only set. It never replaces or installs a system font.
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
DONOR=""
LEGACY=""
TARGET_OS=""

usage() {
  echo "Usage: $0 --font DONOR.ttc --legacy-font LEGACY.ttf --target-os VERSION"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --font) [ $# -ge 2 ] || { usage >&2; exit 64; }; DONOR=$2; shift 2 ;;
    --legacy-font) [ $# -ge 2 ] || { usage >&2; exit 64; }; LEGACY=$2; shift 2 ;;
    --target-os) [ $# -ge 2 ] || { usage >&2; exit 64; }; TARGET_OS=$2; shift 2 ;;
    *) usage >&2; exit 64 ;;
  esac
done

[ -f "$DONOR" ] || { echo "Donor font not found: $DONOR" >&2; exit 66; }
[ -f "$LEGACY" ] || { echo "Legacy font not found: $LEGACY" >&2; exit 66; }
case "$TARGET_OS" in
  10.8.5|10.9.5|10.10.5|10.11.6|10.12.6|10.13.6) ;;
  *) echo "Unsupported target OS: $TARGET_OS" >&2; exit 65 ;;
esac

mkdir -p "$ROOT/build" "$ROOT/payload"
cc "$ROOT/tools/cmap-diff.c" -o "$ROOT/build/cmap-diff"
"$ROOT/build/cmap-diff" "$DONOR" "$LEGACY" > "$ROOT/build/raw-cmap-additions.txt"
cc "$ROOT/tools/font-additions-builder.c" -o "$ROOT/build/font-additions-builder"
"$ROOT/build/font-additions-builder" \
  "$DONOR" \
  "$ROOT/build/raw-cmap-additions.txt" \
  "$ROOT/payload/Emoji26 Additions.ttf" \
  "$ROOT/payload/emoji26-additions.txt"
sh "$ROOT/tools/emoji-table-audit.sh" "$ROOT/payload/Emoji26 Additions.ttf" |
  tee "$ROOT/build/additions-table-audit.txt"
clang -framework Cocoa -framework CoreText \
  "$ROOT/tools/ctprobe.m" -o "$ROOT/build/ctprobe"
"$ROOT/build/ctprobe" \
  "$ROOT/payload/Emoji26 Additions.ttf" \
  "Emoji26 Additions" \
  --additive |
  tee "$ROOT/build/additions-coretext-probe.txt"

DONOR_SHA=`shasum -a 256 "$DONOR" | awk '{print $1}'`
LEGACY_SHA=`shasum -a 256 "$LEGACY" | awk '{print $1}'`
COUNT=`wc -l < "$ROOT/payload/emoji26-additions.txt" | tr -d ' '`
FONT_SHA=`shasum -a 256 "$ROOT/payload/Emoji26 Additions.ttf" | awk '{print $1}'`
FONT_BYTES=`wc -c < "$ROOT/payload/Emoji26 Additions.ttf" | tr -d ' '`

{
  echo "format=emoji26-additions-manifest-v1"
  echo "payload_version=0.2.0"
  echo "mode=additive-only"
  echo "donor_sha256=$DONOR_SHA"
  echo "legacy_sha256=$LEGACY_SHA"
  echo "single_codepoint_additions=$COUNT"
  echo "additions_font_sha256=$FONT_SHA"
  echo "additions_font_bytes=$FONT_BYTES"
  echo "system_font_replacement=false"
  echo "zwj_support=picker-only-until-legacy-renderer-is-proven"
  echo "target_os=$TARGET_OS"
  echo "target_arch=x86_64"
  echo "created_utc=`date -u +%Y-%m-%dT%H:%M:%SZ`"
} > "$ROOT/manifest"

echo "Built a supplemental font with $COUNT safe mapped additions."
echo "No font was installed and no system file was modified."
