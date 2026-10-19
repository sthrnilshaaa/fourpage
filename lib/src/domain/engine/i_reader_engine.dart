/// Abstract reader engine contract for multi-engine EPUB rendering (Pure Flutter, WebView EPUB.js, Native Readium).
library;

import '../../domain/entities/locator.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/reader_preferences.dart';
import '../../domain/entities/search_match.dart';
import '../../application/state/reader_state.dart';

enum EngineType { pureFlutter, webViewEpubJs, nativeReadium }

abstract class IReaderEngine {
  EngineType get engineType;

  /// Stream emitting reader state updates from this engine.
  Stream<ReaderState> get stateStream;

  /// Initializes and opens an EPUB publication archive.
  Future<Publication> open(List<int> archiveBytes);

  /// Navigates to the next page / spine item.
  Future<void> nextPage();

  /// Navigates to the previous page / spine item.
  Future<void> previousPage();

  /// Navigates directly to a target Locator position.
  Future<void> goTo(Locator locator);

  /// Executes full-text search across publication content.
  Future<List<SearchMatch>> search(String query);

  /// Updates reader preferences (theme, font size, line height, alignment).
  Future<void> updatePreferences(ReaderPreferences preferences);


  /// Closes the current reading session and frees engine resources.
  Future<void> close();
}
