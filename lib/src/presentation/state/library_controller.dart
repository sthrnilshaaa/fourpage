import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../aread.dart';
import '../../data/database/app_settings_repository.dart';
import '../../data/repositories/usage_repository.dart';
import '../../data/importers/document_converter.dart';
import '../../data/pdf/pdf_document.dart';
import '../utils/folder_scanner.dart';
import 'app_preferences.dart';
import 'shelves.dart';
import '../platform/epub_unpacker.dart';
import '../platform/folder_tree.dart';

enum BookFormat { epub, pdf }

class BookItem {
  final Publication publication;
  final BookFormat kind;
  final Color coverGradientStart;
  final Color coverGradientEnd;
  final ReadingSession session;

  /// Whole EPUB in memory (the epubx engine renders from it). Empty for PDF.
  final List<int> archiveBytes;
  final String? folderPath;

  /// Last read PDF page (0-based) and fraction, persisted as reading
  /// progress. EPUB progress lives in [session].
  int pdfPage;
  double pdfProgress;

  BookItem({
    required this.publication,
    this.kind = BookFormat.epub,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    required this.session,
    required this.archiveBytes,
    this.folderPath,
    this.pdfPage = 0,
    this.pdfProgress = 0,
  });

  bool get isPdf => kind == BookFormat.pdf;

  /// Label for format badges.
  String get format => isPdf ? 'PDF' : 'EPUB';

  /// Reading progress 0..1, for every list, sort and cover in the app.
  double get progress =>
      isPdf ? pdfProgress.clamp(0.0, 1.0) : (session.state.completionPercentage / 100).clamp(0.0, 1.0);
}

class LibraryController extends ChangeNotifier {
  static final LibraryController instance = LibraryController._internal();
  LibraryController._internal() {
    _initDatabaseAndLoad();
  }

  static const _coverStart = Color(0xFF1E3A8A);
  static const _coverEnd = Color(0xFF0284C7);

  final IPublicationRepository _repository = SqlitePublicationRepository();
  final IReadingProgressRepository _progressRepository = SqliteReadingProgressRepository();
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  final List<BookItem> _books = [];
  final Set<String> _importingPubIds = <String>{};
  final Set<String> _scannedFolders = <String>{};
  final Map<String, String> _bookFolderMap = <String, String>{};
  bool _isInitialized = false;

  // When each book was last opened (publication id -> time).
  final Map<String, DateTime> _lastOpened = {};
  static const _keyLastOpened = 'last_opened';

  // User-made shelves (see shelves.dart).
  ShelfCollection _shelves = ShelfCollection();
  static const _keyShelves = 'shelves';

  List<BookItem> get books => List.unmodifiable(_books);

  /// Books that have been opened, most recently opened first.
  List<BookItem> get recentBooks {
    final opened = _books.where((b) => _lastOpened.containsKey(b.publication.id)).toList()
      ..sort((a, b) => _lastOpened[b.publication.id]!.compareTo(_lastOpened[a.publication.id]!));
    return opened;
  }

  /// Records that [book] was just opened, so it moves to the front of
  /// Recent Reading.
  void markOpened(BookItem book) {
    _lastOpened[book.publication.id] = DateTime.now();
    notifyListeners();
    _settingsRepo
        .setString(
          _keyLastOpened,
          jsonEncode(_lastOpened.map((k, v) => MapEntry(k, v.toIso8601String()))),
        )
        .catchError((Object e) => debugPrint('Could not save last opened: $e'));
  }

  // --- shelves -----------------------------------------------------------------

  List<Shelf> get shelves => _shelves.shelves;

  /// The shelf [book] is on, or null when it's unshelved.
  Shelf? shelfOf(BookItem book) => _shelves.shelfOf(book.publication.id);

  /// Books on [shelf], in the order they were added (books no longer in the
  /// library are skipped).
  List<BookItem> booksOnShelf(Shelf shelf) {
    final byId = {for (final b in _books) b.publication.id: b};
    return [for (final id in shelf.bookIds) ?byId[id]];
  }

