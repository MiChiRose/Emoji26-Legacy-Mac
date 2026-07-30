#!/bin/sh
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
COPYFILE_DISABLE=1
export COPYFILE_DISABLE
FONT="$ROOT/payload/Emoji26 Additions.ttf"
PKGROOT="$ROOT/build/pkg-root"
APPDIR="$PKGROOT/Applications/Emoji 26 Additions"
TOOLSDIR="$APPDIR/bin"
DIST="$ROOT/dist"

[ -f "$FONT" ] || {
  echo "Run build-payload.command first." >&2
  exit 1
}

MODE=`awk -F= '$1=="mode" {print $2}' "$ROOT/manifest"`
[ "$MODE" = additive-only ] || {
  echo "Refusing to package a non-additive payload." >&2
  exit 1
}

EXPECTED=`awk -F= '$1=="additions_font_sha256" {print $2}' "$ROOT/manifest"`
ACTUAL=`shasum -a 256 "$FONT" | awk '{print $1}'`
[ "$EXPECTED" = "$ACTUAL" ] || {
  echo "Font differs from manifest." >&2
  exit 1
}

command -v pkgbuild >/dev/null 2>&1 || {
  echo "pkgbuild is unavailable." >&2
  exit 69
}

if [ -d "$PKGROOT" ]; then
  find "$PKGROOT" -depth -delete
fi

"$ROOT/build-picker.command"
mkdir -p "$PKGROOT/Library/Fonts" "$APPDIR" "$TOOLSDIR" "$DIST"
cp "$FONT" "$PKGROOT/Library/Fonts/Emoji26 Additions.ttf"
cp -R "$ROOT/build/Emoji26Picker.app" "$APPDIR/Emoji26Picker.app"
cp "$ROOT/uninstall.command" "$APPDIR/uninstall.command"
cp "$ROOT/verify.command" "$APPDIR/verify.command"
cp "$ROOT/manifest" "$APPDIR/manifest"
clang -arch x86_64 -mmacosx-version-min=10.8 \
  -framework Cocoa -framework CoreText \
  "$ROOT/tools/ctprobe.m" -o "$TOOLSDIR/ctprobe"
chmod 755 "$TOOLSDIR/ctprobe" "$APPDIR/uninstall.command" "$APPDIR/verify.command"
chmod 644 "$PKGROOT/Library/Fonts/Emoji26 Additions.ttf" "$APPDIR/manifest"
chmod 755 "$ROOT/pkg-scripts/preinstall" "$ROOT/pkg-scripts/postinstall"
xattr -cr "$PKGROOT"
find "$PKGROOT" -name '._*' -type f -delete

pkgbuild \
  --identifier org.emoji-legacy-patch.additions \
  --version 0.2.0 \
  --root "$PKGROOT" \
  --scripts "$ROOT/pkg-scripts" \
  --ownership recommended \
  --filter '(^|/)(\._.*|\.DS_Store|\.svn|CVS)(/|$)' \
  --install-location / \
  "$DIST/Emoji26-Additions-0.2.0.pkg"

echo "Built private local package: $DIST/Emoji26-Additions-0.2.0.pkg"
echo "It contains derived Apple glyph data; do not publish or commit it."
