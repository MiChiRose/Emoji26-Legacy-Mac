#!/bin/sh
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
APP="$ROOT/build/Emoji26Picker.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"
LIST="$ROOT/payload/emoji26-additions.txt"

[ -f "$LIST" ] || {
  echo "Run build-payload.command first." >&2
  exit 1
}

mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/picker/Info.plist" "$APP/Contents/Info.plist"
cp "$LIST" "$RESOURCES/emoji26-additions.txt"
clang -arch x86_64 -mmacosx-version-min=10.8 -framework Cocoa \
  "$ROOT/EmojiPicker.m" -o "$MACOS/Emoji26Picker"
chmod 755 "$MACOS/Emoji26Picker"

echo "Built $APP for Intel OS X 10.8+."
