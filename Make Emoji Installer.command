#!/bin/sh
# Double-click builder. It reads only user-selected fonts and never uploads them.
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`

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

command -v osascript >/dev/null 2>&1 ||
  fail_dialog "AppleScript is unavailable."
command -v pkgbuild >/dev/null 2>&1 ||
  fail_dialog "The macOS pkgbuild tool is unavailable."

echo "No Apple font will be uploaded or included in this builder."
echo "Choose a macOS 26 donor font."
DONOR=`osascript \
  -e 'POSIX path of (choose file with prompt "Choose Apple Color Emoji.ttc from your own macOS 26 installation")'` ||
  fail_dialog "Font selection was cancelled."

echo "Choose the untouched stock emoji font from the exact target OS."
LEGACY=`osascript \
  -e 'POSIX path of (choose file with prompt "Choose the stock Apple Color Emoji font from the target old macOS")'` ||
  fail_dialog "Legacy font selection was cancelled."

TARGET_OS=`osascript \
  -e 'set picked to choose from list {"10.8.5", "10.9.5", "10.10.5", "10.11.6", "10.12.6", "10.13.6"} with prompt "Choose the exact target macOS version" default items {"10.9.5"}' \
  -e 'if picked is false then error number -128' \
  -e 'item 1 of picked'` ||
  fail_dialog "Target OS selection was cancelled."

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

RESULT="$ROOT/dist/Emoji26-Additions-0.2.0-macos$TARGET_OS.pkg"
[ -f "$RESULT" ] || fail_dialog "The expected package was not created."

echo
echo "SUCCESS: $RESULT"
echo "This personal package contains derived Apple glyph data. Do not upload it."
open -R "$RESULT" >/dev/null 2>&1 || true
osascript -e 'display dialog "Your personal emoji installer was created. Finder will show the file. Do not redistribute it." buttons {"OK"} default button "OK" with icon note' >/dev/null 2>&1 || true
