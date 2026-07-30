#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`; FONT=/Library/Fonts/Emoji26\ Additions.ttf
[ "`uname -m`" = x86_64 ] || { echo "FAIL: not x86_64"; exit 1; }
case "`sw_vers -productVersion`" in 10.8.5|10.9.5) ;; *) echo "FAIL: unsupported OS"; exit 1;; esac
[ -f "$FONT" ] || { echo "FAIL: font absent"; exit 1; }
mkdir -p "$ROOT/build"; clang -framework Cocoa -framework CoreText "$ROOT/tools/ctprobe.m" -o "$ROOT/build/ctprobe"
"$ROOT/build/ctprobe" "$FONT" "Emoji26 Additions"
echo "CoreText glyph coverage check passed. This checks single U+1FAE8, skin tone, flag, family ZWJ, profession ZWJ, and VS16."
open -a TextEdit || { echo "FAIL: TextEdit did not launch"; exit 1; }
if [ "`sw_vers -productVersion`" = 10.9.5 ]; then open -a CharacterPalette || echo "WARN: launch Character Palette manually"; fi
echo "Manual visual check required: paste 🫨 👍🏽 🇺🇦 👨‍👩‍👧 👩‍⚕️ ❤️ into TextEdit; verify colored glyphs and no crash."
echo "PASS only after this visual check is recorded separately for this OS."
