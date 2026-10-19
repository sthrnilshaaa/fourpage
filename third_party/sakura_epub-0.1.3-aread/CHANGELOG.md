# Changelog

All notable changes to **sakura_epub** will be documented in this file.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) · versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **sakura_epub** is a fork of [flutter_epub_viewer](https://pub.dev/packages/flutter_epub_viewer) by fayis.dev (BSD-3-Clause).  
> All changes below are relative to the upstream `flutter_epub_viewer` baseline.

---

## [0.1.3] — 2026-04-09

### Fixed

- **`EpubTheme` analyzer lint** — added the missing return type annotation for
  `_decorationToJson` to satisfy `lints_core` static analysis.

---

## [0.1.2] — 2026-04-08

### Fixed

- **Missing return type annotations** — all methods in `EpubController` that lacked explicit return
  types (`void`, `Future<void>`) now declare them, satisfying `type_annotate_public_apis` and
  related lints in stricter lint rulesets (e.g. `lints_core`).

---

## [0.1.1] — 2026-04-08

### Fixed

- **Font family picker now changes book text** — selecting a font in the reader settings actually
  applies that font to the epub content. Root cause: `font-family` CSS was applied via epub.js
  themes but the font bytes were never loaded inside the epub's isolated iframes, so the browser
  always fell back to the system default. Fix: added `setFontFamily()` which injects an
  `@font-face` declaration (with base64-encoded font data) directly into each rendered epub iframe
  and registers a content hook so newly navigated sections receive the same injection automatically.
- **`EpubController.setFontFamily()`** — new public API to set the reader font at runtime.
  Accepts `fontFamily`, optional `fontBase64` (base64-encoded ttf/otf bytes), and `fontMimeType`.
- **`EpubController` JS calls migrated to `callAsyncJavaScript`** — all `evaluateJavascript`
  calls that pass user-controlled strings (CFI, query, color values, etc.) were replaced with
  `callAsyncJavaScript(functionBody, arguments)` to avoid quoting/injection issues with special
  characters in CFI strings or search queries.
- **Stale `Completer` cancellation** — `getCurrentLocation()` and `search()` now cancel any
  in-flight completer before starting a new request, preventing stale callbacks from resolving
  future results incorrectly.

### Changed

- All `Color.withOpacity()` calls replaced with `Color.withValues(alpha:)` (Flutter deprecation).
- Color component accessors updated: `.alpha/.red/.green/.blue` → `.a/.r/.g/.b`.
- Removed redundant imports flagged by the analyzer.

---

## [0.1.0] — 2026-04-07

This is the first independent release of **sakura_epub**, forked from `flutter_epub_viewer` v1.2.8.

### Added

#### Typography & Appearance
- **16 bundled reader fonts** — fonts are embedded in the package so consumers need zero extra setup:
  New York, Gilroy, Alegreya, Amazon Ember, Atkinson Hyperlegible, Bitter Pro, Bookerly,
  Droid Sans, EB Garamond, Gentium Book Plus, Halant, IBM Plex Sans, Linux Libertine, Literata,
  Lora, Ubuntu
- **`EpubTheme` background color propagation** — the background color is now correctly extracted
  from `backgroundDecoration` (`BoxDecoration.color`) and forwarded to epub.js `updateTheme()` as
  a hex string. The upstream library always passed `null`, causing a black screen when the EPUB's
  own CSS set a dark body background.
- **`EpubController.updateTheme()` background fix** — same extraction applied to the runtime
  theme-switching path so live theme changes also set the epub.js body background correctly.

#### Stability & Performance
- **Base64 EPUB loading** — large EPUB files are now base64-encoded in Dart and decoded with
  `atob()` in JavaScript instead of being serialised as a comma-separated byte array
  (`[12,34,56,…]`). For a 17 MB file the JS string shrinks from ~51 MB to ~23 MB, eliminating
  OOM crashes and ANR timeouts on mid-range Android devices.
- **`epubView.js` base64 decoder** — the bundled JavaScript detects whether `data` is a `String`
  (base64) or an `Array` (legacy) and decodes accordingly, maintaining backward compatibility.

#### Package Infrastructure
- **Asset path corrected** — internal WebView asset reference updated from
  `packages/flutter_epub_viewer/lib/assets/webpage/html/swipe.html` to
  `packages/sakura_epub/lib/assets/webpage/html/swipe.html`.
- **Font asset paths corrected** — all `fonts:` entries in `pubspec.yaml` updated from the
  non-existent `assets/fonts/` to the real `lib/assets/fonts/` directory.
- **`pubspec.yaml` assets section cleaned** — removed non-existent `assets/fonts/` and
  `assets/animations/` entries; added correct `lib/assets/fonts/` entry.

#### Example App
- Complete rewrite of `example/lib/main.dart` with a modern, immersive reader UI:
  - Full-screen reader with tap-to-reveal top/bottom bars (animated fade)
  - Frosted-glass top bar: chapter list, search, and settings controls
  - Frosted-glass bottom bar: slim progress track, prev/next navigation
  - Draggable bottom sheet for reading settings (theme swatches + font-size slider)
  - Draggable chapter-list bottom sheet with numbered chips
  - Dedicated search input sheet and search-results sheet
  - Floating selection bar with one-tap highlight and clear actions
  - Animated loading screen (pulsing book icon + progress bar, themed to current epub background)
  - Full adaptive dark/light color system driven by the active `EpubThemeType`

---

## Upstream history (flutter_epub_viewer)

The following is a condensed history of the upstream library that sakura_epub was forked from.
Full details: https://pub.dev/packages/flutter_epub_viewer/changelog

| Version | Highlights |
|---------|-----------|
| 1.2.8 | Fixed `getCurrentLocation()` |
| 1.2.7 | Added `customCss` support in `EpubTheme` |
| 1.2.6 | Fixed dispose issue |
| 1.2.5 | `onTouchDown`/`onTouchUp`; `selectAnnotationRange`; XPath/XPointer navigation |
| 1.2.4 | `onSelection` with WebView-relative coords; `onSelectionChanging`; `onDeselection`; `clearSelectionOnPageChange`; selection block during navigation |
| 1.2.3 | iOS chapter parsing improvements |
| 1.2.2 | Book metadata (`getMetadata()`) |
| 1.2.1 | Theme change at runtime; first/last page navigation; font-size relocation fix |
| 1.2.0 | `EpubTheme` with background and foreground color |
| 1.1.6 | Remove-highlight fix |
| 1.1.5 | LTR/RTL fixes; sub-chapter parsing; `onRelocated` fix on Android |
| 1.1.4 | Size-fit fixes |
| 1.1.3 | Reading progress |
| 1.1.2 | Annotation click handler |
| 1.1.1 | Book reload fix |
| 1.1.0 | Local file & asset loading; underline annotation; text extraction |
| 1.0.1 | Fixed blank screen |
| 1.0.0 | Initial release — highlights, search, chapters, text selection, CFI navigation |
