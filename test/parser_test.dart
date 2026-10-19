import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EPUB Publication Parser Tests', () {
    test('parses full EPUB 3 publication with nav.xhtml TOC', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));
      archive.addFile(
        ArchiveFile.string(
          'META-INF/container.xml',
          '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
              '<rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        ),
      );
      archive.addFile(
        ArchiveFile.string(
          'EPUB/package.opf',
          '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">'
              '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
              '<dc:title>Clean Code Architecture</dc:title>'
              '<dc:creator>Robert C. Martin</dc:creator>'
              '<dc:language>en</dc:language>'
              '<dc:identifier id="book-id">urn:isbn:9780132350884</dc:identifier>'
              '</metadata>'
              '<manifest>'
              '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
              '<item id="cover" href="cover.jpg" media-type="image/jpeg" properties="cover-image"/>'
              '<item id="ch1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>'
              '<item id="ch2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/>'
              '</manifest>'
              '<spine>'
              '<itemref idref="ch1"/>'
              '<itemref idref="ch2"/>'
              '</spine></package>',
        ),
      );
      archive.addFile(
        ArchiveFile.string(
          'EPUB/nav.xhtml',
          '<?xml version="1.0" encoding="UTF-8"?>'
              '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">'
              '<body>'
              '<nav epub:type="toc">'
              '<h1>Table of Contents</h1>'
              '<ol>'
              '<li><a href="text/ch1.xhtml">Chapter 1: Clean Code</a></li>'
              '<li><a href="text/ch2.xhtml">Chapter 2: Meaningful Names</a></li>'
              '</ol>'
              '</nav>'
              '</body></html>',
        ),
      );
      archive.addFile(ArchiveFile.string('EPUB/text/ch1.xhtml', '<html><body><h1>Chapter 1</h1><p>Clean code smells nice.</p></body></html>'));
      archive.addFile(ArchiveFile.string('EPUB/text/ch2.xhtml', '<html><body><h1>Chapter 2</h1><p>Names matter a lot.</p></body></html>'));

      final zipBytes = ZipEncoder().encode(archive)!;
      final parser = EpubPublicationParser();

      final pub = await parser.parsePublication(zipBytes);

      expect(pub.metadata.title, equals('Clean Code Architecture'));
      expect(pub.metadata.authors, contains('Robert C. Martin'));
      expect(pub.spine.length, equals(2));
      expect(pub.tableOfContents.items.length, equals(2));
      expect(pub.tableOfContents.items.first.title, equals('Chapter 1: Clean Code'));
      expect(pub.coverResource?.href, equals('EPUB/cover.jpg'));
      expect(pub.fingerprint, isNotEmpty);
    });

    test('parses EPUB 2 NCX navigation fallback', () {
      const ncxXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="nav1" playOrder="1">
      <navLabel><text>Introduction</text></navLabel>
      <content src="intro.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
''';

      final navParser = NavigationParser();
      final toc = navParser.parse(navContent: ncxXml, navDocumentPath: 'OEBPS/toc.ncx');

      expect(toc.items.length, equals(1));
      expect(toc.items.first.title, equals('Introduction'));
      expect(toc.items.first.href, equals('OEBPS/intro.xhtml'));
    });
  });
}
