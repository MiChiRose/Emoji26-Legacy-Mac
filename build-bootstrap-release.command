#!/bin/sh
# Produces a redistributable ZIP containing only this project's code/binaries.
set -eu

ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
VERSION="0.2.1-alpha.2"
WORK="$ROOT/build/bootstrap-release"
STAGE="$WORK/Emoji26 Installer Builder"
HOST_BIN="$STAGE/prebuilt/host"
TARGET_BIN="$STAGE/prebuilt/target"
ZIP="$ROOT/dist/Emoji26-Installer-Builder-$VERSION.zip"
CHECKSUM="$ZIP.sha256"

for tool in clang codesign lipo unzip zip; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Required build tool is unavailable: $tool" >&2
    exit 69
  }
done

if [ -d "$WORK" ]; then
  find "$WORK" -depth -delete
fi
mkdir -p "$HOST_BIN" "$TARGET_BIN" "$STAGE/tools" "$STAGE/picker" \
  "$STAGE/pkg-scripts" "$STAGE/dist" "$ROOT/dist"

clang -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  "$ROOT/tools/cmap-diff.c" \
  -o "$HOST_BIN/cmap-diff"
clang -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  "$ROOT/tools/font-additions-builder.c" \
  -o "$HOST_BIN/font-additions-builder"
clang -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  "$ROOT/tools/sfnt-audit.c" \
  -o "$HOST_BIN/sfnt-audit"
clang -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  -framework Cocoa -framework CoreText \
  "$ROOT/tools/ctprobe.m" -o "$HOST_BIN/ctprobe"

clang -arch x86_64 -mmacosx-version-min=10.8 -framework Cocoa \
  "$ROOT/EmojiPicker.m" -o "$TARGET_BIN/Emoji26Picker"
clang -arch x86_64 -mmacosx-version-min=10.8 \
  -framework Cocoa -framework CoreText \
  "$ROOT/tools/ctprobe.m" -o "$TARGET_BIN/ctprobe"

for binary in "$HOST_BIN"/* "$TARGET_BIN"/*; do
  codesign --force --sign - "$binary" >/dev/null 2>&1
  codesign --verify "$binary"
done

for file in \
  "Make Emoji Installer.command" \
  "Export Legacy Font.command" \
  build-payload.command build-additions.command build-picker.command \
  build-pkg.command install.command uninstall.command verify.command \
  manifest manifest.template EmojiPicker.m README.md README-RU.md \
  START-HERE.txt START-HERE-RU.txt LICENSE NOTICE.md; do
  cp "$ROOT/$file" "$STAGE/$file"
done

for file in cmap-diff.c font-additions-builder.c sfnt-audit.c ctprobe.m \
  emoji-table-audit.sh; do
  cp "$ROOT/tools/$file" "$STAGE/tools/$file"
done
cp "$ROOT/picker/Info.plist" "$STAGE/picker/Info.plist"
cp "$ROOT/pkg-scripts/preinstall" "$STAGE/pkg-scripts/preinstall"
cp "$ROOT/pkg-scripts/postinstall" "$STAGE/pkg-scripts/postinstall"

chmod 755 "$STAGE/"*.command "$STAGE/tools/emoji-table-audit.sh" \
  "$HOST_BIN"/* "$TARGET_BIN"/* "$STAGE/pkg-scripts/"*
chmod 644 "$STAGE/"*.md "$STAGE/LICENSE" "$STAGE/manifest" \
  "$STAGE/manifest.template" "$STAGE/EmojiPicker.m" "$STAGE/tools/"*.c \
  "$STAGE/tools/ctprobe.m" "$STAGE/picker/Info.plist" "$STAGE/"*.txt

find "$STAGE" -name '._*' -type f -delete
rm -f "$ZIP"
rm -f "$CHECKSUM"
(cd "$WORK" && /usr/bin/zip -qry -X "$ZIP" "Emoji26 Installer Builder")

echo "Built redistributable bootstrap: $ZIP"
echo "Checking that no Apple font or generated package entered the archive..."
if /usr/bin/unzip -Z1 "$ZIP" |
  grep -E '\.(ttc|ttf|otf|pkg)$' >/dev/null 2>&1; then
  echo "Refusing release: forbidden font/package content detected." >&2
  exit 1
fi
(cd "$ROOT/dist" &&
  shasum -a 256 "Emoji26-Installer-Builder-$VERSION.zip" \
    > "Emoji26-Installer-Builder-$VERSION.zip.sha256")
cat "$CHECKSUM"
