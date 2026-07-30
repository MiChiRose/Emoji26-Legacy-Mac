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
GENERATED_SCRIPTS="$ROOT/build/pkg-scripts"

[ -f "$FONT" ] || {
  echo "Run build-payload.command first." >&2
  exit 1
}

MODE=`awk -F= '$1=="mode" {print $2}' "$ROOT/manifest"`
[ "$MODE" = additive-only ] || {
  echo "Refusing to package a non-additive payload." >&2
  exit 1
}
TARGET_OS=`awk -F= '$1=="target_os" {print $2}' "$ROOT/manifest"`
case "$TARGET_OS" in
  10.8.5|10.9.5|10.10.5|10.11.6|10.12.6|10.13.6) ;;
  *) echo "Unsupported target OS in manifest: $TARGET_OS" >&2; exit 1 ;;
esac

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
if [ -d "$GENERATED_SCRIPTS" ]; then
  find "$GENERATED_SCRIPTS" -depth -delete
fi

"$ROOT/build-picker.command"
mkdir -p "$PKGROOT/Library/Fonts" "$APPDIR" "$TOOLSDIR" "$DIST" "$GENERATED_SCRIPTS"
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
sed "s/__TARGET_OS__/$TARGET_OS/g" \
  "$ROOT/pkg-scripts/preinstall" > "$GENERATED_SCRIPTS/preinstall"
cp "$ROOT/pkg-scripts/postinstall" "$GENERATED_SCRIPTS/postinstall"
chmod 755 "$GENERATED_SCRIPTS/preinstall" "$GENERATED_SCRIPTS/postinstall"
xattr -cr "$PKGROOT"
find "$PKGROOT" -name '._*' -type f -delete

pkgbuild \
  --identifier org.emoji-legacy-patch.additions \
  --version 0.2.0 \
  --root "$PKGROOT" \
  --scripts "$GENERATED_SCRIPTS" \
  --ownership recommended \
  --filter '(^|/)(\._.*|\.DS_Store|\.svn|CVS)(/|$)' \
  --install-location / \
  "$DIST/Emoji26-Additions-0.2.0-macos$TARGET_OS.pkg"

echo "Built private local package: $DIST/Emoji26-Additions-0.2.0-macos$TARGET_OS.pkg"
echo "It contains derived Apple glyph data; do not publish or commit it."
