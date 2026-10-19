import 'package:aread/aread.dart';
import 'package:aread/src/presentation/utils/sample_epub_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Both reader engines report positions as EPUB CFIs, not spine hrefs. The
  // restoration strategy used to fall through to "start of book" for those,
  // so every saved position became chapter 1 at 0%.
  test('a CFI position is saved as-is, with its progress', () async {
    final progressRepo = InMemoryReadingProgressRepository();
    final session = ReadingSession(progressRepository: progressRepo);
    final bytes = SampleEpubBuilder.buildEpubZip(title: 'P', author: 'A', chapterTexts: ['one', 'two', 'three']);
    await session.dispatchCommand(OpenPublicationCommand(archiveBytes: bytes));

    const cfi = 'epubcfi(/6/6!/4/2/1:0)';
    await session.dispatchCommand(const NavigateToLocatorCommand(
      Locator(href: cfi, locations: LocationParameters(progression: 0.66, totalProgression: 0.66, cfi: cfi)),
    ));

    final saved = await progressRepo.getProgress(session.state.publication!.id);
    expect(saved!.locator.locations.cfi, cfi);
    expect(saved.percentage, closeTo(66, 0.001));
    expect(session.state.completionPercentage, closeTo(66, 0.001));

    // Reopening (app restart) keeps it too, rather than resetting to start.
    final reopened = ReadingSession(progressRepository: progressRepo);
    await reopened.dispatchCommand(OpenPublicationCommand(archiveBytes: bytes));
    expect(reopened.state.currentLocator?.locations.cfi, cfi);
    expect(reopened.state.completionPercentage, closeTo(66, 0.001));
  });

  test('a CFI given only as href is recognised too', () async {
    final progressRepo = InMemoryReadingProgressRepository();
    final session = ReadingSession(progressRepository: progressRepo);
    final bytes = SampleEpubBuilder.buildEpubZip(title: 'Q', author: 'A', chapterTexts: ['one', 'two']);
    await session.dispatchCommand(OpenPublicationCommand(archiveBytes: bytes));

    await session.dispatchCommand(const NavigateToLocatorCommand(
      Locator(href: 'epubcfi(/6/4!/4/2)', locations: LocationParameters(totalProgression: 0.4)),
    ));
    final saved = await progressRepo.getProgress(session.state.publication!.id);
    expect(saved!.locator.href, 'epubcfi(/6/4!/4/2)');
    expect(saved.percentage, closeTo(40, 0.001));
  });
}
