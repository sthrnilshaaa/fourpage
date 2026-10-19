/// In-memory repository implementation for annotations and bookmarks.
library;

import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/repositories/i_annotation_repository.dart';

class InMemoryAnnotationRepository implements IAnnotationRepository {
  final Map<String, List<Annotation>> _annotations = {};
  final Map<String, List<Bookmark>> _bookmarks = {};

  @override
  Future<List<Annotation>> getAnnotationsForPublication(String publicationId) async {
    return List.unmodifiable(_annotations[publicationId] ?? []);
  }

  @override
  Future<void> saveAnnotation(Annotation annotation) async {
    final list = _annotations.putIfAbsent(annotation.publicationId, () => []);
    list.removeWhere((a) => a.id == annotation.id);
    list.add(annotation);
  }

  @override
  Future<void> deleteAnnotation(String annotationId) async {
    for (final list in _annotations.values) {
      list.removeWhere((a) => a.id == annotationId);
    }
  }

  @override
  Future<List<Bookmark>> getBookmarksForPublication(String publicationId) async {
    return List.unmodifiable(_bookmarks[publicationId] ?? []);
  }

  @override
  Future<void> saveBookmark(Bookmark bookmark) async {
    final list = _bookmarks.putIfAbsent(bookmark.publicationId, () => []);
    list.removeWhere((b) => b.id == bookmark.id);
    list.add(bookmark);
  }

  @override
  Future<void> deleteBookmark(String bookmarkId) async {
    for (final list in _bookmarks.values) {
      list.removeWhere((b) => b.id == bookmarkId);
    }
  }
}
