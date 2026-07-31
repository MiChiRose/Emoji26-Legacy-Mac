#!/bin/sh
# Read-only helper for the target legacy Mac.
set -eu

fail_dialog() {
  MESSAGE=$1
  osascript -e "display dialog \"$MESSAGE\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  echo "ERROR: $MESSAGE" >&2
  exit 1
}

[ "`uname -m`" = x86_64 ] ||
  fail_dialog "This helper must run on the target Intel Mac."

TARGET_OS=`sw_vers -productVersion`
case "$TARGET_OS" in
  10.8.5|10.9.5|10.10.5|10.11.6|10.12.6|10.13.6) ;;
  *) fail_dialog "Unsupported target system: $TARGET_OS" ;;
esac

SOURCE=""
if [ -f "/System/Library/Fonts/Apple Color Emoji.ttf" ]; then
  SOURCE="/System/Library/Fonts/Apple Color Emoji.ttf"
  SUFFIX="ttf"
elif [ -f "/System/Library/Fonts/Apple Color Emoji.ttc" ]; then
  SOURCE="/System/Library/Fonts/Apple Color Emoji.ttc"
  SUFFIX="ttc"
else
  fail_dialog "The stock system Apple Color Emoji font was not found."
fi

STAMP=`date +%Y%m%d-%H%M%S`
OUT="$HOME/Desktop/Emoji Legacy Source-$TARGET_OS-$STAMP"
FONT="$OUT/Apple Color Emoji Legacy.$SUFFIX"

mkdir -m 700 "$OUT"
cp "$SOURCE" "$FONT"
chmod 600 "$FONT"
printf '%s\n' "$TARGET_OS" > "$OUT/target-os.txt"
shasum -a 256 "$FONT" > "$OUT/legacy-font.sha256"
{
  echo "Personal source copied from your own target Mac."
  echo "Target OS: $TARGET_OS"
  echo
  echo "Copy this entire folder to the modern build Mac."
  echo "Do not upload or redistribute the Apple font inside it."
} > "$OUT/README.txt"

echo "Created: $OUT"
echo "No system file was modified."
open -R "$OUT" >/dev/null 2>&1 || true
osascript -e 'display dialog "Legacy source folder created on your Desktop. Copy the entire folder to your modern Mac." buttons {"OK"} default button "OK" with icon note' >/dev/null 2>&1 || true
