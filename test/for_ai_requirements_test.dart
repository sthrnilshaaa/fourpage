import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('for_ai.md Exhaustive EPUB Extraction & Local File Model Tests', () {
    late Uint8List sampleEpubBytes;

    setUp(() {
      final archive = Archive();

      // mimetype
      archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));

      // META-INF/container.xml
      const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile.string('META-INF/container.xml', containerXml));

      // OEBPS/content.opf
      const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Complete Local EPUB Test</dc:title>
    <dc:creator opf:role="aut" opf:file-as="Doe, John">John Doe</dc:creator>
    <dc:contributor opf:role="trl">Jane Smith</dc:contributor>
    <dc:publisher>Antigravity Publishing</dc:publisher>
    <dc:language>en</dc:language>
    <dc:identifier id="pub-id">urn:uuid:9999-8888-7777-6666</dc:identifier>
    <dc:description>An exhaustive EPUB test for local file support.</dc:description>
    <meta property="belongs-to-collection">Master Ebook Series</meta>
    <meta property="schema:accessibilityFeature">structuralNavigation</meta>
    <meta property="schema:accessibilityFeature">alternativeText</meta>
    <meta property="rendition:layout">reflowable</meta>
    <meta property="rendition:orientation">portrait</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
    <item id="cover" href="cover.jpg" media-type="image/jpeg" properties="cover-image"/>
    <item id="font" href="font.ttf" media-type="font/ttf"/>
  </manifest>
  <spine page-progression-direction="ltr" toc="ncx">
    <itemref idref="nav"/>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''';
      archive.addFile(ArchiveFile.string('OEBPS/content.opf', opfXml));

      // OEBPS/nav.xhtml
      const navXml = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <h1>Table of Contents</h1>
      <ol>
        <li><a href="chapter1.xhtml">Chapter One: Beginning</a></li>
        <li><a href="chapter2.xhtml">Chapter Two: Continuation</a></li>
      </ol>
    </nav>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('OEBPS/nav.xhtml', navXml));

      // OEBPS/chapter1.xhtml
      const ch1Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter 1</title></head>
  <body>
    <h1>Chapter 1</h1>
    <p>This is the first paragraph of local EPUB book content with words to test extraction.</p>
    <p>This second paragraph validates word count calculation and reading time estimation accuracy.</p>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('OEBPS/chapter1.xhtml', ch1Xml));

      // OEBPS/chapter2.xhtml
      const ch2Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter 2</title></head>
  <body>
    <h1>Chapter 2</h1>
    <p>Chapter two provides additional text content for comprehensive local book verification.</p>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('OEBPS/chapter2.xhtml', ch2Xml));

      // OEBPS/style.css
      archive.addFile(ArchiveFile.string('OEBPS/style.css', 'body { font-family: serif; }'));

      final encoder = ZipEncoder();
      sampleEpubBytes = Uint8List.fromList(encoder.encode(archive)!);
    });

    test('Validates local EPUB container structure via EpubValidator', () async {
      final source = MemoryBookSource(name: 'test_book.epub', bytes: sampleEpubBytes);
      const validator = EpubValidator();
      final result = await validator.validate(source);

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Parses full publication metadata including contributors, collections, and accessibility', () async {
      final parser = EpubPublicationParser();
      final publication = await parser.parsePublication(sampleEpubBytes);

      expect(publication.metadata.title, equals('Complete Local EPUB Test'));
      expect(publication.metadata.authors, contains('John Doe'));
      expect(publication.metadata.publisher, equals('Antigravity Publishing'));
      expect(publication.metadata.language, equals('en'));

      // Contributors with roles
      expect(publication.metadata.contributors, hasLength(2));
      expect(publication.metadata.contributors.first.role, equals('aut'));
      expect(publication.metadata.contributors.last.name, equals('Jane Smith'));

      // Series / Collections
      expect(publication.metadata.collections, hasLength(1));
      expect(publication.metadata.collections.first.name, equals('Master Ebook Series'));

      // Accessibility Metadata
      expect(publication.metadata.accessibility.features, contains('structuralNavigation'));
      expect(publication.metadata.accessibility.features, contains('alternativeText'));
    });

    test('Classifies manifest resources into correct ResourceTypes', () async {
      final parser = EpubPublicationParser();
      final publication = await parser.parsePublication(sampleEpubBytes);

      final navRes = publication.getResource('OEBPS/nav.xhtml');
      expect(navRes, isNotNull);
      expect(navRes!.isNavigation, isTrue);
      expect(navRes.isContentDocument, isTrue);

      final cssRes = publication.getResource('OEBPS/style.css');
      expect(cssRes, isNotNull);
      expect(cssRes!.isStylesheet, isTrue);

      final coverRes = publication.coverResource;
      expect(coverRes, isNotNull);
      expect(coverRes!.isImage, isTrue);

      final fontRes = publication.getResource('OEBPS/font.ttf');
      expect(fontRes, isNotNull);
      expect(fontRes!.isFont, isTrue);
    });

    test('Calculates derived statistics (word count, reading time, resource metrics)', () async {
      final parser = EpubPublicationParser();
      final publication = await parser.parsePublication(sampleEpubBytes);

      final stats = publication.derivedStatistics;
      expect(stats.wordCount, greaterThan(20));
      expect(stats.chapterCount, equals(3));
      expect(stats.imageCount, equals(1));
      expect(stats.fontCount, equals(1));
      expect(stats.stylesheetCount, equals(1));
      expect(stats.estimatedReadingTimeMinutes, greaterThanOrEqualTo(1));
    });

    test('Imports local EPUB book end-to-end via BookImporter pipeline', () async {
      final source = MemoryBookSource(name: 'test_book.epub', bytes: sampleEpubBytes);
      final repository = InMemoryPublicationRepository();
      final importer = BookImporter(repository: repository);

      final result = await importer.importBook(source);

      expect(result.isSuccess, isTrue);
      expect(result.publication, isNotNull);
      expect(result.publication!.metadata.title, equals('Complete Local EPUB Test'));

      final saved = await repository.getPublicationById(result.publication!.id);
      expect(saved, isNotNull);
    });
  });
}
