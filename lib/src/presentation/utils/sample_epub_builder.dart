import 'package:archive/archive.dart';

class SampleEpubBuilder {
  SampleEpubBuilder._();

  /// Builds a production-valid EPUB 3 ZIP archive bytes for any imported title, author, and chapter text contents.
  static List<int> buildEpubZip({
    required String title,
    required String author,
    required List<String> chapterTexts,
  }) {
    final archive = Archive();
    archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));
    archive.addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
      ),
    );

    final manifestItems = <String>[];
    final spineItemrefs = <String>[];
    final navLiItems = <String>[];

    manifestItems.add('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>');

    for (var i = 0; i < chapterTexts.length; i++) {
      final id = 'ch${i + 1}';
      final filename = 'ch${i + 1}.xhtml';
      manifestItems.add('<item id="$id" href="$filename" media-type="application/xhtml+xml"/>');
      spineItemrefs.add('<itemref idref="$id"/>');
      navLiItems.add('<li><a href="$filename">Chapter ${i + 1}</a></li>');

      final xhtmlContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter ${i + 1}</title></head>
<body>
  <h1 id="chapter-${i + 1}">Chapter ${i + 1}</h1>
  <p>${chapterTexts[i]}</p>
</body>
</html>
''';
      archive.addFile(ArchiveFile.string('EPUB/$filename', xhtmlContent));
    }

    final opfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
    <dc:language>en</dc:language>
    <dc:identifier id="pub-id">id-${title.hashCode}</dc:identifier>
  </metadata>
  <manifest>
    ${manifestItems.join('\n')}
  </manifest>
  <spine>
    ${spineItemrefs.join('\n')}
  </spine>
</package>
''';
    archive.addFile(ArchiveFile.string('EPUB/package.opf', opfXml));

    final navXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <nav epub:type="toc">
    <h1>Table of Contents</h1>
    <ol>
      ${navLiItems.join('\n')}
    </ol>
  </nav>
</body>
</html>
''';
    archive.addFile(ArchiveFile.string('EPUB/nav.xhtml', navXml));

    return ZipEncoder().encode(archive)!;
  }
}
