#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`; FONT=/Library/Fonts/Emoji26\ Additions.ttf
[ "`uname -m`" = x86_64 ] || { echo "FAIL: not x86_64"; exit 1; }
[ -f "$ROOT/manifest" ] || { echo "FAIL: manifest absent"; exit 1; }
TARGET_OS=`awk -F= '$1=="target_os" {print $2}' "$ROOT/manifest"`
CURRENT_OS=`sw_vers -productVersion`
case "$TARGET_OS" in
  10.8.5|10.9.5|10.10.5|10.11.6|10.12.6|10.13.6) ;;
  *) echo "FAIL: unsupported target in manifest"; exit 1 ;;
esac
[ "$CURRENT_OS" = "$TARGET_OS" ] || {
  echo "FAIL: package targets $TARGET_OS, current OS is $CURRENT_OS"
  exit 1
}
[ -f "$FONT" ] || { echo "FAIL: font absent"; exit 1; }
if [ -x "$ROOT/bin/ctprobe" ]; then
  PROBE="$ROOT/bin/ctprobe"
else
  mkdir -p "$ROOT/build"
  clang -framework Cocoa -framework CoreText "$ROOT/tools/ctprobe.m" -o "$ROOT/build/ctprobe"
  PROBE="$ROOT/build/ctprobe"
fi
"$PROBE" "$FONT" "Emoji26 Additions" --additive
echo "CoreText additive-font check passed for U+1FAE8, U+1FAE9 and U+1FA8A."
echo "The supplemental font correctly excludes legacy U+1F600."
open -a TextEdit || { echo "FAIL: TextEdit did not launch"; exit 1; }
if [ "$CURRENT_OS" = 10.9.5 ]; then open -a CharacterPalette || echo "WARN: launch Character Palette manually"; fi
if [ -d "$ROOT/Emoji26Picker.app" ]; then
  open "$ROOT/Emoji26Picker.app" || echo "WARN: launch Emoji26Picker manually"
fi
echo "Manual visual check required: paste 🫨 🫩 and the seven current macOS 26 additions into TextEdit."
echo "Verify colored glyphs and no crash. ZWJ/modifier sequences are not claimed by the additive font."
echo "PASS only after this visual check is recorded separately for this OS."
