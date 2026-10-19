import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UpdateAnnotationCommand saves the new version and replaces it in state', () async {
    final repo = InMemoryAnnotationRepository();
    final session = ReadingSession(annotationRepository: repo);
    final now = DateTime(2026);
    final original = Annotation(
      id: 'a1',
      publicationId: 'p',
      locator: const Locator(href: 'epubcfi(/6/4!/4,/1:0,/1:5)'),
      textQuote: 'hello',
      colorHex: '#FFEB3B',
      type: AnnotationType.highlight,
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveAnnotation(original);
    final migrated = Annotation(
      id: 'a1',
      publicationId: 'p',
      locator: const Locator(
        href: 'OEBPS/ch1.html#aread:10',
        locations: LocationParameters(charOffset: 10, charEnd: 15, cfi: 'epubcfi(/6/4!/4,/1:0,/1:5)'),
      ),
      textQuote: 'hello',
      colorHex: '#4CAF50',
      type: AnnotationType.highlight,
      createdAt: now,
      updatedAt: now,
    );
    await session.dispatchCommand(UpdateAnnotationCommand(migrated));
    final saved = await repo.getAnnotationsForPublication('p');
    expect(saved.single.colorHex, '#4CAF50');
    expect(saved.single.locator.locations.charOffset, 10);
    expect(session.state.annotations.single.id, 'a1');
    expect(session.state.annotations.single.colorHex, '#4CAF50');
  });
}
