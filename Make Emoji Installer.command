#!/bin/sh
# Double-click builder. It reads only user-owned local fonts and never uploads them.
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
VERSION="0.2.1"

fail_dialog() {
  MESSAGE=$1
  osascript -e "display dialog \"$MESSAGE\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  echo "ERROR: $MESSAGE" >&2
  exit 1
}

case "`uname -m`" in
  arm64|x86_64) ;;
  *) fail_dialog "This builder requires an Intel or Apple silicon Mac." ;;
esac

HOST_OS=`sw_vers -productVersion`
HOST_MAJOR=`echo "$HOST_OS" | awk -F. '{print $1}'`
case "$HOST_MAJOR" in
  ''|*[!0-9]*) fail_dialog "Could not determine the build Mac version." ;;
esac
[ "$HOST_MAJOR" -ge 11 ] ||
  fail_dialog "Build this personal installer on macOS 11 or newer."

command -v osascript >/dev/null 2>&1 ||
  fail_dialog "AppleScript is unavailable."
command -v pkgbuild >/dev/null 2>&1 ||
  fail_dialog "The macOS pkgbuild tool is unavailable."

echo "No Apple font will be uploaded or included in the downloaded builder."

DONOR=""
if [ "$HOST_MAJOR" -eq 26 ]; then
  for CANDIDATE in \
    "/System/Library/Fonts/Apple Color Emoji.ttc" \
    "/System/Library/Fonts/Apple Color Emoji.ttf" \
    "/System/Library/Fonts/Supplemental/Apple Color Emoji.ttc"; do
    if [ -z "$DONOR" ] && [ -f "$CANDIDATE" ]; then
      DONOR=$CANDIDATE
    fi
  done
fi
if [ -z "$DONOR" ]; then
  DONOR=`osascript \
    -e 'POSIX path of (choose file with prompt "Choose Apple Color Emoji.ttc from your own macOS 26 installation")'` ||
    fail_dialog "The macOS 26 font selection was cancelled."
fi

LEGACY_DIR=""
if [ -f "$ROOT/Emoji Legacy Source/target-os.txt" ]; then
  LEGACY_DIR="$ROOT/Emoji Legacy Source"
else
  LEGACY_DIR=`osascript \
    -e 'POSIX path of (choose folder with prompt "Choose the Emoji Legacy Source folder created on your old Mac")'` ||
    fail_dialog "The legacy source folder selection was cancelled."
fi

[ -f "$LEGACY_DIR/target-os.txt" ] ||
  fail_dialog "The selected folder has no target-os.txt."
TARGET_OS=`tr -d '\r\n' < "$LEGACY_DIR/target-os.txt"`
case "$TARGET_OS" in
  10.8.5|10.9.5|10.10.5|10.11.6|10.12.6|10.13.6) ;;
  *) fail_dialog "Unsupported or invalid target OS: $TARGET_OS" ;;
esac

if [ -f "$LEGACY_DIR/Apple Color Emoji Legacy.ttf" ]; then
  LEGACY="$LEGACY_DIR/Apple Color Emoji Legacy.ttf"
elif [ -f "$LEGACY_DIR/Apple Color Emoji Legacy.ttc" ]; then
  LEGACY="$LEGACY_DIR/Apple Color Emoji Legacy.ttc"
else
  fail_dialog "The selected folder has no exported legacy emoji font."
fi

echo
echo "Planned local build:"
echo "  donor:    $DONOR"
echo "  legacy:   $LEGACY"
echo "  target:   $TARGET_OS"
echo "  upload:   none"
echo "  install:  none"
echo

"$ROOT/build-payload.command" \
  --font "$DONOR" \
  --legacy-font "$LEGACY" \
  --target-os "$TARGET_OS" ||
  fail_dialog "Font conversion or CoreText validation failed. See Terminal output."

"$ROOT/build-pkg.command" ||
  fail_dialog "Package creation failed. See Terminal output."

RESULT="$ROOT/dist/Emoji26-Additions-$VERSION-macos$TARGET_OS.pkg"
[ -f "$RESULT" ] || fail_dialog "The expected package was not created."

DESKTOP_RESULT="$HOME/Desktop/Emoji26-Additions-$VERSION-macos$TARGET_OS.pkg"
if [ -e "$DESKTOP_RESULT" ]; then
  STAMP=`date +%Y%m%d-%H%M%S`
  DESKTOP_RESULT="$HOME/Desktop/Emoji26-Additions-$VERSION-macos$TARGET_OS-$STAMP.pkg"
fi
cp "$RESULT" "$DESKTOP_RESULT"
SOURCE_SHA=`shasum -a 256 "$RESULT" | awk '{print $1}'`
DESKTOP_SHA=`shasum -a 256 "$DESKTOP_RESULT" | awk '{print $1}'`
[ "$SOURCE_SHA" = "$DESKTOP_SHA" ] ||
  fail_dialog "The Desktop package checksum did not match."
printf '%s  %s\n' "$DESKTOP_SHA" "`basename "$DESKTOP_RESULT"`" \
  > "$DESKTOP_RESULT.sha256"

echo
echo "SUCCESS: $DESKTOP_RESULT"
echo "This personal package contains derived Apple glyph data. Do not upload it."
open -R "$DESKTOP_RESULT" >/dev/null 2>&1 || true
osascript -e 'display dialog "Your personal emoji installer and checksum were created on the Desktop. Do not redistribute the package." buttons {"OK"} default button "OK" with icon note' >/dev/null 2>&1 || true
