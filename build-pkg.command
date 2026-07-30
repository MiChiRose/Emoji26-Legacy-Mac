#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
[ -f "$ROOT/payload/Apple Color Emoji.ttc" ] || { echo "Run build-payload.command first; no font is stored in Git." >&2; exit 1; }
command -v pkgbuild >/dev/null 2>&1 || { echo "pkgbuild unavailable. Use the .command scripts directly." >&2; exit 69; }
mkdir -p "$ROOT/dist"
pkgbuild --identifier org.emoji-legacy-patch --version 0.1.0 --root "$ROOT" --install-location /Applications/EmojiLegacyPatch "$ROOT/dist/EmojiLegacyPatch-0.1.0.pkg"
echo "Package built; inspect it before distribution."
