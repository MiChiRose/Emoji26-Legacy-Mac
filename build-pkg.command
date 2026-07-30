#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
[ -f "$ROOT/payload/Emoji26 Additions.ttf" ] || {
  echo "Additive font is not built. A full Apple Color Emoji TTC is never packaged." >&2
  exit 1
}
MODE=`awk -F= '$1=="mode" {print $2}' "$ROOT/manifest"`
[ "$MODE" = additive-only ] || {
  echo "Refusing to package a non-additive payload." >&2
  exit 1
}
command -v pkgbuild >/dev/null 2>&1 || { echo "pkgbuild unavailable. Use the .command scripts directly." >&2; exit 69; }
mkdir -p "$ROOT/dist"
pkgbuild --identifier org.emoji-legacy-patch --version 0.2.0 --root "$ROOT" --install-location /Applications/EmojiLegacyPatch "$ROOT/dist/EmojiLegacyPatch-0.2.0.pkg"
echo "Package built; inspect it before distribution."
