# Contributing to Fourpages

Thanks for helping! Bug reports, ideas, translations and code are all welcome.

## Ways to help

- **Report a bug or suggest a feature:** open an [issue](https://github.com/sthrnilshaaa/fourpages/issues/new/choose).
- **Translate the app:** see [Translations](README.md#translations). No coding needed.
- **Fix something:** look for issues labelled `good first issue` or `help wanted`.

## Working on the code

1. Install Flutter (stable; CI uses the version in `.github/workflows/ci.yml`) and Java 17.
2. Fork and clone, then:
   ```sh
   flutter pub get
   flutter run            # Android, github flavor by default
   ```
3. Make your change on a branch (`fix/scroll-jump`, `feat/shelf-colors`, ...).
4. Before opening a pull request:
   ```sh
   flutter analyze
   flutter test
   dart format <files you changed>
   ```
5. Open the pull request and fill in the template.

Code layout: `lib/src/` is split into `core/`, `domain/` (entities and
interfaces), `data/` (storage, parsers, engines), `application/` (reading
session and commands) and `presentation/` (screens, widgets, state).

## Rules of thumb

- Every user-facing string goes in `lib/l10n/app_en.arb`.
- No fake data in the UI: show real data or an honest empty state.
- Keep the app offline and private: no analytics, no tracking, no accounts.
- Don't commit books. Keep sample books outside the repo or in the
  git-ignored `test-books/` folder.
- Commit messages: a short imperative summary line, then a body explaining why.

## License

By contributing you agree that your work is licensed under the
[GNU GPL v3.0](LICENSE), the same as the rest of the project.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).
