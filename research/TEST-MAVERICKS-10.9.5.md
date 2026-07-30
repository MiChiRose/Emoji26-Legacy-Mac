# Process-local smoke test: OS X Mavericks 10.9.5

Date: 2026-07-30

Target:

- Mac OS X 10.9.5
- Build 13F1911
- Intel x86_64

Scope:

- The package was not installed.
- Nothing was written to `/Library` or `/System`.
- The generated supplemental font and two x86_64 probes were copied only to
  `/private/tmp/Emoji26Smoke`.
- CoreText registered the font with process scope.
- The temporary directory was removed after the test.

Payload:

- Family: `Emoji26 Additions`
- PostScript name: `Emoji26Additions-Regular`
- Glyph count retained from donor face: 3,844
- Generated font SHA-256:
  `0bb5f74034134ccd6b2710d98f8928cee281bc4005634478e692f6fb8fed729a`

CoreText mapping result:

```text
resolved-family=Emoji26 Additions postscript=Emoji26Additions-Regular glyphs=3844
U+1FAE8=ok U+1FAE9=ok U+1FA8A=ok legacy-U+1F600=excluded
```

Rendering result:

- CoreText/AppKit produced a 420×120 RGBA PNG without crashing.
- U+1FAE8 SHAKING FACE rendered in color.
- U+1FAE9 FACE WITH BAGS UNDER EYES rendered in color.
- U+1FA8A TROMBONE rendered in color.
- Render PNG SHA-256:
  `351133a7ca5ac84f9bfbab8591fabde1c3f1e3fa109b8f808f4fed9966430d75`

This proves that Mavericks CoreText can load the generated additive font, map
representative macOS 26 additions, and decode/draw their retained `sbix`
bitmaps. It does not yet prove:

- fallback selection in arbitrary AppKit applications after installation;
- behavior after logout/restart and font-cache refresh;
- package install/uninstall rollback;
- the picker;
- all 571 mapped additions;
- ZWJ, modifier, flag, or variation-selector sequences;
- Mountain Lion 10.8.5 behavior.
