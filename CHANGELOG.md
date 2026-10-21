# Changelog

All notable changes to Fourpages. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.2] - 2026-10-21

### Added
- Undo after highlighting text or adding a note, and after removing either.
- Bookmark button toggles: it fills in on a bookmarked page and tapping it
  again removes the bookmark (with Undo).
- Chapters & Notes lists your bookmarks; swipe or tap the bin to remove a
  bookmark, highlight or note, with Undo.
- Saved: swipe a quote, note or bookmark to remove it (Undo), or long-press
  for Open, Copy, Share and Remove. Newest first; notes show their text.

### Changed
- Reader footer is now a dock: a progress ring with the percentage, the
  chapter and pages left, and Bookmark and Aa buttons. Drag sideways on it
  to move through the book.
- Page overview no longer repeats the current chapter or the pages-left
  line; both stay in the footer.

### Fixed
- A quick double tap on a book opened two readers.
- Tapping Import twice opened two file pickers.
- Highlighting the same text twice stacked duplicate highlights.
- Undo after removing a book's whole library entry no longer brings its
  highlights back.

## [1.0.1] - 2026-10-20

### Added
- Book menu: long-press (or right-click) any book for Open, About this book,
  Move to shelf, Share book file and Remove from library.
- Large screens and tablets: cover grid with a details pane, settings with a
  detail pane, a three-pane reader with a two-page spread, and two PDF pages
  per row.

### Changed
- Reader footer: a new info pill with the chapter name, pages left,
  previous/next chapter buttons, the seek bar and the percentage.

### Fixed
- Removing a book now also deletes its progress, highlights, bookmarks,
  settings and cached files.

## [1.0.0] - 2026-10-19

First release.

### Added
- Shelves: create, rename, delete and reorder shelves; long-press a book and
  drag it between shelves; add books to a shelf from a checklist.
- In-app guide (Settings › i) explaining every feature and gesture.
- In-app update check against GitHub Releases.
- Support links: Ko-fi and Star on GitHub (Settings › About).
- Native Android reader engine (Kotlin page engine) with locators, CFI
  migration, highlights, notes, search and a scrolled mode.
- PDF reader with pinch zoom; TXT, Markdown, HTML and DOCX import.
- Reading reminders, haptics, reading stats, home-screen widget.
- Reader fonts: Literata, Lora, Source Serif, Atkinson Hyperlegible and
  IBM Plex Sans (all freely licensed).

[Unreleased]: https://github.com/sthrnilshaaa/fourpages/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/sthrnilshaaa/fourpages/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/sthrnilshaaa/fourpages/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/sthrnilshaaa/fourpages/releases/tag/v1.0.0
