/// UseCase for managing user highlights, notes, and bookmarks.
library;

import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/locator.dart';
import '../../domain/repositories/i_annotation_repository.dart';

class ManageAnnotationsUseCase {
  final IAnnotationRepository _repository;

  ManageAnnotationsUseCase(this._repository);

  Future<Annotation> createAnnotation({
    required String publicationId,
    required Locator locator,
    String? textQuote,
    String? note,
    String colorHex = '#FFD54F',
    AnnotationType type = AnnotationType.highlight,
  }) async {
    final annotation = Annotation(
      id: 'ann-${DateTime.now().millisecondsSinceEpoch}',
      publicationId: publicationId,
      locator: locator,
      textQuote: textQuote ?? locator.text?.highlight,
      textPrefix: locator.text?.before,
      textSuffix: locator.text?.after,
      note: note,
      colorHex: colorHex,
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.saveAnnotation(annotation);
    return annotation;
  }

  Future<void> deleteAnnotation(String annotationId) async {
    await _repository.deleteAnnotation(annotationId);
  }

  Future<List<Annotation>> getAnnotations(String publicationId) async {
    return _repository.getAnnotationsForPublication(publicationId);
  }

  Future<Bookmark> createBookmark({
    required String publicationId,
    required Locator locator,
    required String title,
  }) async {
    final bookmark = Bookmark(
      id: 'bm-${DateTime.now().millisecondsSinceEpoch}',
      publicationId: publicationId,
      locator: locator,
      title: title,
      createdAt: DateTime.now(),
    );

    await _repository.saveBookmark(bookmark);
    return bookmark;
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    await _repository.deleteBookmark(bookmarkId);
  }

  Future<List<Bookmark>> getBookmarks(String publicationId) async {
    return _repository.getBookmarksForPublication(publicationId);
  }
}
