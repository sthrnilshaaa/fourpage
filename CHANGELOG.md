# Changelog

All notable changes to Fourpage. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.6] - 2026-10-28

### Added
- The screen stays on while a book is open.
- On phones with a 90/120 Hz display, the app runs at the fastest refresh
  rate.

### Changed
- The library opens instantly: books are listed right away and their files
  load in the background. A book still loading shows its own placeholder,
  replaced as soon as it's ready, instead of one placeholder for the whole
  screen. Opening a book that hasn't loaded yet loads it first.
- New page overview progress bar: book and chapter names, page count, and a
  percentage bubble at your position. Chapter pills only show while
  dragging between chapters.

### Fixed
- Tappable rows in the reader's side panes show their tap highlight.

## [1.0.5] - 2026-10-23

### Changed
- Reading is now full screen: the status bar and navigation bar hide with
  the reader controls and come back together with them (tap the page, or
  swipe in from the screen edge). The page uses the freed space.

## [1.0.4] - 2026-10-21

### Fixed
- Page overview: the previous/next chapter boxes and the chapter swipe work
  again in both reading modes, including books whose table of contents
  doesn't list every chapter.
- The next-chapter box in page mode is no longer hidden behind the footer.

## [1.0.3] - 2026-10-21

### Changed
- Renamed to Fourpage; the project now lives at github.com/sthrnilshaaa/fourpage.
- New versions are announced with a notification each time the app opens;
  tap it to update. With notifications off, the update dialog shows instead.

### Fixed
- Update downloads that stall or get cut off now fail cleanly instead of
  hanging or handing a broken file to the installer; downloads can be
  cancelled; an offline check no longer delays the next check by a day;
  release notes show without Markdown symbols.
- Importing a book that is already in the library keeps your copy and says
  so; rescanning a folder counts only new books.
- Scanning a folder shows progress, can't be started twice, and reports errors.
- Reset library also removes leftover book files and Recent Reading.

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

[Unreleased]: https://github.com/sthrnilshaaa/fourpage/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/sthrnilshaaa/fourpage/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/sthrnilshaaa/fourpage/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/sthrnilshaaa/fourpage/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/sthrnilshaaa/fourpage/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/sthrnilshaaa/fourpage/releases/tag/v1.0.0
