#!/bin/sh
# Build only from a user-owned macOS installation or an official Apple installer.
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
PAYLOAD="$ROOT/payload"
FONT=""
SOURCE=""
usage() { echo "Usage: $0 --font /path/Apple\\ Color\\ Emoji.ttc | --macos-root /Volumes/macOS | --installer /path/Install\\ macOS*.app"; }
[ $# -ge 2 ] || { usage >&2; exit 64; }
case "$1" in
  --font) FONT=$2; SOURCE="user-supplied" ;;
  --macos-root) FONT="$2/System/Library/Fonts/Apple Color Emoji.ttc"; SOURCE="user-owned-macos-root" ;;
  --installer) FONT="$2/Contents/SharedSupport/SharedSupport.dmg"; SOURCE="official-apple-installer"; echo "Installer extraction is intentionally manual: mount the Apple installer image, then rerun with --font. No remote or third-party source is accepted." >&2; exit 78 ;;
  *) usage >&2; exit 64 ;;
esac
[ -f "$FONT" ] || { echo "No Apple Color Emoji.ttc at: $FONT" >&2; exit 66; }
case "$FONT" in *"Apple Color Emoji.ttc") ;; *) echo "Refusing non-canonical font filename." >&2; exit 65;; esac
mkdir -p "$PAYLOAD" "$ROOT/build"
sh "$ROOT/tools/emoji-table-audit.sh" "$FONT" | tee "$ROOT/build/table-audit.txt"
clang -framework Cocoa -framework CoreText "$ROOT/tools/ctprobe.m" -o "$ROOT/build/ctprobe"
if ! "$ROOT/build/ctprobe" "$FONT" > "$ROOT/build/coretext-probe.txt" 2>&1; then
  echo "STOP: this host CoreText cannot prove the donor is usable. Build payload on each target OS; do not install." >&2
  cat "$ROOT/build/coretext-probe.txt" >&2; exit 2
fi
cp "$FONT" "$PAYLOAD/Apple Color Emoji.ttc"
FONT_SHA=`shasum -a 256 "$PAYLOAD/Apple Color Emoji.ttc" | awk '{print $1}'`
FONT_BYTES=`wc -c < "$PAYLOAD/Apple Color Emoji.ttc" | tr -d ' '`
{ echo "format=emoji-legacy-patch-manifest-v1"; echo "payload_version=0.1.0"; echo "font_source=$SOURCE"; echo "font_sha256=$FONT_SHA"; echo "font_bytes=$FONT_BYTES"; echo "font_format=TTC (table audit in build/table-audit.txt)"; echo "target_os=10.8.5,10.9.5"; echo "target_arch=x86_64"; echo "created_utc=`date -u +%Y-%m-%dT%H:%M:%SZ`"; } > "$ROOT/manifest"
echo "Payload built. Font remains untracked by Git. Copy this complete project to each target and run verify.command before install."
