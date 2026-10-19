import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aread/src/data/database/app_settings_repository.dart';
import 'package:aread/src/presentation/state/library_controller.dart';
import 'package:aread/src/presentation/utils/folder_scanner.dart';
import 'package:aread/src/presentation/utils/sample_epub_builder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('FolderScanner Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aread_folder_scan_test_');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('recursively finds .epub and .EPUB files while skipping hidden items', () async {
      // 1. Valid root EPUB
      final file1 = File('${tempDir.path}/book1.epub');
      await file1.writeAsString('fake epub content 1');

      // 2. Valid uppercase .EPUB
      final file2 = File('${tempDir.path}/book2.EPUB');
      await file2.writeAsString('fake epub content 2');

      // 3. Valid nested EPUB in subfolder
      final subDir = Directory('${tempDir.path}/subfolder');
      await subDir.create();
      final file3 = File('${subDir.path}/book3.epub');
      await file3.writeAsString('fake epub content 3');

      // 4. Hidden file (AppleDouble / dotfile) - should be skipped
      final hiddenFile = File('${tempDir.path}/._book.epub');
      await hiddenFile.writeAsString('hidden file');

      // 5. Hidden directory - should be skipped
      final hiddenDir = Directory('${tempDir.path}/.hidden_folder');
      await hiddenDir.create();
      final fileInHidden = File('${hiddenDir.path}/ignored.epub');
      await fileInHidden.writeAsString('ignored file');

      // 6. Non-epub file - should be skipped
      final textFile = File('${tempDir.path}/readme.txt');
      await textFile.writeAsString('plain text');

      final foundFiles = await FolderScanner.findEpubFiles(tempDir);
      final foundNames = foundFiles.map((f) => f.path.split(Platform.pathSeparator).last).toSet();

      expect(foundFiles.length, 3);
      expect(foundNames, containsAll(['book1.epub', 'book2.EPUB', 'book3.epub']));
      expect(foundNames, isNot(contains('._book.epub')));
      expect(foundNames, isNot(contains('ignored.epub')));
      expect(foundNames, isNot(contains('readme.txt')));
    });

    test('scanning non-existent directory returns empty list safely without crashing', () async {
      final nonExistent = Directory('${tempDir.path}/does_not_exist_abc123');
      final result = await FolderScanner.findEpubFiles(nonExistent);
      expect(result, isEmpty);
    });
  });

  group('AppSettingsRepository String Key-Value Tests', () {
    test('stores, retrieves, and removes string values in SQLite', () async {
      final repo = AppSettingsRepository();

      await repo.setString('test_folder_key', '/path/to/test/folder');
      final retrieved = await repo.getString('test_folder_key');
      expect(retrieved, '/path/to/test/folder');

      await repo.remove('test_folder_key');
      final afterRemove = await repo.getString('test_folder_key');
      expect(afterRemove, isNull);
    });
  });

  group('LibraryController Import Deduplication Tests', () {
    test('importing the same book repeatedly never creates duplicate entries in library', () async {
      final controller = LibraryController.instance;

      final zipBytes = SampleEpubBuilder.buildEpubZip(
        title: 'Deduplication Test Book',
        author: 'Test Author',
        chapterTexts: ['Chapter 1 content for deduplication test'],
      );

      // First import
      final item1 = await controller.addBookFromBytes(
        title: 'Deduplication Test Book',
        author: 'Test Author',
        zipBytes: zipBytes,
      );

      final pubId = item1.publication.id;
      final countAfterFirst = controller.books.where((b) => b.publication.id == pubId).length;
      expect(countAfterFirst, 1, reason: 'First import must have exactly 1 entry in books list');

      // Second import of the exact same book bytes
      final item2 = await controller.addBookFromBytes(
        title: 'Deduplication Test Book',
        author: 'Test Author',
        zipBytes: zipBytes,
      );

      expect(item2.publication.id, pubId);
      final countAfterSecond = controller.books.where((b) => b.publication.id == pubId).length;
      expect(countAfterSecond, 1, reason: 'Second import of same book must never produce double entries');
    });

    test('scanAndImportFolder imports books from directory and tracks folder path', () async {
      final controller = LibraryController.instance;
      final tempDir = await Directory.systemTemp.createTemp('aread_folder_import_test_');

      try {
        final zipBytes1 = SampleEpubBuilder.buildEpubZip(
          title: 'Scanned Folder Book 1',
          author: 'Folder Author',
          chapterTexts: ['Folder chapter 1'],
        );
        final zipBytes2 = SampleEpubBuilder.buildEpubZip(
          title: 'Scanned Folder Book 2',
          author: 'Folder Author',
          chapterTexts: ['Folder chapter 2'],
        );

        final bookFile1 = File('${tempDir.path}/scanned1.epub');
        await bookFile1.writeAsBytes(zipBytes1);
        final bookFile2 = File('${tempDir.path}/scanned2.epub');
        await bookFile2.writeAsBytes(zipBytes2);

        final importedCount = await controller.scanAndImportFolder(tempDir.path);
        expect(importedCount, 2);

        expect(controller.scannedFolders, contains(tempDir.path));

        final folderBooks = controller.books.where((b) => b.folderPath == tempDir.path).toList();
        expect(folderBooks.length, 2);
        for (final b in folderBooks) {
          expect(b.folderPath, tempDir.path);
        }

        // Rescanning the folder does not create duplicate entries
        final rescannedCount = await controller.scanAndImportFolder(tempDir.path);
        expect(rescannedCount, 2);

        final folderBooksAfterRescan = controller.books.where((b) => b.folderPath == tempDir.path).toList();
        expect(folderBooksAfterRescan.length, 2, reason: 'Rescanning folder must never create double entries');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
