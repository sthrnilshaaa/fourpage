import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite Database & Offline Sync Tests', () {
    late AppDatabase db;
    late SqlitePublicationRepository pubRepo;
    late SqliteAnnotationRepository annRepo;
    late SqliteReadingProgressRepository progressRepo;
    late SqliteReaderPreferencesRepository prefsRepo;

    setUp(() async {
      db = AppDatabase.instance;
      pubRepo = SqlitePublicationRepository(db: db);
      annRepo = SqliteAnnotationRepository(db: db);
      progressRepo = SqliteReadingProgressRepository(db: db);
      prefsRepo = SqliteReaderPreferencesRepository(db: db);
    });

    test('saves and retrieves publication from SQLite database', () async {
      const pub = Publication(
        id: 'pub-test-1',
        fingerprint: 'fp-12345',
        metadata: PublicationMetadata(
          title: 'Database Test Book',
          identifier: 'id-test-1',
          authors: ['Test Author'],
        ),
        resources: [ManifestResource(href: 'ch1.xhtml', mediaType: 'application/xhtml+xml')],
        spine: [SpineItem(idref: 'ch1', href: 'ch1.xhtml', mediaType: 'application/xhtml+xml', index: 0)],
        tableOfContents: TableOfContents(items: [NavItem(title: 'Chapter 1', href: 'ch1.xhtml')]),
        packagePath: 'EPUB/package.opf',
      );

      await pubRepo.savePublication(pub);

      final fetched = await pubRepo.getPublicationById('pub-test-1');
      expect(fetched, isNotNull);
      expect(fetched!.metadata.title, equals('Database Test Book'));
      expect(fetched.metadata.authors.first, equals('Test Author'));
    });

    test('saves and retrieves annotation and bookmark from SQLite database', () async {
      const locator = Locator(href: 'ch1.xhtml', locations: LocationParameters(position: 0, progression: 0.5));

      final annotation = Annotation(
        id: 'ann-1',
        publicationId: 'pub-test-1',
        locator: locator,
        textQuote: 'Important text in book',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await annRepo.saveAnnotation(annotation);

      final fetchedAnn = await annRepo.getAnnotationsForPublication('pub-test-1');
      expect(fetchedAnn.length, equals(1));
      expect(fetchedAnn.first.textQuote, equals('Important text in book'));

      final bookmark = Bookmark(
        id: 'bm-1',
        publicationId: 'pub-test-1',
        locator: locator,
        title: 'Chapter 1 Bookmark',
        createdAt: DateTime.now(),
      );

      await annRepo.saveBookmark(bookmark);

      final fetchedBm = await annRepo.getBookmarksForPublication('pub-test-1');
      expect(fetchedBm.length, equals(1));
      expect(fetchedBm.first.title, equals('Chapter 1 Bookmark'));
    });

    test('saves and updates reading progress in SQLite database', () async {
      const locator = Locator(href: 'ch1.xhtml', locations: LocationParameters(position: 0, progression: 0.75));

      final progress = ReadingProgress(
        publicationId: 'pub-test-1',
        locator: locator,
        percentage: 75.0,
        lastReadAt: DateTime.now(),
      );

      await progressRepo.saveProgress(progress);

      final fetched = await progressRepo.getProgress('pub-test-1');
      expect(fetched, isNotNull);
      expect(fetched!.percentage, equals(75.0));
    });

    test('saves and retrieves reader preferences per publication in SQLite database', () async {
      const prefsA = ReaderPreferences(
        fontSize: 22.0,
        theme: ReaderTheme.sepia,
        fontFamily: 'Merriweather',
      );
      const prefsB = ReaderPreferences(fontSize: 14.0, theme: ReaderTheme.light);

      await prefsRepo.savePreferences('pub-test-1', prefsA);
      await prefsRepo.savePreferences('pub-test-2', prefsB);

      final fetchedA = await prefsRepo.getPreferences('pub-test-1');
      expect(fetchedA.fontSize, equals(22.0));
      expect(fetchedA.theme, equals(ReaderTheme.sepia));
      expect(fetchedA.fontFamily, equals('Merriweather'));

      // Each publication keeps its own preferences, independent of the others.
      final fetchedB = await prefsRepo.getPreferences('pub-test-2');
      expect(fetchedB.fontSize, equals(14.0));
      expect(fetchedB.theme, equals(ReaderTheme.light));

      // A book that never had preferences saved falls back to defaults.
      final fetchedUnknown = await prefsRepo.getPreferences('never-opened-book');
      expect(fetchedUnknown.fontSize, equals(const ReaderPreferences().fontSize));
    });

    test('records mutations in sync_journal and marks synced', () async {
      final journal = SyncJournalManager(db);
      final pending = await journal.getPendingMutations();

      expect(pending, isNotEmpty);
      final ids = pending.map((e) => e.id).toList();
      await journal.markSynced(ids);

      final remaining = await journal.getPendingMutations();
      expect(remaining, isEmpty);
    });
  });
}
