import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026);

  test('a removed bookmark comes back unchanged with RestoreBookmarkCommand', () async {
    final repo = InMemoryAnnotationRepository();
    final session = ReadingSession(annotationRepository: repo);
    final bookmark = Bookmark(
      id: 'b1',
      publicationId: 'p',
      locator: const Locator(href: 'ch1.html', locations: LocationParameters(charOffset: 120)),
      title: 'Bookmark at 42%',
      createdAt: now,
    );
    await session.dispatchCommand(RestoreBookmarkCommand(bookmark));
    await session.dispatchCommand(const DeleteBookmarkCommand('b1'));
    expect(session.state.bookmarks, isEmpty);
    expect(await repo.getBookmarksForPublication('p'), isEmpty);

    await session.dispatchCommand(RestoreBookmarkCommand(bookmark));
    expect(session.state.bookmarks.single.id, 'b1');
    expect(session.state.bookmarks.single.title, 'Bookmark at 42%');
    expect((await repo.getBookmarksForPublication('p')).single.locator.locations.charOffset, 120);

    // Restoring twice doesn't duplicate it.
    await session.dispatchCommand(RestoreBookmarkCommand(bookmark));
    expect(session.state.bookmarks, hasLength(1));
  });

  test('a removed highlight comes back with its note and colour', () async {
    final repo = InMemoryAnnotationRepository();
    final session = ReadingSession(annotationRepository: repo);
    final note = Annotation(
      id: 'a1',
      publicationId: 'p',
      locator: const Locator(href: 'ch1.html#aread:10', locations: LocationParameters(charOffset: 10, charEnd: 15)),
      textQuote: 'hello',
      note: 'remember this',
      colorHex: '#4CAF50',
      type: AnnotationType.note,
      createdAt: now,
      updatedAt: now,
    );
    await session.dispatchCommand(UpdateAnnotationCommand(note));
    await session.dispatchCommand(const DeleteAnnotationCommand('a1'));
    expect(session.state.annotations, isEmpty);

    await session.dispatchCommand(UpdateAnnotationCommand(note));
    final back = session.state.annotations.single;
    expect(back.note, 'remember this');
    expect(back.colorHex, '#4CAF50');
    expect((await repo.getAnnotationsForPublication('p')).single.id, 'a1');
  });
}
