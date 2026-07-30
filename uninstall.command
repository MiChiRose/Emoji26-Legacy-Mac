#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
DEST="/System/Library/Fonts/Apple Color Emoji.ttc"; BASE="/Library/Application Support/EmojiLegacyPatch"; CURRENT="$BASE/current-backup"
[ -f "$CURRENT" ] || { echo "No installed backup record." >&2; exit 1; }
STAMP=`cat "$CURRENT"`; BACKUP="$BASE/backups/$STAMP/Apple Color Emoji.ttc"
[ -f "$BACKUP" ] || { echo "Backup missing: $BACKUP" >&2; exit 1; }
echo "Will restore $DEST from $BACKUP"; printf "Type RESTORE to continue: "; read answer; [ "$answer" = RESTORE ] || exit 0
[ "`id -u`" = 0 ] || exec sudo "$0"
TMP="$DEST.emoji-rollback.$$"; trap 'rm -f "$TMP"' EXIT HUP INT TERM
cp "$BACKUP" "$TMP" && chown root:wheel "$TMP" && chmod 644 "$TMP" || { echo "Cannot stage rollback." >&2; exit 1; }
mv "$TMP" "$DEST"; trap - EXIT HUP INT TERM
rm -f "$CURRENT"
echo "Restored original font. Restart to safely rebuild system font caches; no cache directories are deleted."