  /// Books on no shelf.
  List<BookItem> get unshelvedBooks => _books.where((b) => _shelves.shelfOf(b.publication.id) == null).toList();

  bool shelfNameTaken(String name, {String? exceptId}) => _shelves.nameTaken(name, exceptId: exceptId);

  Shelf createShelf(String name) {
    final shelf = _shelves.create(name, id: DateTime.now().microsecondsSinceEpoch.toRadixString(36));
    _shelvesChanged();
    return shelf;
  }

  void renameShelf(Shelf shelf, String name) {
    _shelves.rename(shelf.id, name);
    _shelvesChanged();
  }

  /// Deletes the shelf only; its books stay in the library, unshelved.
  void deleteShelf(Shelf shelf) {
    _shelves.delete(shelf.id);
    _shelvesChanged();
  }

  void reorderShelf(int oldIndex, int newIndex) {
    _shelves.reorder(oldIndex, newIndex);
    _shelvesChanged();
  }

  /// Puts [book] on [shelf], or takes it off its shelf when [shelf] is null.
  void moveBookToShelf(BookItem book, Shelf? shelf) {
    _shelves.moveBook(book.publication.id, shelf?.id);
    _shelvesChanged();
  }

  void _shelvesChanged() {
    notifyListeners();
    _settingsRepo
        .setString(_keyShelves, _shelves.encode())
        .catchError((Object e) => debugPrint('Could not save shelves: $e'));
  }

  /// Called when a reader closes: progress shown in lists is read from the
  /// book's session, which doesn't notify the library by itself.
  void readerClosed() => notifyListeners();

  Future<void> _loadLastOpened() async {
    try {
      final json = await _settingsRepo.getString(_keyLastOpened);
      if (json != null && json.isNotEmpty) {
        (jsonDecode(json) as Map).forEach((k, v) {
          final t = DateTime.tryParse(v as String);
          if (t != null) _lastOpened[k as String] = t;
        });
      } else {
        // First run with this feature: seed from recorded reading sessions.
        final usage = await UsageRepository().summary();
        for (final b in usage.books) {
          _lastOpened[b.publicationId] = b.lastReadAt;
        }
      }
    } catch (e) {
      debugPrint('Error restoring last opened: $e');
    }
  }
  bool get isInitialized => _isInitialized;
  List<String> get scannedFolders => List.unmodifiable(_scannedFolders.toList());

  String? getFolderForBook(String pubId) => _bookFolderMap[pubId];

  BookItem? _activeBook;
  BookItem? get activeBook => _activeBook;

  // --- files -------------------------------------------------------------------

