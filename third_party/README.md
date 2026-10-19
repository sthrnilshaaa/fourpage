# Vendored package patches

## flutter_inappwebview_android-1.1.3-agp9-patch

`flutter_inappwebview_android` 1.1.3 (the latest published version as of
2026-09, pulled in transitively via `sakura_epub` -> `flutter_inappwebview`)
still calls `getDefaultProguardFile('proguard-android.txt')` in its
`android/build.gradle`. AGP 9.0+ removed that file outright (it forced
`-dontoptimize`, which blocks R8 optimizations), so any Android build fails
with:

    A problem occurred evaluating project ':flutter_inappwebview_android'.
    > `getDefaultProguardFile('proguard-android.txt')` is no longer
      supported ...

This is a known, currently-unfixed upstream issue - see
[pichillilorenzo/flutter_inappwebview#2852](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2852)
and [#2765](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2765)
(no patched release exists yet). This directory is an exact copy of the
published 1.1.3 package with the one-line fix applied
(`proguard-android.txt` -> `proguard-android-optimize.txt`), wired in via
`dependency_overrides` in the root `pubspec.yaml`.

**Remove this once upstream ships a real fix**: bump `sakura_epub`/
`flutter_inappwebview` to a version that pulls in a patched
`flutter_inappwebview_android`, delete this directory, and drop the
`dependency_overrides` entry.

## sakura_epub-0.1.3-aread

Copy of `sakura_epub` 0.1.3 with one feature added, wired in via
`dependency_overrides`:

- `EpubViewer(servedBook: EpubServedBook(...))` opens the book from an
  unpacked folder served by Android's WebViewAssetLoader
  (`https://appassets.androidplatform.net/books/<folder>/`, the reader page
  itself from `/assets/...` on the same origin) instead of base64-encoding
  the whole EPUB, sending it over the JavaScript bridge and unzipping it in
  JavaScript on every open. The app unpacks books natively once
  (`android/.../EpubUnpacker.kt`, `lib/src/presentation/platform/epub_unpacker.dart`).
- `EpubSource` loads its bytes lazily (only the fallback path reads them).
- `epubView.js` `loadBook(..., bookUrl)`: opens `bookUrl` when given.

Every change is marked `aread patch`. Other platforms (no servedBook) behave
exactly like upstream.

### Second patch in flutter_inappwebview_android

`AndroidInternalStoragePathHandler.toMap()` called itself instead of
`super.toMap()` (infinite recursion -> stack overflow while building the
WebView whenever an `InternalStoragePathHandler` is used). Fixed in
`lib/src/webview_asset_loader.dart`, marked `aread patch`.
