/// Repository interface for persisting user annotations, highlights, and bookmarks.
library;

import 'dart:async';
import '../entities/annotation.dart';
import '../entities/bookmark.dart';

abstract class IAnnotationRepository {
  Future<List<Annotation>> getAnnotationsForPublication(String publicationId);
  Future<void> saveAnnotation(Annotation annotation);
  Future<void> deleteAnnotation(String annotationId);

  Future<List<Bookmark>> getBookmarksForPublication(String publicationId);
  Future<void> saveBookmark(Bookmark bookmark);
  Future<void> deleteBookmark(String bookmarkId);
}
