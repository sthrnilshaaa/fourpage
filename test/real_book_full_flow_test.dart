import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real Book User Action & End-to-End Flow Tests', () {
    late Uint8List realBookArchiveBytes;

    setUp(() {
      final archive = Archive();

      // 1. mimetype (mandatory uncompressed as first file in standard EPUB)
      archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));

      // 2. META-INF/container.xml
      const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile.string('META-INF/container.xml', containerXml));

      // 3. EPUB/package.opf
      const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>The Great Gatsby</dc:title>
    <dc:creator>F. Scott Fitzgerald</dc:creator>
    <dc:publisher>Charles Scribner's Sons</dc:publisher>
    <dc:language>en</dc:language>
    <dc:identifier id="pub-id">urn:isbn:9780743273565</dc:identifier>
    <meta property="rendition:layout">reflowable</meta>
    <meta property="rendition:orientation">auto</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover-img" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>
    <item id="style" href="styles/style.css" media-type="text/css"/>
    <item id="ch1" href="chapters/chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapters/chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch3" href="chapters/chapter3.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
    <itemref idref="ch3"/>
  </spine>
</package>''';
      archive.addFile(ArchiveFile.string('EPUB/package.opf', opfXml));

      // 4. EPUB/nav.xhtml
      const navXml = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <head><title>Table of Contents</title></head>
  <body>
    <nav epub:type="toc">
      <h1>Table of Contents</h1>
      <ol>
        <li><a href="chapters/chapter1.xhtml">Chapter 1 - Nick Carraway and Gatsby</a></li>
        <li><a href="chapters/chapter2.xhtml">Chapter 2 - The Valley of Ashes</a></li>
        <li><a href="chapters/chapter3.xhtml">Chapter 3 - The Party at Gatsby's</a></li>
      </ol>
    </nav>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('EPUB/nav.xhtml', navXml));

      // 5. EPUB/styles/style.css
      archive.addFile(ArchiveFile.string('EPUB/styles/style.css', 'body { font-family: serif; font-size: 1em; line-height: 1.6; }'));

      // 6. Cover image placeholder
      archive.addFile(ArchiveFile('EPUB/images/cover.jpg', 4, [0xFF, 0xD8, 0xFF, 0xE0]));

      // 7. Chapter 1 XHTML
      const ch1Content = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter 1</title><link rel="stylesheet" type="text/css" href="../styles/style.css"/></head>
  <body>
    <h1 id="ch1-title">Chapter 1</h1>
    <p>In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.</p>
    <p>"Whenever you feel like criticizing any one," he told me, "just remember that all the people in this world haven't had the advantages that you've had."</p>
    <p>He didn't say any more, but we've always been unusually communicative in a reserved way, and I understood that he meant a great deal more than that.</p>
    <p>Gatsby turned out all right at the end; it is what preyed on Gatsby, what foul dust floated in the wake of his dreams that temporarily closed out my interest in the abortive sorrows and short-winded elations of men.</p>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('EPUB/chapters/chapter1.xhtml', ch1Content));

      // 8. Chapter 2 XHTML
      const ch2Content = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter 2</title><link rel="stylesheet" type="text/css" href="../styles/style.css"/></head>
  <body>
    <h1 id="ch2-title">Chapter 2</h1>
    <p>About half way between West Egg and New York the motorroad hastily joins the railroad and runs beside it for a quarter of a mile, so as to shrink away from a certain desolate area of land.</p>
    <p>This is a valley of ashes—a fantastic farm where ashes grow like wheat into ridges and hills and grotesque gardens; where ashes take the forms of houses and chimneys and rising smoke.</p>
    <p>The eyes of Doctor T. J. Eckleburg are blue and gigantic—their irises are one yard high. They look out of no face, but, instead, from a pair of enormous yellow spectacles.</p>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('EPUB/chapters/chapter2.xhtml', ch2Content));

      // 9. Chapter 3 XHTML
      const ch3Content = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter 3</title><link rel="stylesheet" type="text/css" href="../styles/style.css"/></head>
  <body>
    <h1 id="ch3-title">Chapter 3</h1>
    <p>There was music from my neighbor's house through the summer nights. In his blue gardens men and girls came and went like moths among the whisperings and the champagne and the stars.</p>
    <p>I believe that on the first night I went to Gatsby's house I was one of the few guests who had actually been invited. People were not invited—they went there.</p>
    <p>He smiled understandingly—much more than understandingly. It was one of those rare smiles with a quality of eternal reassurance in it.</p>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('EPUB/chapters/chapter3.xhtml', ch3Content));

      final encoder = ZipEncoder();
      realBookArchiveBytes = Uint8List.fromList(encoder.encode(archive)!);
    });

    test('Action 1: Import, validate, and parse a real-world EPUB book', () async {
      final validator = const EpubValidator();
      final source = MemoryBookSource(name: 'gatsby.epub', bytes: realBookArchiveBytes);

      final validation = await validator.validate(source);
      expect(validation.isValid, isTrue);

      final parser = EpubPublicationParser();
      final publication = await parser.parsePublication(realBookArchiveBytes);

      // Metadata verification
      expect(publication.metadata.title, equals('The Great Gatsby'));
      expect(publication.metadata.authors, contains('F. Scott Fitzgerald'));
      expect(publication.metadata.publisher, equals("Charles Scribner's Sons"));
      expect(publication.metadata.language, equals('en'));
      expect(publication.metadata.identifier, equals('urn:isbn:9780743273565'));

      // Cover detection
      expect(publication.coverResource, isNotNull);
      expect(publication.coverResource!.href, equals('EPUB/images/cover.jpg'));

      // Table of contents
      expect(publication.tableOfContents.items.length, equals(3));
      expect(publication.tableOfContents.items[0].title, equals('Chapter 1 - Nick Carraway and Gatsby'));
      expect(publication.tableOfContents.items[1].title, equals('Chapter 2 - The Valley of Ashes'));
      expect(publication.tableOfContents.items[2].title, equals("Chapter 3 - The Party at Gatsby's"));

      // Derived reading statistics
      expect(publication.derivedStatistics.chapterCount, equals(3));
      expect(publication.derivedStatistics.wordCount, greaterThan(150));
      expect(publication.derivedStatistics.estimatedReadingTimeMinutes, greaterThanOrEqualTo(1));
    });

    test('Action 2 & 3: Open publication session, page turn (next/previous) and TOC jump', () async {
      final session = ReadingSession();
      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: realBookArchiveBytes));

      expect(session.state.status, equals(ReaderStatus.ready));
      expect(session.state.publication, isNotNull);
      expect(session.state.currentSpineIndex, equals(0));
      expect(session.state.currentLocator?.href, equals('EPUB/chapters/chapter1.xhtml'));

      // User Action: Turn page forward (Next Chapter)
      await session.dispatchCommand(const NextPageCommand());
      expect(session.state.currentSpineIndex, equals(1));
      expect(session.state.currentLocator?.href, equals('EPUB/chapters/chapter2.xhtml'));
      expect(session.state.completionPercentage, greaterThan(30.0));

      // User Action: Turn page backward (Previous Chapter)
      await session.dispatchCommand(const PreviousPageCommand());
      expect(session.state.currentSpineIndex, equals(0));
      expect(session.state.currentLocator?.href, equals('EPUB/chapters/chapter1.xhtml'));

      // User Action: Jump via Table of Contents directly to Chapter 3
      final ch3Item = session.state.publication!.tableOfContents.items[2];
      await session.dispatchCommand(
        NavigateToLocatorCommand(
          Locator(href: ch3Item.href, title: ch3Item.title),
        ),
      );
      expect(session.state.currentSpineIndex, equals(2));
      expect(session.state.currentLocator?.href, equals('EPUB/chapters/chapter3.xhtml'));
      expect(session.state.completionPercentage, greaterThan(65.0));

      await session.close();
    });

    test('Action 4: Reading progress tracking, location saving, and session restoration', () async {
      final progressRepo = InMemoryReadingProgressRepository();
      final session1 = ReadingSession(progressRepository: progressRepo);

      await session1.dispatchCommand(OpenPublicationCommand(archiveBytes: realBookArchiveBytes));

      // User reads to Chapter 2 at 45% of chapter
      final targetLocator = Locator(
        href: 'EPUB/chapters/chapter2.xhtml',
        title: 'Chapter 2',
        locations: const LocationParameters(
          position: 2,
          progression: 0.45,
          totalProgression: 0.48,
        ),
      );

      await session1.dispatchCommand(NavigateToLocatorCommand(targetLocator));
      final pubId = session1.state.publication!.id;

      // Close session 1
      await session1.close();

      // Verify progress was saved in repository
      final savedProgress = await progressRepo.getProgress(pubId);
      expect(savedProgress, isNotNull);
      expect(savedProgress!.locator.href, equals('EPUB/chapters/chapter2.xhtml'));
      expect(savedProgress.locator.locations.progression, equals(0.45));

      // Re-open book in a new session (simulating app relaunch)
      final session2 = ReadingSession(progressRepository: progressRepo);
      await session2.dispatchCommand(OpenPublicationCommand(archiveBytes: realBookArchiveBytes));

      // Position should be automatically restored to saved location
      expect(session2.state.currentLocator?.href, equals('EPUB/chapters/chapter2.xhtml'));
      expect(session2.state.currentLocator?.locations.progression, equals(0.45));

      await session2.close();
    });

    test('Action 5 & 6: User highlights text and attaches written notes', () async {
      final annotationRepo = InMemoryAnnotationRepository();
      final session = ReadingSession(annotationRepository: annotationRepo);

      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: realBookArchiveBytes));

      // User Action: Highlight famous opening quote in Chapter 1 with yellow
      const quote1 = "In my younger and more vulnerable years my father gave me some advice";
      await session.dispatchCommand(
        CreateAnnotationCommand(
          locator: const Locator(href: 'EPUB/chapters/chapter1.xhtml'),
          textQuote: quote1,
          colorHex: '#FFEB3B',
          type: AnnotationType.highlight,
        ),
      );

      // User Action: Highlight and attach a note to Doctor Eckleburg's eyes in Chapter 2
      const quote2 = "The eyes of Doctor T. J. Eckleburg are blue and gigantic";
      const userNote = "The eyes represent a watchful commercialized god overlooking the wasteland.";
      await session.dispatchCommand(
        CreateAnnotationCommand(
          locator: const Locator(href: 'EPUB/chapters/chapter2.xhtml'),
          textQuote: quote2,
          note: userNote,
          colorHex: '#2196F3',
          type: AnnotationType.note,
        ),
      );

      // Verify annotations exist in state and repo
      expect(session.state.annotations.length, equals(2));

      final highlight = session.state.annotations.firstWhere((a) => a.type == AnnotationType.highlight);
      expect(highlight.textQuote, equals(quote1));
      expect(highlight.colorHex, equals('#FFEB3B'));

      final note = session.state.annotations.firstWhere((a) => a.type == AnnotationType.note);
      expect(note.textQuote, equals(quote2));
      expect(note.note, equals(userNote));
      expect(note.colorHex, equals('#2196F3'));

      // User Action: Delete the yellow highlight
      await session.dispatchCommand(DeleteAnnotationCommand(highlight.id));
      expect(session.state.annotations.length, equals(1));
      expect(session.state.annotations.first.note, equals(userNote));

      await session.close();
    });

    test('Action 7: User creates and deletes bookmarks', () async {
      final annotationRepo = InMemoryAnnotationRepository();
      final session = ReadingSession(annotationRepository: annotationRepo);

      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: realBookArchiveBytes));

      // User bookmarks a location in Chapter 2
      final loc = Locator(
        href: 'EPUB/chapters/chapter2.xhtml',
        title: 'Chapter 2',
        locations: const LocationParameters(position: 1, progression: 0.3),
      );

      await session.dispatchCommand(
        CreateBookmarkCommand(
          locator: loc,
          title: 'Valley of Ashes Entrance',
        ),
      );

      expect(session.state.bookmarks.length, equals(1));
      final bm = session.state.bookmarks.first;
      expect(bm.title, equals('Valley of Ashes Entrance'));
      expect(bm.locator.href, equals('EPUB/chapters/chapter2.xhtml'));

      // User deletes bookmark
      await session.dispatchCommand(DeleteBookmarkCommand(bm.id));
      expect(session.state.bookmarks.isEmpty, isTrue);

      await session.close();
    });

    test('Action 8: In-book full-text search across all chapters', () async {
      final session = ReadingSession();
      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: realBookArchiveBytes));

      // User searches for "Gatsby"
      await session.dispatchCommand(const ExecuteSearchCommand('Gatsby'));

      final results = session.state.searchResults;
      expect(results.isNotEmpty, isTrue);
      expect(results.length, greaterThanOrEqualTo(2));

      // Verify search matches contain context snippets
      for (final match in results) {
        expect(match.matchedText.toLowerCase(), equals('gatsby'));
        expect(match.locator.href, anyOf(contains('chapter1.xhtml'), contains('chapter3.xhtml')));
      }

      // Search for specific phrase
      await session.dispatchCommand(const ExecuteSearchCommand('ashes'));
      expect(session.state.searchResults.length, greaterThanOrEqualTo(3));
      for (final m in session.state.searchResults) {
        expect(m.locator.href, contains('chapter2.xhtml'));
      }

      await session.close();
    });

    test('Action 10: User updates typography, theme, and layout preferences per book', () async {
      final prefsRepo = InMemoryReaderPreferencesRepository();
      final session = ReadingSession(preferencesRepository: prefsRepo);

      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: realBookArchiveBytes));

      // User customizes reading experience:
      // - Switches to Sepia theme
      // - Sets font size to 19.0
      // - Sets font family to Bookerly
      // - Sets text alignment to justify
      // - Sets continuous vertical scroll mode
      const customPrefs = ReaderPreferences(
        theme: ReaderTheme.sepia,
        fontSize: 19.0,
        fontFamily: 'Bookerly',
        textAlignment: 'justify',
        scrollMode: ScrollMode.continuous,
        lineHeight: 1.8,
        marginHorizontal: 24.0,
      );

      await session.dispatchCommand(const UpdatePreferencesCommand(customPrefs));

      expect(session.state.preferences.theme, equals(ReaderTheme.sepia));
      expect(session.state.preferences.fontSize, equals(19.0));
      expect(session.state.preferences.fontFamily, equals('Bookerly'));
      expect(session.state.preferences.textAlignment, equals('justify'));
      expect(session.state.preferences.scrollMode, equals(ScrollMode.continuous));

      final pubId = session.state.publication!.id;
      final persistedPrefs = await prefsRepo.getPreferences(pubId);
      expect(persistedPrefs.theme, equals(ReaderTheme.sepia));
      expect(persistedPrefs.fontFamily, equals('Bookerly'));

      await session.close();
    });

    test('Action 11: Multi-Engine Compatibility Diagnostic Evaluation', () async {
      final harness = EpubCompatibilityHarness();
      final report = await harness.evaluatePublication(realBookArchiveBytes);

      expect(report.title, equals('The Great Gatsby'));
      expect(report.version, equals(EPUBVersion.epub3));
      expect(report.layout, equals(LayoutType.reflowable));
      expect(report.protection, equals(ProtectionType.unprotected));
      expect(report.engineScores.isNotEmpty, isTrue);
      expect(report.recommendedEngine, isNotEmpty);
    });

    test('Action 12: SQLite Database Persistence & Offline Sync Journaling', () async {
      final db = AppDatabase.instance;
      final pubRepo = SqlitePublicationRepository(db: db);
      final progressRepo = SqliteReadingProgressRepository(db: db);
      final prefRepo = SqliteReaderPreferencesRepository(db: db);

      final parser = EpubPublicationParser();
      final publication = await parser.parsePublication(realBookArchiveBytes);

      // Save publication in SQLite
      await pubRepo.savePublication(publication);

      final retrieved = await pubRepo.getPublicationById(publication.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.metadata.title, equals('The Great Gatsby'));
      expect(retrieved.metadata.authors, contains('F. Scott Fitzgerald'));

      // Save reading progress in SQLite
      final progress = ReadingProgress(
        publicationId: publication.id,
        locator: const Locator(href: 'EPUB/chapters/chapter2.xhtml'),
        percentage: 0.65,
        lastReadAt: DateTime.now(),
      );
      await progressRepo.saveProgress(progress);

      final savedProg = await progressRepo.getProgress(publication.id);
      expect(savedProg, isNotNull);
      expect(savedProg!.percentage, equals(0.65));

      // Save custom preferences in SQLite
      const prefs = ReaderPreferences(theme: ReaderTheme.dark, fontSize: 18.0);
      await prefRepo.savePreferences(publication.id, prefs);

      final savedPrefs = await prefRepo.getPreferences(publication.id);
      expect(savedPrefs.theme, equals(ReaderTheme.dark));
      expect(savedPrefs.fontSize, equals(18.0));

      // Verify Offline Sync Manager triggers and marks mutations synced
      final syncManager = OfflineSyncManager.instance;
      await syncManager.syncNow();
      expect(syncManager.currentStatus.pendingCount, equals(0));
      expect(syncManager.currentStatus.status, equals(SyncStateStatus.synced));

      // Clean up publication
      await pubRepo.deletePublication(publication.id);
      final deleted = await pubRepo.getPublicationById(publication.id);
      expect(deleted, isNull);
    });
  });
}
