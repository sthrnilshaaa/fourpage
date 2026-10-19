import 'dart:typed_data';
import 'package:aread/aread.dart';
import 'package:aread/src/presentation/utils/sample_epub_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookImporter, BookSource & EpubValidator Tests', () {
    late List<int> validEpubBytes;

    setUp(() {
      validEpubBytes = SampleEpubBuilder.buildEpubZip(
        title: 'Validation & Import Test Ebook',
        author: 'Author Name',
        chapterTexts: ['Chapter 1 content for validator pipeline test.'],
      );
    });

    test('BookSource variants operate correctly without physical filesystem requirements', () async {
      final memSource = MemoryBookSource(name: 'test.epub', bytes: validEpubBytes);
      expect(memSource.name, equals('test.epub'));
      expect(memSource.size, equals(validEpubBytes.length));

      final uriSource = AndroidUriBookSource(uri: 'content://com.android.providers.downloads.documents/document/12', bytes: Uint8List.fromList(validEpubBytes));
      expect(uriSource.name, equals('ebook.epub'));
      expect(uriSource.mimeType, equals('application/epub+zip'));
    });

    test('EpubValidator validates standard EPUB 3 container', () async {
      final validator = const EpubValidator();
      final source = MemoryBookSource(name: 'valid.epub', bytes: validEpubBytes);

      final result = await validator.validate(source);
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('EpubValidator catches invalid non-EPUB files with controlled error', () async {
      final validator = const EpubValidator();
      final corruptSource = MemoryBookSource(name: 'corrupt.txt', bytes: [1, 2, 3, 4, 5]);

      final result = await validator.validate(corruptSource);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('ZIP/OCF archive'));
    });

    test('BookImporter executes full import pipeline: BookSource -> Validation -> Parsing -> Domain Publication', () async {
      final repository = InMemoryPublicationRepository();
      final importer = BookImporter(repository: repository);
      final source = MemoryBookSource(name: 'import_test.epub', bytes: validEpubBytes);

      final result = await importer.importBook(source);
      expect(result.isSuccess, isTrue);
      expect(result.publication, isNotNull);
      expect(result.publication!.metadata.title, equals('Validation & Import Test Ebook'));

      final savedPub = await repository.getPublicationById(result.publication!.id);
      expect(savedPub, isNotNull);
    });
  });
}
