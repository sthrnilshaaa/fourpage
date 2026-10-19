/// Picks which reader engine opens a book, and pushes its screen.
///
/// sakura_epub (WebView + epub.js) only ships native implementations for
/// Android/iOS/Windows/macOS - not Linux or Web, which this app also
/// targets. So: sakura_epub there, and the original pure-Flutter/epubx
/// renderer (ReaderScreen) everywhere else. Both read/write the same
/// ReadingSession-backed SQLite storage (annotations, bookmarks, progress,
/// per-book preferences), so this choice is purely about rendering - not
/// about which data a book has.
///
/// Build-time gate: `--dart-define=AREAD_READER_ENGINE=auto|sakura|epubx`
/// (default `auto`). `epubx` forces the pure-Flutter reader anywhere (e.g.
/// to compare engines on an Android device); `sakura` is only honoured on
/// platforms that have its WebView plugin and otherwise falls back to
/// epubx, so no flag value can produce a build that calls a missing plugin.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/locator.dart';
import '../screens/pdf_reader_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/native_reader_screen.dart';
import '../screens/sakura_reader_screen.dart';
import '../state/library_controller.dart';

/// native: the Kotlin PageEngine under the Flutter reader UI (Android).
enum ReaderEngine { native, sakura, epubx }

/// The value of `--dart-define=AREAD_READER_ENGINE=...`, fixed at compile time.
const String readerEngineOverride = String.fromEnvironment('AREAD_READER_ENGINE', defaultValue: 'auto');

/// Whether sakura_epub's WebView plugin exists for [platform].
bool sakuraSupports(TargetPlatform platform, {required bool isWeb}) {
  if (isWeb) return false;
  return platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS;
}

bool get isSakuraEpubSupportedPlatform => sakuraSupports(defaultTargetPlatform, isWeb: kIsWeb);

/// Resolves the engine for a platform and override value. Pure, so the gate
/// is unit-testable for every platform from any host.
ReaderEngine resolveReaderEngine({
  required TargetPlatform platform,
  required bool isWeb,
  String override = readerEngineOverride,
}) {
  final supported = sakuraSupports(platform, isWeb: isWeb);
  switch (override.trim().toLowerCase()) {
    case 'epubx':
      return ReaderEngine.epubx;
    case 'sakura':
      return supported ? ReaderEngine.sakura : ReaderEngine.epubx;
    case 'native':
    case 'auto':
    default:
      if (platform == TargetPlatform.android && !isWeb) return ReaderEngine.native;
      return supported ? ReaderEngine.sakura : ReaderEngine.epubx;
  }
}

ReaderEngine get currentReaderEngine => resolveReaderEngine(platform: defaultTargetPlatform, isWeb: kIsWeb);

Future<void> openReader(BuildContext context, BookItem book, {Locator? initialLocator}) {
  final Widget screen = book.isPdf ? PdfReaderScreen(book: book) : switch (currentReaderEngine) {
    ReaderEngine.native => NativeReaderScreen(book: book, initialLocator: initialLocator),
    ReaderEngine.sakura => SakuraReaderScreen(book: book, initialLocator: initialLocator),
    ReaderEngine.epubx => ReaderScreen(book: book, initialLocator: initialLocator),
  };

  LibraryController.instance.markOpened(book);
  return Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => screen))
      .whenComplete(LibraryController.instance.readerClosed);
}
