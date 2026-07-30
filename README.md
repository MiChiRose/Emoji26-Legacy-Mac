# Emoji Legacy Patch (research-grade, reversible)

Independent project for testing whether a user-owned modern `Apple Color Emoji.ttc` can work on **OS X 10.8.5/10.9.5, Intel x86_64**. It contains no Apple font binaries, no downloads, and never disables platform protections.

Development now follows an **additive-only** design. The stock system emoji
font is not replaced. `build-additions.command` compares the user-supplied
macOS 26 `cmap` with the stock legacy font and produces only the missing
code-point set. See the static
[MavericksForever package review](research/MAVERICKSFOREVER.md).

## Honest compatibility boundary

The project does **not** claim macOS 26 compatibility until `build-payload.command` and `verify.command` pass on each target OS and a human records actual colored rendering. A modern TTC may use tables or bitmap encodings unreadable by old CoreText. The portable table audit reports `sbix`, `cmap`, and `GSUB`; the CoreText probe rejects a font whose required characters cannot be mapped. It is coverage evidence, not proof that old CoreText applies all GSUB/ZWJ substitutions.

No lossless, legally redistributable general converter from Apple Color Emoji to a 10.8-compatible legacy format is included: conversion would require Apple glyph bitmaps and a validated target font compiler, and must be developed only after a target-machine failure proves the need. Do not claim flags, modifiers, ZWJ or VS16 support solely from a successful file replacement.

## Source and build

Use only fonts copied from macOS installations you own:

`./build-payload.command --font "/Volumes/Your macOS 26/System/Library/Fonts/Apple Color Emoji.ttc" --legacy-font "/path/to/stock/Apple Color Emoji.ttf"`

The command computes only code points absent from the stock legacy font. It
does not copy the full donor TTC into payload. Third-party mirrors are rejected
by policy.

The native builder extracts the first donor face, replaces `cmap` and `name`,
keeps `sbix`, and emits a separately named `Emoji26 Additions.ttf`. CoreText
then verifies representative new glyphs and confirms that legacy U+1F600 is
not exposed by the supplemental font.

`build-pkg.command` produces one private local installer containing the
supplemental font, x86_64 verifier, and AppKit picker. Because that package
contains derived Apple glyph data, it must not be committed or published.

A process-local test on real OS X 10.9.5 confirmed CoreText loading and color
`sbix` rendering for three representative additions without installing the
font. See [the Mavericks smoke-test record](research/TEST-MAVERICKS-10.9.5.md).

Run `./uninstall.command` and type `RESTORE` to roll back. Restart afterward rather than deleting caches.

## Picker and Mavericks research

`build-picker.command` builds a tiny 10.8-compatible AppKit picker that copies a selected test emoji to the pasteboard. It is the safe fallback until 10.8 Character Palette paths are captured read-only on a real system.

For 10.9, inspect (read-only first) `/System/Library/Input Methods/CharacterPalette.app/Contents/Resources/`, including `Category-Emoji.plist`, `CharacterDB.sqlite3`, and localized resources. This project intentionally does not modify them: those database/schema changes need separately versioned, real-Mavericks validation. The original research reports that Mavericks can lack skin-tone UI and that picker search has limitations; use it as investigation input, not as an installable payload: [Updated Mavericks Emojis](https://github.com/Wowfunhappy/Updated-Mavericks-Emojis).

## Test record required

For **each** 10.8.5 and 10.9.5, save the OS build, donor font SHA-256, table audit, probe result, and a visual result for `🫨`, `👍🏽`, `🇺🇦`, `👨‍👩‍👧`, `👩‍⚕️`, `❤️` in TextEdit. Also launch the appropriate picker and verify no crash. A clean install alone is not a pass.
