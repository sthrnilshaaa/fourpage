import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Ids used to be "ann-<milliseconds>": two highlights made in the same
  // millisecond shared an id, so deleting one deleted both.
  test('annotations and bookmarks created back to back get unique ids', () async {
    final useCase = ManageAnnotationsUseCase(InMemoryAnnotationRepository());
    const locator = Locator(href: 'ch1.xhtml', type: 'application/xhtml+xml');
    final annotations = [
      for (var i = 0; i < 50; i++) await useCase.createAnnotation(publicationId: 'p', locator: locator),
    ];
    final bookmarks = [
      for (var i = 0; i < 50; i++) await useCase.createBookmark(publicationId: 'p', locator: locator, title: 't'),
    ];
    expect(annotations.map((a) => a.id).toSet(), hasLength(50));
    expect(bookmarks.map((b) => b.id).toSet(), hasLength(50));
  });
}
