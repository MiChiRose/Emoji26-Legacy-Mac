#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
FONT="$ROOT/payload/Apple Color Emoji.ttc"
MANIFEST="$ROOT/manifest"
DEST="/System/Library/Fonts/Apple Color Emoji.ttc"
BACKUP_ROOT="/Library/Application Support/EmojiLegacyPatch/backups"
fail(){ echo "ERROR: $*" >&2; exit 1; }
[ "`uname -m`" = x86_64 ] || fail "Intel x86_64 is required."
VER=`sw_vers -productVersion`; case "$VER" in 10.8.5|10.9.5) ;; *) fail "Supported only on 10.8.5 or 10.9.5; found $VER";; esac
[ -f "$FONT" ] && [ -f "$MANIFEST" ] || fail "Build payload and manifest first."
EXPECTED=`awk -F= '$1=="font_sha256" {print $2}' "$MANIFEST"`; ACTUAL=`shasum -a 256 "$FONT" | awk '{print $1}'`; [ "$EXPECTED" = "$ACTUAL" ] || fail "Payload hash differs from manifest."
[ -f "$DEST" ] || fail "System font not found: $DEST"
NEEDED=`wc -c < "$FONT" | tr -d ' '`; FREE=`df -k /System | awk 'NR==2 {print $4*1024}'`; [ "$FREE" -gt "$NEEDED" ] || fail "Insufficient free space."
echo "Planned changes:"; echo "  replace: $DEST"; echo "  backup:  $BACKUP_ROOT/<timestamp>/Apple Color Emoji.ttc"; echo "  manifest: $BACKUP_ROOT/<timestamp>/metadata.txt"; echo "  no Character Palette files are modified by this installer."
printf "Type INSTALL to continue (or anything else to cancel): "; read answer; [ "$answer" = INSTALL ] || { echo "Cancelled."; exit 0; }
[ "`id -u`" = 0 ] || exec sudo "$0"
STAMP=`date +%Y%m%d-%H%M%S`; BACKUP="$BACKUP_ROOT/$STAMP"; mkdir -p "$BACKUP" || fail "Cannot create backup."
{ echo "path=$DEST"; shasum -a 256 "$DEST"; stat -f 'owner=%Su group=%Sg mode=%Lp bytes=%z' "$DEST"; } > "$BACKUP/metadata.txt"
cp -p "$DEST" "$BACKUP/Apple Color Emoji.ttc" || fail "Backup failed; no replacement made."
TMP="$DEST.emoji-legacy-patch.$$"; trap 'rm -f "$TMP"' EXIT HUP INT TERM
cp "$FONT" "$TMP" && chown root:wheel "$TMP" && chmod 644 "$TMP" || fail "Could not stage replacement."
mv "$TMP" "$DEST" || fail "Atomic rename failed; original backup preserved."
trap - EXIT HUP INT TERM
echo "$STAMP" > "/Library/Application Support/EmojiLegacyPatch/current-backup"
echo "Installed. Restart before judging rendering; then run verify.command."
