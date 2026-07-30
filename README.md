# Emoji Legacy Patch (research-grade, reversible)

Independent project for testing whether a user-owned modern `Apple Color Emoji.ttc` can work on **OS X 10.8.5/10.9.5, Intel x86_64**. It contains no Apple font binaries, no downloads, and never disables platform protections.

## Honest compatibility boundary

The project does **not** claim macOS 26 compatibility until `build-payload.command` and `verify.command` pass on each target OS and a human records actual colored rendering. A modern TTC may use tables or bitmap encodings unreadable by old CoreText. The portable table audit reports `sbix`, `cmap`, and `GSUB`; the CoreText probe rejects a font whose required characters cannot be mapped. It is coverage evidence, not proof that old CoreText applies all GSUB/ZWJ substitutions.

No lossless, legally redistributable general converter from Apple Color Emoji to a 10.8-compatible legacy format is included: conversion would require Apple glyph bitmaps and a validated target font compiler, and must be developed only after a target-machine failure proves the need. Do not claim flags, modifiers, ZWJ or VS16 support solely from a successful file replacement.

## Source and build

On each target Mac, use only a font copied from a macOS 26 volume you own:

`./build-payload.command --font "/Volumes/Your macOS 26/System/Library/Fonts/Apple Color Emoji.ttc"`

The `--macos-root` alternative accepts a mounted user-owned system volume. `--installer` deliberately does not automate extraction: mount an official Apple installer yourself and pass its verified font path. Third-party mirrors are rejected by policy, not used by this repository.

Run `./verify.command` before `./install.command`. Installation prints its exact one-file change, checks 10.8.5/10.9.5 and x86_64, hashes the payload, checks space, requires typing `INSTALL`, backs up file/hash/owner/group/mode, stages beside the destination, and uses `mv` for replacement. It does not change Character Palette resources.

Run `./uninstall.command` and type `RESTORE` to roll back. Restart afterward rather than deleting caches.

## Picker and Mavericks research

`build-picker.command` builds a tiny 10.8-compatible AppKit picker that copies a selected test emoji to the pasteboard. It is the safe fallback until 10.8 Character Palette paths are captured read-only on a real system.

For 10.9, inspect (read-only first) `/System/Library/Input Methods/CharacterPalette.app/Contents/Resources/`, including `Category-Emoji.plist`, `CharacterDB.sqlite3`, and localized resources. This project intentionally does not modify them: those database/schema changes need separately versioned, real-Mavericks validation. The original research reports that Mavericks can lack skin-tone UI and that picker search has limitations; use it as investigation input, not as an installable payload: [Updated Mavericks Emojis](https://github.com/Wowfunhappy/Updated-Mavericks-Emojis).

## Test record required

For **each** 10.8.5 and 10.9.5, save the OS build, donor font SHA-256, table audit, probe result, and a visual result for `🫨`, `👍🏽`, `🇺🇦`, `👨‍👩‍👧`, `👩‍⚕️`, `❤️` in TextEdit. Also launch the appropriate picker and verify no crash. A clean install alone is not a pass.
