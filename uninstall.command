#!/bin/sh
# Removes/restores only this project's supplemental font.
set -eu

DEST="/Library/Fonts/Emoji26 Additions.ttf"
STATE="/Library/Application Support/EmojiLegacyPatch"
CURRENT="$STATE/current-backup"
CONFIRMED=${1-}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[ -f "$CURRENT" ] || fail "No installed additive-font record."
STAMP=`cat "$CURRENT"`
BACKUP="$STATE/backups/$STAMP"
META="$BACKUP/metadata.txt"
[ -f "$META" ] || fail "Backup metadata is missing."
PREVIOUS=`awk -F= '$1=="previous" {print $2}' "$META"`

if [ "$CONFIRMED" != --confirmed ]; then
  echo "Will remove only: $DEST"
  if [ "$PREVIOUS" = present ]; then
    echo "Will restore the previous file from: $BACKUP"
  fi
  echo "System Apple Color Emoji files remain unchanged."
  printf "Type REMOVE-ADDITIONS to continue: "
  read answer
  [ "$answer" = REMOVE-ADDITIONS ] || { echo "Cancelled."; exit 0; }
  [ "`id -u`" = 0 ] || exec sudo "$0" --confirmed
fi

[ "`id -u`" = 0 ] || fail "Root privileges were not obtained."

if [ "$PREVIOUS" = present ]; then
  SOURCE="$BACKUP/Emoji26 Additions.ttf"
  [ -f "$SOURCE" ] || fail "Previous supplemental font backup is missing."
  TMP="/Library/Fonts/.Emoji26-Rollback.$$"
  trap 'rm -f "$TMP"' EXIT HUP INT TERM
  cp "$SOURCE" "$TMP" &&
    chown root:wheel "$TMP" &&
    chmod 644 "$TMP" ||
    fail "Could not stage rollback."
  mv "$TMP" "$DEST" || fail "Atomic rollback rename failed."
  trap - EXIT HUP INT TERM
else
  QUARANTINE="$BACKUP/removed-Emoji26-Additions.ttf"
  [ -f "$DEST" ] && mv "$DEST" "$QUARANTINE"
fi

rm -f "$CURRENT"
echo "Additive font removed/restored. Restart to refresh font services."
