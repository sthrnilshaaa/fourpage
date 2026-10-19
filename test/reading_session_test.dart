import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingSession & Commands Integration Tests', () {
    late List<int> zipBytes;

    setUp(() {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));
      archive.addFile(
        ArchiveFile.string(
          'META-INF/container.xml',
          '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
              '<rootfiles><rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        ),
      );
      archive.addFile(
        ArchiveFile.string(
          'OEBPS/package.opf',
          '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id1">'
              '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Integration Test Ebook</dc:title><dc:identifier id="id1">id1</dc:identifier></metadata>'
              '<manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/><item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/></manifest>'
              '<spine><itemref idref="ch1"/><itemref idref="ch2"/></spine></package>',
        ),
      );
      archive.addFile(ArchiveFile.string('OEBPS/ch1.xhtml', '<html><body><h1>Chapter 1</h1><p>Test content for chapter one.</p></body></html>'));
      archive.addFile(ArchiveFile.string('OEBPS/ch2.xhtml', '<html><body><h1>Chapter 2</h1><p>Second chapter content.</p></body></html>'));

      zipBytes = ZipEncoder().encode(archive)!;
    });

    test('ReadingSession lifecycle: open, navigate next/prev, add highlight/bookmark, search', () async {
      final session = ReadingSession();

      expect(session.state.status, equals(ReaderStatus.initial));

      // 1. Open publication
      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: zipBytes));
      expect(session.state.status, equals(ReaderStatus.ready));
      expect(session.state.publication?.metadata.title, equals('Integration Test Ebook'));
      expect(session.state.currentLocator?.href, equals('OEBPS/ch1.xhtml'));

      // 2. Next page command
      await session.dispatchCommand(const NextPageCommand());
      expect(session.state.currentLocator?.href, equals('OEBPS/ch2.xhtml'));
      expect(session.state.completionPercentage, equals(50.0));

      // 3. Previous page command
      await session.dispatchCommand(const PreviousPageCommand());
      expect(session.state.currentLocator?.href, equals('OEBPS/ch1.xhtml'));

      // 4. Create highlight annotation
      await session.dispatchCommand(
        CreateAnnotationCommand(
          locator: session.state.currentLocator!,
          textQuote: 'Test content for chapter one.',
          colorHex: '#FF5722',
        ),
      );
      expect(session.state.annotations.length, equals(1));
      expect(session.state.annotations.first.textQuote, equals('Test content for chapter one.'));

      // 5. Create bookmark
      await session.dispatchCommand(
        CreateBookmarkCommand(
          locator: session.state.currentLocator!,
          title: 'Bookmark 1',
        ),
      );
      expect(session.state.bookmarks.length, equals(1));
      expect(session.state.bookmarks.first.title, equals('Bookmark 1'));

      // 6. Search
      await session.dispatchCommand(const ExecuteSearchCommand('content'));
      expect(session.state.searchResults.length, equals(2));

      // 7. Preferences
      await session.dispatchCommand(
        const UpdatePreferencesCommand(
          ReaderPreferences(fontSize: 20.0, theme: ReaderTheme.sepia),
        ),
      );
      expect(session.state.preferences.fontSize, equals(20.0));
      expect(session.state.preferences.theme, equals(ReaderTheme.sepia));

      await session.close();
    });
  });
}
