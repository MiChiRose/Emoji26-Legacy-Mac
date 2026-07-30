#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`; FONT=/Library/Fonts/Emoji26\ Additions.ttf
[ "`uname -m`" = x86_64 ] || { echo "FAIL: not x86_64"; exit 1; }
case "`sw_vers -productVersion`" in 10.8.5|10.9.5) ;; *) echo "FAIL: unsupported OS"; exit 1;; esac
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
if [ "`sw_vers -productVersion`" = 10.9.5 ]; then open -a CharacterPalette || echo "WARN: launch Character Palette manually"; fi
if [ -d "$ROOT/Emoji26Picker.app" ]; then
  open "$ROOT/Emoji26Picker.app" || echo "WARN: launch Emoji26Picker manually"
fi
echo "Manual visual check required: paste 🫨 🫩 and the seven current macOS 26 additions into TextEdit."
echo "Verify colored glyphs and no crash. ZWJ/modifier sequences are not claimed by the additive font."
echo "PASS only after this visual check is recorded separately for this OS."
