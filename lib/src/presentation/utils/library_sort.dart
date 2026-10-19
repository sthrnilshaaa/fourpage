/// Ordering for library lists (Library tab and its sort sheet).
library;

import '../../../l10n/l10n.dart';
import '../state/app_preferences.dart';
import '../state/library_controller.dart';

String librarySortLabel(LibrarySort sort) => switch (sort) {
      LibrarySort.recentlyAdded => l10n.recentlyAdded,
      LibrarySort.title => l10n.titleAZ,
      LibrarySort.author => l10n.authorAZ,
      LibrarySort.progress => l10n.readingProgress,
    };

double _progressOf(BookItem book) => book.progress;

String _authorOf(BookItem book) =>
    book.publication.metadata.authors.isNotEmpty ? book.publication.metadata.authors.first : '';

/// Returns [books] in [sort] order. `recentlyAdded` keeps the library's own
/// order (newest import first).
List<BookItem> sortBooks(List<BookItem> books, LibrarySort sort) {
  final sorted = List<BookItem>.of(books);
  int byText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  switch (sort) {
    case LibrarySort.recentlyAdded:
      break;
    case LibrarySort.title:
      sorted.sort((a, b) => byText(a.publication.metadata.title, b.publication.metadata.title));
    case LibrarySort.author:
      sorted.sort((a, b) {
        final byAuthor = byText(_authorOf(a), _authorOf(b));
        return byAuthor != 0 ? byAuthor : byText(a.publication.metadata.title, b.publication.metadata.title);
      });
    case LibrarySort.progress:
      sorted.sort((a, b) => _progressOf(b).compareTo(_progressOf(a)));
  }
  return sorted;
}
