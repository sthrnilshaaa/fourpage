<div align="center">

<img src="media/banner.png" alt="Fourpage — a free, offline book reader" width="100%">

# Fourpage

**A free, offline book reader for Android. No ads, no account, no tracking.**

[![CI](https://github.com/sthrnilshaaa/fourpage/actions/workflows/ci.yml/badge.svg)](https://github.com/sthrnilshaaa/fourpage/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
![Downloads](https://img.shields.io/github/downloads/SthrNilshaaa/fourpage/total?style=for-the-badge&label=Downloads&color=blue&labelColor=24292f&logo=github)
[![GitHub stars](https://img.shields.io/github/stars/sthrnilshaaa/fourpage?style=social)](https://github.com/sthrnilshaaa/fourpage)
[![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-support-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/L2L124TL7L)

<a href="https://play.google.com/apps/testing/com.fourpages.reader"><img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="80"></a>

[**Download**](#download) · [Features](#features) · [Build](#build-from-source) · [Translate](#translations) · [Contribute](CONTRIBUTING.md) · [Support](#support)

</div>

---

## Screenshots

<table>
  <tr>
    <td align="center"><img src="media/screenshots/home.png" width="200" alt="Home"><br><sub>Home</sub></td>
    <td align="center"><img src="media/screenshots/shelves.png" width="200" alt="Shelves"><br><sub>Shelves</sub></td>
    <td align="center"><img src="media/screenshots/reader.png" width="200" alt="Reader"><br><sub>Reader</sub></td>
    <td align="center"><img src="media/screenshots/highlights.png" width="200" alt="Highlights"><br><sub>Highlights & notes</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="media/screenshots/library.png" width="200" alt="Library"><br><sub>Library</sub></td>
    <td align="center"><img src="media/screenshots/reader-controls.png" width="200" alt="Reader controls"><br><sub>Reader controls</sub></td>
    <td align="center"><img src="media/screenshots/saved.png" width="200" alt="Saved"><br><sub>Saved</sub></td>
    <td align="center"><img src="media/screenshots/settings.png" width="200" alt="Settings"><br><sub>Settings</sub></td>
  </tr>
</table>

## Features

**Library**
- Import **EPUB** and **PDF**; **TXT, Markdown, HTML and DOCX** are turned into books.
- Import single files or **scan whole folders**.
- **Shelves**: make your own, long-press a book and **drag it between shelves**.
- Sort by recently added, title, author or progress; Recent Reading on Home.

**Reading**
- Fast native Android reader: **paged** (with page-curl turns) or **scrolled**.
- Themes (paper, sepia, night, forest, black), fonts, text size, line spacing,
  alignment and margins, per book or as defaults for all books.
- Chapters, in-book search, bookmarks, a progress scrubber and "pages left".
- **Highlights in colours, notes, Copy / Share / Search, and Define** (dictionary).
- PDF with pinch zoom, pan and go-to-page.

**Everything else**
- Saved tab with all your bookmarks, quotes and notes across books.
- Reading stats, break reminders and a daily reading reminder.
- Home-screen widget to continue reading.
- Built-in **guide** to every feature (Settings › i).
- **Private by design**: books, notes and progress never leave your phone. See the [privacy policy](PRIVACY.md).

## Download

<a href="https://play.google.com/apps/testing/com.fourpages.reader"><img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="80"></a>

**Fourpage is in beta on Google Play.** To join:

1. Join the [Fourpage Testers Google Group](https://groups.google.com/g/fourpage-testers) (one click, with the Google account you use on your phone).
2. Open the [beta sign-up page](https://play.google.com/apps/testing/com.fourpages.reader) on your phone or computer, signed in with your Google account.
3. Tap **Become a tester**.
4. Install it from the [Play Store listing](https://play.google.com/store/apps/details?id=com.fourpages.reader). Updates arrive automatically.

Joining the beta also helps Fourpage get its full public release on Google Play.

You can also [build it from source](#build-from-source).

## Build from source

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) (stable, see
`FLUTTER_VERSION` in [`.github/workflows/ci.yml`](.github/workflows/ci.yml)), Java 17, Android SDK.

```sh
git clone https://github.com/sthrnilshaaa/fourpage.git
cd fourpage
flutter pub get
flutter run                     # Android
```

## Project structure

```
lib/                 Flutter app (core / domain / data / application / presentation)
android/app/         Android app
android/reader/      Native Kotlin reader engine (Readium parsing + own page engine)
shaders/             Page-curl shader
test/                Unit & widget tests
third_party/         Vendored, patched packages (see third_party/README.md)
media/               README / store images
.github/             CI (analyze & tests), issue & PR templates
```

## Translations

All UI text lives in [`lib/l10n/app_en.arb`](lib/l10n/app_en.arb). To add or improve a language:

1. Fork the repo.
2. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb` (for example `app_hi.arb`
   for Hindi, `app_es.arb` for Spanish) and translate the values. Keep the keys,
   the `{placeholders}` and the `@key` blocks as they are.
3. Run `flutter gen-l10n` and check it in the app (Settings › Appearance › Language).
4. Open a pull request. Partial translations are fine; missing strings fall back to English.

Not a coder? Open a [translation issue](https://github.com/sthrnilshaaa/fourpage/issues/new?template=translation.yml).

## Contributing

Bug reports, ideas and pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md),
and please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues:
see [SECURITY.md](SECURITY.md).

## Support

Fourpage is free and has no ads. If it's useful to you:

- ☕ [Buy a coffee on Ko-fi](https://ko-fi.com/L2L124TL7L)
- ⭐ [Star the repo](https://github.com/sthrnilshaaa/fourpage)
- Share it with a friend

## Acknowledgements

[Flutter](https://flutter.dev) ·
[Readium Kotlin Toolkit](https://github.com/readium/kotlin-toolkit) (BSD-3) ·
[sakura_epub](https://pub.dev/packages/sakura_epub) (BSD-3) ·
[flutter_inappwebview](https://github.com/pichillilorenzo/flutter_inappwebview) (Apache-2.0) ·
[epub.js](https://github.com/futurepress/epub.js) (BSD-2) ·
[Free Dictionary API](https://dictionaryapi.dev)

## License

Fourpage is free software under the [GNU General Public License v3.0](LICENSE).
You may use, study, share and change it; if you distribute a modified version,
it must also be GPL-3.0 with its source available.
