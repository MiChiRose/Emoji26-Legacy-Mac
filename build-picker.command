#!/bin/sh
set -eu
ROOT=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`; mkdir -p "$ROOT/build"
clang -framework Cocoa -mmacosx-version-min=10.8 "$ROOT/EmojiPicker.m" -o "$ROOT/build/EmojiLegacyPicker"
echo "Built $ROOT/build/EmojiLegacyPicker"