  Future<Directory> _booksDir() async {
    Directory dir;
    if (kIsWeb) {
      dir = Directory.current;
    } else {
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        // Headless tests: keep book files out of the project, per process.
        dir = Directory('${Directory.systemTemp.path}/fourpages_test_$pid');
      }
    }
    final booksDir = Directory('${dir.path}/app_books');
    if (!booksDir.existsSync()) booksDir.createSync(recursive: true);
    return booksDir;
  }

  /// Where a book's file is stored: `app_books/<id>.epub` or `<id>.pdf`.
  Future<File> getBookFile(String pubId, {BookFormat kind = BookFormat.epub}) async =>
      File('${(await _booksDir()).path}/$pubId.${kind == BookFormat.pdf ? 'pdf' : 'epub'}');

  /// Like [getBookFile], but guarantees the file exists, writing
  /// [archiveBytes] if it doesn't - engines that open a path (sakura_epub's
  /// EpubSource.fromFile) otherwise hang on a missing file.
  Future<File> ensureBookFileOnDisk(String pubId, List<int> archiveBytes) async {
    final file = await getBookFile(pubId);
    if (!await file.exists()) await file.writeAsBytes(archiveBytes);
    return file;
  }

  /// A session persisting to SQLite; new books start from the user's
  /// reading defaults (Settings) until they get their own preferences.
  ReadingSession _newSession() => ReadingSession(
        annotationRepository: SqliteAnnotationRepository(),
        progressRepository: SqliteReadingProgressRepository(),
        preferencesRepository: SqliteReaderPreferencesRepository(
          defaults: () => AppPreferences.instance.readerDefaults,
        ),
      );

  // --- loading -----------------------------------------------------------------

  Future<void> _initDatabaseAndLoad() async {
    if (_isInitialized) return;
    await AppPreferences.instance.load();

    try {
      final foldersJson = await _settingsRepo.getString('scanned_folders');
      if (foldersJson != null && foldersJson.isNotEmpty) {
        _scannedFolders.addAll(List<String>.from(jsonDecode(foldersJson) as List));
      }
      final mapJson = await _settingsRepo.getString('book_folder_map');
      if (mapJson != null && mapJson.isNotEmpty) {
        _bookFolderMap.addAll(Map<String, String>.from(jsonDecode(mapJson) as Map));
      }
    } catch (e) {
      debugPrint('Error restoring folder settings: $e');
    }

    await _loadLastOpened();
    try {
      _shelves = ShelfCollection.decode(await _settingsRepo.getString(_keyShelves));
    } catch (e) {
      debugPrint('Error restoring shelves: $e');
    }
    for (final pub in await _repository.getAllPublications()) {
      await _restore(pub);
    }
    _dedupe();
    _isInitialized = true;

    // Pick up publications written elsewhere (e.g. another import path).
    AppDatabase.instance.changeStream.listen((tableName) {
      if (tableName == 'publications') _reloadFromDatabase();
    });
    notifyListeners();
  }

  Future<void> _reloadFromDatabase() async {
    final pubs = await _repository.getAllPublications();
    _books.removeWhere((b) => !pubs.any((p) => p.id == b.publication.id));
    for (final pub in pubs) {
      if (!_importingPubIds.contains(pub.id)) await _restore(pub);
    }
    _dedupe();
    notifyListeners();
  }

  /// Rebuilds the library entry for a stored publication from its file.
  /// A book whose file is gone is skipped (it can't be read) rather than
  /// shown with made-up content.
  Future<void> _restore(Publication pub) async {
    if (_books.any((b) => b.publication.id == pub.id)) return;
    try {
      final pdf = await getBookFile(pub.id, kind: BookFormat.pdf);
      if (await pdf.exists()) {
        _books.add(await _pdfItem(pub, folderPath: _bookFolderMap[pub.id]));
        return;
      }
      final epub = await getBookFile(pub.id);
      if (!await epub.exists()) {
        debugPrint('Skipping ${pub.id}: its book file is missing');
        return;
      }
      final bytes = await epub.readAsBytes();
      final session = _newSession();
      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: bytes));
      _books.add(BookItem(
        publication: pub,
        coverGradientStart: _coverStart,
        coverGradientEnd: _coverEnd,
        session: session,
        archiveBytes: bytes,
        folderPath: _bookFolderMap[pub.id],
      ));
    } catch (e) {
      debugPrint('Error restoring publication ${pub.id}: $e');
    }
  }

  Future<BookItem> _pdfItem(Publication pub, {String? folderPath}) async {
    final saved = await _progressRepository.getProgress(pub.id);
    return BookItem(
      publication: pub,
      kind: BookFormat.pdf,
      coverGradientStart: const Color(0xFF7F1D1D),
      coverGradientEnd: const Color(0xFFB91C1C),
      session: _newSession(),
      archiveBytes: const [],
      folderPath: folderPath,
      pdfPage: saved?.locator.locations.position ?? 0,
      pdfProgress: (saved?.percentage ?? 0) / 100,
    );
  }

  void _dedupe() {
    final seen = <String>{};
    _books.retainWhere((b) => seen.add(b.publication.id));
  }

  void _upsert(BookItem item) {
    final index = _books.indexWhere((b) => b.publication.id == item.publication.id);
    if (index >= 0) {
      _books[index] = item;
    } else {
      _books.insert(0, item);
    }
    _dedupe();
    notifyListeners();
  }

  void _rememberFolder(String id, String? folderPath) {
    if (folderPath == null || folderPath.isEmpty) return;
    _bookFolderMap[id] = folderPath;
    _scannedFolders.add(folderPath);
    _persistFolderData();
  }

  // --- importing ----------------------------------------------------------------

  /// Imports any supported document (see DocumentConverter): EPUB and PDF as
  /// they are, TXT/Markdown/HTML/DOCX converted to EPUB. Throws
  /// [UnsupportedDocumentException] for formats it can't read, including PDF
  /// on platforms without a PDF renderer.
  Future<BookItem> addDocument({required String fileName, required List<int> bytes, String? folderPath}) async =>
      (await importDocument(fileName: fileName, bytes: bytes, folderPath: folderPath)).item;

  /// Like [addDocument], and says whether the book was new ([added] is false
  /// when it was already in the library; that entry is returned unchanged,
  /// so its open reader, shelf and progress aren't disturbed).
  Future<({BookItem item, bool added})> importDocument({
    required String fileName,
    required List<int> bytes,
    String? folderPath,
  }) async {
    final doc = DocumentConverter.convert(fileName, bytes);
    if (doc.kind == DocumentKind.pdf) {
      if (!isPdfSupportedPlatform) {
        throw UnsupportedDocumentException(fileName, UnsupportedReason.pdfNotSupported);
      }
      return _addPdf(fileName, doc.bytes, folderPath: folderPath);
    }
    return _addEpub(doc.bytes, folderPath: folderPath);
  }

  /// The library entry with [id], or null.
  BookItem? bookById(String id) {
    for (final b in _books) {
      if (b.publication.id == id) return b;
    }
    return null;
  }

  /// Already in the library: only record the folder it was found in.
  ({BookItem item, bool added}) _existing(BookItem item, String? folderPath) {
    if (folderPath != null && folderPath.isNotEmpty && item.folderPath == null) {
      _rememberFolder(item.publication.id, folderPath);
    }
    return (item: item, added: false);
  }

  Future<({BookItem item, bool added})> _addPdf(String fileName, List<int> bytes, {String? folderPath}) async {
    final hash = HashUtils.sha256Bytes(bytes);
    final pub = Publication(
      id: hash.substring(0, 16),
      fingerprint: hash,
      metadata: PublicationMetadata(
        title: DocumentConverter.titleFromFileName(fileName),
        identifier: 'pdf:$hash',
      ),
      packagePath: '',
    );
    final known = bookById(pub.id);
    if (known != null) return _existing(known, folderPath);
    _importingPubIds.add(pub.id);
    try {
      await (await getBookFile(pub.id, kind: BookFormat.pdf)).writeAsBytes(bytes);
      await _repository.savePublication(pub);
      _rememberFolder(pub.id, folderPath);
      final item = await _pdfItem(pub, folderPath: folderPath ?? _bookFolderMap[pub.id]);
      _upsert(item);
      return (item: item, added: true);
    } finally {
      _importingPubIds.remove(pub.id);
    }
  }

  /// Adds an EPUB to the database and library, keeping a copy on disk.
  /// [title]/[author] are ignored - metadata comes from the book itself.
  Future<BookItem> addBookFromBytes({
    required String title,
    required String author,
    required List<int> zipBytes,
    Color startColor = const Color(0xFF0F766E),
    Color endColor = const Color(0xFF14B8A6),
    String? folderPath,
  }) async =>
      (await _addEpub(zipBytes, startColor: startColor, endColor: endColor, folderPath: folderPath)).item;

  Future<({BookItem item, bool added})> _addEpub(
    List<int> zipBytes, {
    Color startColor = const Color(0xFF0F766E),
    Color endColor = const Color(0xFF14B8A6),
    String? folderPath,
  }) async {
    final pub = await EpubPublicationParser().parsePublication(zipBytes);
    final known = bookById(pub.id);
    if (known != null) return _existing(known, folderPath);
    _importingPubIds.add(pub.id);
    try {
      await _repository.savePublication(pub);
      try {
        await (await getBookFile(pub.id)).writeAsBytes(zipBytes);
      } catch (e) {
        debugPrint('Warning: Failed to persist EPUB archive file to disk: $e');
      }
      _rememberFolder(pub.id, folderPath);

      final session = _newSession();
      await session.dispatchCommand(OpenPublicationCommand(archiveBytes: zipBytes));
      final item = BookItem(
        publication: pub,
        coverGradientStart: startColor,
        coverGradientEnd: endColor,
        session: session,
        archiveBytes: zipBytes,
        folderPath: folderPath ?? _bookFolderMap[pub.id],
      );
      _upsert(item);
      OfflineSyncManager.instance.syncNow();
      return (item: item, added: true);
    } finally {
      _importingPubIds.remove(pub.id);
    }
  }

  /// File extensions folder scans and the file picker accept here.
  static List<String> get importableExtensions =>
      DocumentConverter.supportedExtensions.where((e) => e != 'pdf' || isPdfSupportedPlatform).toList();

  /// Scans a folder recursively for supported documents and imports them.
  /// Returns how many books were new. A second call for a folder that is
  /// still being scanned joins that scan instead of starting another.
  Future<int> scanAndImportFolder(String folderPath, {Function(int current, int total)? onProgress}) {
    final running = _scans[folderPath];
    if (running != null) return running;
    final scan = _scan(folderPath, onProgress: onProgress);
    _scans[folderPath] = scan;
    scan.whenComplete(() => _scans.remove(folderPath)).ignore();
    notifyListeners();
    return scan.whenComplete(notifyListeners);
  }

  final Map<String, Future<int>> _scans = {};

  /// True while [folderPath] is being scanned.
  bool isScanning(String folderPath) => _scans.containsKey(folderPath);

  Future<int> _scan(String folderPath, {Function(int current, int total)? onProgress}) async {
    if (FolderTree.isTreeUri(folderPath)) return _scanAndImportTree(folderPath, onProgress: onProgress);
    final files = await FolderScanner.findFiles(Directory(folderPath), importableExtensions);
    _scannedFolders.add(folderPath);
    await _persistFolderData();

    var importedCount = 0;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final r = await importDocument(
            fileName: file.path.split(Platform.pathSeparator).last,
            bytes: bytes,
            folderPath: folderPath,
          );
          if (r.added) importedCount++;
        }
      } catch (e) {
        debugPrint('Error importing ${file.path}: $e');
      }
      onProgress?.call(i + 1, files.length);
    }
    notifyListeners();
    return importedCount;
  }

  /// Play build: a folder picked with the system folder picker (tree URI).
  Future<int> _scanAndImportTree(String treeUri, {Function(int current, int total)? onProgress}) async {
    if (!await FolderTree.hasAccess(treeUri)) {
      throw FolderScanPermissionException(FolderTree.displayPath(treeUri));
    }
    final files = await FolderTree.list(treeUri, importableExtensions);
    _scannedFolders.add(treeUri);
    await _persistFolderData();

    var importedCount = 0;
    for (var i = 0; i < files.length; i++) {
      try {
        final bytes = await FolderTree.read(files[i].uri);
        if (bytes.isNotEmpty) {
          final r = await importDocument(fileName: files[i].name, bytes: bytes, folderPath: treeUri);
          if (r.added) importedCount++;
        }
      } catch (e) {
        debugPrint('Error importing ${files[i].name}: $e');
      }
      onProgress?.call(i + 1, files.length);
    }
    notifyListeners();
    return importedCount;
  }

  Future<void> _persistFolderData() async {
    try {
      await _settingsRepo.setString('scanned_folders', jsonEncode(_scannedFolders.toList()));
      await _settingsRepo.setString('book_folder_map', jsonEncode(_bookFolderMap));
    } catch (e) {
      debugPrint('Error persisting folder data: $e');
    }
  }

  // --- reading state -------------------------------------------------------------

  /// Saves the PDF page being read (0-based) so the book reopens there.
  Future<void> savePdfPage(BookItem book, int page, int pageCount) async {
    if (!book.isPdf || pageCount <= 0) return;
    book.pdfPage = page;
    book.pdfProgress = pageCount <= 1 ? 1 : page / (pageCount - 1);
    await _progressRepository.saveProgress(ReadingProgress(
      publicationId: book.publication.id,
      locator: Locator(
        href: 'page:${page + 1}',
        type: 'application/pdf',
        locations: LocationParameters(position: page, totalProgression: book.pdfProgress),
      ),
      percentage: book.pdfProgress * 100,
      lastReadAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void setActiveBook(BookItem book) {
    _activeBook = book;
    notifyListeners();
  }

  /// Stops tracking a scanned folder. Its books stay in the library (they
  /// were copied into app storage on import); they just lose the folder tag.
  Future<void> removeScannedFolder(String folderPath) async {
    _scannedFolders.remove(folderPath);
    if (FolderTree.isTreeUri(folderPath)) {
      await FolderTree.release(folderPath).catchError((Object e) => debugPrint('Release folder: $e'));
    }
    _bookFolderMap.removeWhere((_, folder) => folder == folderPath);
    await _persistFolderData();
    notifyListeners();
  }

  /// Applies [prefs] to every book now in the library (Settings → "Apply to
  /// all books"); books keep per-book overrides made afterwards.
  Future<void> applyPreferencesToAllBooks(ReaderPreferences prefs) async {
    for (final book in _books) {
      await book.session.dispatchCommand(UpdatePreferencesCommand(prefs));
    }
    notifyListeners();
  }

  /// Settings → Reset library: every book, its file and everything recorded
  /// about it is removed. App settings are kept.
  Future<void> resetLibrary() async {
    for (final b in _books) {
      await EpubUnpacker.remove(b.publication.id);
    }
    _lastOpened.clear();
    _books.clear();
    _scannedFolders.clear();
    _bookFolderMap.clear();
    _shelves.clear();
    _activeBook = null;
    await AppDatabase.instance.clearLibraryData();
    try {
      final dir = await _booksDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('Reset: could not delete book files: $e');
    }
    notifyListeners();
  }

  /// Removes a book from the library: its file, cached data, progress,
  /// highlights and bookmarks. The original file the user imported from is
  /// not touched.
  Future<void> deleteBook(String publicationId) async {
    await _repository.deletePublication(publicationId);
    await AppDatabase.instance.clearBookData(publicationId).catchError((Object e) => debugPrint('Delete book data: $e'));
    await EpubUnpacker.remove(publicationId);
    _books.removeWhere((b) => b.publication.id == publicationId);
    _bookFolderMap.remove(publicationId);
    _persistFolderData();
    _shelves.forgetBook(publicationId);
    _shelvesChanged();
    if (_lastOpened.remove(publicationId) != null) {
      _settingsRepo
          .setString(_keyLastOpened, jsonEncode(_lastOpened.map((k, v) => MapEntry(k, v.toIso8601String()))))
          .catchError((Object e) => debugPrint('Could not save last opened: $e'));
    }
    if (_activeBook?.publication.id == publicationId) _activeBook = null;
    // The book file and everything cached beside it (`<id>.epub`,
    // `<id>.epub.locations.json`, saved page pictures, ...).
    try {
      final dir = await _booksDir();
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
        if (name.startsWith('$publicationId.')) await entity.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Delete book files: $e');
    }
    notifyListeners();
    OfflineSyncManager.instance.syncNow();
  }
}
