# Emoji26 Legacy Mac

Build a reversible, additive emoji package for Intel Macs running the final
releases of OS X/macOS 10.8 through 10.13.

This repository contains source code only. It does **not** contain Apple Color
Emoji, generated fonts, or a prebuilt installer. You build the package locally
from fonts copied from macOS installations that you own.

[Русская инструкция](README-RU.md)

## What it does

The builder compares a user-supplied macOS 26 `Apple Color Emoji.ttc` with the
stock Apple Color Emoji font from the target legacy OS. It produces a separately
named `Emoji26 Additions.ttf` containing only safe, previously missing,
single-code-point mappings.

Installation adds `/Library/Fonts/Emoji26 Additions.ttf`. It does not replace
the system Apple Color Emoji font and does not modify Character Palette. A small
AppKit picker is included because old Character Palette databases do not know
the new characters.

## Compatibility status

| Target | Status |
| --- | --- |
| OS X 10.9.5, Intel x86_64 | CoreText process-local loading and color `sbix` rendering confirmed on a real Mac |
| OS X 10.8.5 | Build target available; installation and rendering not yet verified |
| OS X 10.10.5–10.13.6 | Build targets available; installation and rendering not yet verified |

“Build target available” is not a claim that rendering works. Each generated
package is locked to one exact OS version and refuses installation elsewhere.
See the [Mavericks test record](research/TEST-MAVERICKS-10.9.5.md).

Confirmed on 10.9.5: the supplemental font loaded in CoreText and rendered
`U+1FAE8`, `U+1FAE9`, and `U+1FA8A` in color without installation. System-wide
fallback after installation, reboot behavior, and uninstall still require
human testing.

## Requirements

- A modern Mac running macOS 11 or newer for the downloadable builder.
- A user-owned macOS 26 `Apple Color Emoji.ttc`, copied from an installed system
  or an official Apple installer.
- The unmodified stock Apple Color Emoji font from the exact target OS.
- An Intel x86_64 target Mac running one of:
  `10.8.5`, `10.9.5`, `10.10.5`, `10.11.6`, `10.12.6`, or `10.13.6`.

Do not use third-party font mirrors or unknown binaries.

## Easiest path: downloadable builder

Download `Emoji26-Installer-Builder-0.2.0-alpha.1.zip` from the GitHub
prerelease, unpack it, and double-click `Make Emoji Installer.command`.
If Gatekeeper shows a warning for the unsigned research build, Control-click
the command, choose **Open**, and confirm only if the downloaded ZIP checksum
matches the accompanying `.sha256` asset.

The builder asks for:

1. Your macOS 26 `Apple Color Emoji.ttc`.
2. The untouched stock Apple Color Emoji font from the exact old target OS.
3. The exact target OS version.

It then creates a personal `.pkg` locally and reveals it in Finder. The
download contains only this project's open-source code and compiled tools. It
contains no Apple fonts, performs no upload, and installs nothing on the build
Mac. Xcode, Python, and Homebrew are not required for the downloadable builder.

The resulting personal `.pkg` does contain derived Apple glyph data. Keep it
for your own machines and do not redistribute it.

## Build

Example for Mavericks 10.9.5:

```sh
./build-payload.command \
  --font "/Volumes/macOS 26/System/Library/Fonts/Apple Color Emoji.ttc" \
  --legacy-font "/path/to/stock-10.9.5/Apple Color Emoji.ttf" \
  --target-os 10.9.5

./build-pkg.command
```

Building directly from a Git checkout requires Xcode Command Line Tools.

The result is
`dist/Emoji26-Additions-0.2.0-macos10.9.5.pkg`. It contains derived Apple glyph
data and is for your own machines only: do not publish, upload, or commit it.

Before installation, keep a copy of the generated `manifest`; it records the
target OS, build mode, byte size, and SHA-256 digest.

## Install, verify, and uninstall

Open the locally built `.pkg` on the matching legacy Mac. The installer verifies
the exact OS version, x86_64 architecture, payload digest, available space, and
backs up any older copy of this project's supplemental font. It leaves system
Apple fonts and Character Palette unchanged.

After restarting, run the installed verifier:

```sh
"/Applications/Emoji 26 Additions/verify.command"
```

Then visually test the picker and TextEdit. To remove the patch:

```sh
"/Applications/Emoji 26 Additions/uninstall.command"
```

Type the requested confirmation and restart. The rollback touches only this
project's supplemental font.

## Rendering limits

The current safe payload deliberately excludes ZWJ, variation-selector, skin
tone, regional-indicator, tag, keycap, and existing legacy mappings. Therefore
it does **not** claim new flags, skin-tone combinations, family/profession ZWJ
sequences, or VS15/VS16 behavior. The picker can copy strings, but copying a
sequence is not proof that old AppKit can render it.

The native audit covers `cmap`, `sbix`, and `GSUB`. Old CoreText behavior must
still be visually verified on every target version. A successful installation
alone is not a rendering pass.

## Safety and provenance

- No network downloads or `curl | sh`.
- No replacement of `/System/Library/Fonts/Apple Color Emoji.ttf`.
- No Character Palette database edits.
- No disabling system protections.
- Exact paths only; no recursive deletion or broad globs.
- Local package generation only; Apple font binaries are Git-ignored.
- The published bootstrap archive is scanned to reject `.ttc`, `.ttf`, `.otf`,
  and `.pkg` entries before release.

The design was informed by a static review of
[Updated Mavericks Emojis](https://github.com/Wowfunhappy/Updated-Mavericks-Emojis)
and its MavericksForever package. This implementation intentionally uses a
different additive, reversible model. See
[research/MAVERICKSFOREVER.md](research/MAVERICKSFOREVER.md).

## License

Project source code is available under the MIT License. Apple Color Emoji,
Apple glyph artwork, macOS, and related marks belong to Apple Inc. and are not
licensed or distributed by this repository. See [NOTICE.md](NOTICE.md).
