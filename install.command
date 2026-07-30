#!/bin/sh
# Installs only a separately named supplemental font. Never replaces Apple fonts.
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
FONT="$ROOT/payload/Emoji26 Additions.ttf"
MANIFEST="$ROOT/manifest"
DEST="/Library/Fonts/Emoji26 Additions.ttf"
STATE="/Library/Application Support/EmojiLegacyPatch"
CONFIRMED=${1-}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -f "$FONT" ] || fail "Additive font is not built: $FONT"
[ -f "$MANIFEST" ] || fail "Manifest is missing."

[ "`uname -m`" = x86_64 ] || fail "Intel x86_64 is required."
VER=`sw_vers -productVersion`
TARGET_OS=`awk -F= '$1=="target_os" {print $2}' "$MANIFEST"`
case "$TARGET_OS" in
  10.8.5|10.9.5|10.10.5|10.11.6|10.12.6|10.13.6) ;;
  *) fail "Manifest contains unsupported target OS: $TARGET_OS" ;;
esac
[ "$VER" = "$TARGET_OS" ] ||
  fail "This payload targets $TARGET_OS; current OS is $VER."

MODE=`awk -F= '$1=="mode" {print $2}' "$MANIFEST"`
[ "$MODE" = additive-only ] || fail "Manifest is not additive-only."

EXPECTED=`awk -F= '$1=="additions_font_sha256" {print $2}' "$MANIFEST"`
[ -n "$EXPECTED" ] && [ "$EXPECTED" != UNBUILT ] ||
  fail "Manifest has no validated additive-font hash."
ACTUAL=`shasum -a 256 "$FONT" | awk '{print $1}'`
[ "$EXPECTED" = "$ACTUAL" ] || fail "Payload hash differs from manifest."

NEEDED=`wc -c < "$FONT" | tr -d ' '`
FREE=`df -k /Library | awk 'NR==2 {print $4*1024}'`
[ "$FREE" -gt "$NEEDED" ] || fail "Insufficient free space."

if [ "$CONFIRMED" != --confirmed ]; then
  echo "Planned changes:"
  echo "  install: $DEST"
  echo "  state:   $STATE"
  echo "  unchanged: /System/Library/Fonts/Apple Color Emoji.ttf"
  echo "  unchanged: /System/Library/Input Methods/CharacterPalette.app"
  printf "Type ADDITIONS to continue (or anything else to cancel): "
  read answer
  [ "$answer" = ADDITIONS ] || { echo "Cancelled."; exit 0; }
  [ "`id -u`" = 0 ] || exec sudo "$0" --confirmed
fi

[ "`id -u`" = 0 ] || fail "Root privileges were not obtained."
STAMP=`date +%Y%m%d-%H%M%S`
BACKUP="$STATE/backups/$STAMP"
mkdir -p "$BACKUP" || fail "Cannot create state directory."

if [ -f "$DEST" ]; then
  {
    echo "previous=present"
    echo "path=$DEST"
    shasum -a 256 "$DEST"
    stat -f 'owner=%Su group=%Sg mode=%Lp bytes=%z' "$DEST"
  } > "$BACKUP/metadata.txt"
  cp -p "$DEST" "$BACKUP/Emoji26 Additions.ttf" ||
    fail "Existing supplemental-font backup failed."
else
  {
    echo "previous=absent"
    echo "path=$DEST"
  } > "$BACKUP/metadata.txt"
fi

TMP="/Library/Fonts/.Emoji26-Additions.$$"
trap 'rm -f "$TMP"' EXIT HUP INT TERM
cp "$FONT" "$TMP" &&
  chown root:wheel "$TMP" &&
  chmod 644 "$TMP" ||
  fail "Could not stage supplemental font."
mv "$TMP" "$DEST" || fail "Atomic installation rename failed."
trap - EXIT HUP INT TERM

echo "$STAMP" > "$STATE/current-backup"
echo "Installed additive font only. Restart, then run verify.command."
