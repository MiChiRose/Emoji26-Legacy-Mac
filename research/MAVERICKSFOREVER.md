# MavericksForever implementation review

Reviewed package:

- Project: <https://github.com/Wowfunhappy/Updated-Mavericks-Emojis>
- Release: `2025.08.30/Mavericks.Emoji.Update.pkg`
- Package SHA-256:
  `b2d1d7bd12e1a17737ca7b3b7fde5f903a1a404e2e744ae9b084c193a2ce72a4`
- Package signature status on macOS 26: unsigned

The package was expanded for static inspection only. It was not executed.

## Payload

The package installs:

1. `/Library/Fonts/Apple Color Emoji.ttc`
2. `/System/Library/Input Methods/CharacterPalette.app/Contents/Resources/Category-Emoji.plist`
3. Three replacement category images:
   `CategoryImage-NKo.pdf`, `CategoryImage-Tifinagh.pdf`, and
   `CategoryImage-Ugaritic.pdf`
4. `CharacterDB.sqlite3`

The font is installed as a Library-level overlay rather than replacing the
original Mavericks `/System/Library/Fonts/Apple Color Emoji.ttf`.

The package font:

- SHA-256:
  `a9dbc03ebb8d782822c8a6217329c06b06aeeeaf5c1f4756979d71ddaf1b2762`
- Size: 188,589,668 bytes
- TTC with two faces
- Contains `sbix`, `cmap`, and `morx`; does not contain `GSUB`
- Exposes 1,462 mapped Unicode code points in the first face
- Adds 598 mapped code points relative to the stock Mavericks font

The currently installed `/Library/Fonts/Apple Color Emoji.ttc` on the
read-only Mavericks test machine has the same SHA-256 and size. No files on
that machine were changed during this review.

## Character Palette technique

`Category-Emoji.plist` replaces the complete Mavericks emoji category list
with eight categories. Food, Activity, and Flags reuse three existing obscure
category image slots. The added category titles are literal English strings.

`CharacterDB.sqlite3` retains the Mavericks `unihan_dict(uchr, info)` schema.
The reviewed database has 70,168 rows and contains searchable entries for
single emoji and some multi-code-point sequences, including shaking face,
the Ukraine flag, and a family ZWJ sequence.

The public repository tracks `EmojiNames.strings`, but ignores both
`Apple Color Emoji.ttc` and the generated `CharacterDB.sqlite3`.

## Installer safety gaps

The package is useful research input, but its installer is not a safe base for
this project:

- it is unsigned;
- it has no uninstall package;
- it does not back up the Library-level font;
- backups use adjacent `.bk` files without hashes or metadata;
- the preinstall script restores every matching `*.bk` before making new
  backups and is written as a Bash array script despite a `/bin/sh` shebang;
- replacement of the five Character Palette resources is not atomic;
- it does not verify free space, ownership, permissions, or payload hashes;
- it supports only 10.9.5 and has no 10.8 path;
- it installs a complete newer Apple font, so it is not an “only missing
  emoji” payload.

## macOS 26 delta

The current macOS 26.5 font exposes 1,469 mapped Unicode code points. It has
seven mapped code points absent from the 2025-08-30 MavericksForever font:

`U+1F6D8`, `U+1FA8A`, `U+1FA8E`, `U+1FAC8`, `U+1FACD`, `U+1FAEA`,
and `U+1FAEF`.

The Mavericks CoreText probe of the current macOS 26 font showed that file
loading alone is insufficient: a new single code point was missing and family
and profession ZWJ sequences were not ligated.

## Design adopted here

This project adopts only the proven data-path observations:

- `/Library/Fonts` is preferable to replacing the stock system font;
- `Category-Emoji.plist` controls category membership;
- `CharacterDB.sqlite3` supplies expanded-picker search names.

It does not reuse or redistribute the package font or payload resources.
Instead, it computes the donor-versus-legacy `cmap` difference and will build a
separately named supplemental font containing only proven additions. ZWJ and
modifier sequences remain picker-only until the generated font passes actual
one-glyph shaping tests on each target OS.
