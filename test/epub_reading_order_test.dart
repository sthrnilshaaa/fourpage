import 'package:archive/archive.dart';
import 'package:aread/src/data/parsers/epub_document.dart';
import 'package:aread/src/data/parsers/epub_view_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an EPUB 2 archive whose NCX can disagree with its spine, the way
/// real Calibre-converted books do (see docs/reader/epubx-engine.md).
Uint8List buildEpub({
  required List<String> spineFiles,
  required Map<String, String> fileBodies,
  required String ncxNavPoints,
  List<String> extraManifestHrefs = const [],
  String? missingCoverHref,
}) {
  final archive = Archive();
  archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));
  archive.addFile(ArchiveFile.string(
    'META-INF/container.xml',
    '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
  ));

  final manifest = StringBuffer()
    ..writeln('<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>');
  final spine = StringBuffer();
  for (var i = 0; i < spineFiles.length; i++) {
    manifest.writeln('<item id="f$i" href="${spineFiles[i]}" media-type="application/xhtml+xml"/>');
    spine.writeln('<itemref idref="f$i"/>');
  }
  for (var i = 0; i < extraManifestHrefs.length; i++) {
    manifest.writeln('<item id="x$i" href="${extraManifestHrefs[i]}" media-type="text/css"/>');
  }
  if (missingCoverHref != null) {
    manifest.writeln('<item id="cover" href="$missingCoverHref" media-type="image/jpeg" properties="cover-image"/>');
  }

  archive.addFile(ArchiveFile.string('OEBPS/content.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Order Test</dc:title>${missingCoverHref != null ? '<meta name="cover" content="cover"/>' : ''}<dc:identifier id="id">order-test</dc:identifier><dc:language>en</dc:language>
  </metadata>
  <manifest>$manifest</manifest>
  <spine toc="ncx">$spine</spine>
</package>'''));

  archive.addFile(ArchiveFile.string('OEBPS/toc.ncx', '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head></head><docTitle><text>Order Test</text></docTitle>
  <navMap>$ncxNavPoints</navMap>
</ncx>'''));

  for (final file in spineFiles) {
    archive.addFile(ArchiveFile.string(
      'OEBPS/$file',
      '<?xml version="1.0" encoding="UTF-8"?><html xmlns="http://www.w3.org/1999/xhtml">'
          '<head><title>$file</title></head><body>${fileBodies[file]}</body></html>',
    ));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String navPoint(String id, String label, String src, [String children = '']) =>
    '<navPoint id="$id"><navLabel><text>$label</text></navLabel><content src="$src"/>$children</navPoint>';

List<String> texts(ReadingOrder order) => order.paragraphs.map((p) => p.element.text.trim()).toList();

void main() {
  group('buildReadingOrder (epubx / Linux-Web reader)', () {
    test('includes every spine item even when the TOC lists only the first', () async {
      // Mirrors "The Catcher in the Rye" demo book: NCX = one "Start" entry,
      // spine = 32 files. The old TOC-driven builder rendered only page one.
      final bytes = buildEpub(
        spineFiles: ['a.html', 'b.html', 'c.html'],
        fileBodies: {'a.html': '<p>A1</p>', 'b.html': '<p>B1</p><p>B2</p>', 'c.html': '<p>C1</p>'},
        ncxNavPoints: navPoint('n1', 'Start', 'a.html'),
      );
      final order = buildReadingOrder(await EpubDocument.openData(bytes));

      expect(texts(order), ['A1', 'B1', 'B2', 'C1']);
      expect(order.tableOfContents.map((c) => c.title), ['Start']);
      expect(order.tableOfContents.single.startIndex, 0);
    });

    test('follows spine order, not TOC order', () async {
      // Mirrors "Slaughterhouse-Five": its NCX lists the cover (last spine
      // file) first.
      final bytes = buildEpub(
        spineFiles: ['one.html', 'two.html', 'cover.html'],
        fileBodies: {'one.html': '<p>One</p>', 'two.html': '<p>Two</p>', 'cover.html': '<p>Cover</p>'},
        ncxNavPoints: navPoint('n0', 'Cover', 'cover.html') +
            navPoint('n1', 'Chapter 1', 'one.html') +
            navPoint('n2', 'Chapter 2', 'two.html'),
      );
      final order = buildReadingOrder(await EpubDocument.openData(bytes));

      expect(texts(order), ['One', 'Two', 'Cover']);
      final toc = {for (final c in order.tableOfContents) c.title: c.startIndex};
      expect(toc, {'Chapter 1': 0, 'Chapter 2': 1, 'Cover': 2});
    });

    test('anchored entries in one file point inside it without duplicating content', () async {
      // Mirrors "Alice": one spine file, nested NCX entries with #anchors.
      final bytes = buildEpub(
        spineFiles: ['book.htm'],
        fileBodies: {
          'book.htm': '<h1 id="top">Alice</h1><p>intro</p><h2 id="c1">I</h2><p>one</p><h2 id="c2">II</h2><p>two</p>',
        },
        ncxNavPoints: navPoint(
          'n0',
          'Alice',
          'book.htm#top',
          navPoint('n1', 'I', 'book.htm#c1') + navPoint('n2', 'II', 'book.htm#c2'),
        ),
      );
      final order = buildReadingOrder(await EpubDocument.openData(bytes));

      expect(texts(order), ['Alice', 'intro', 'I', 'one', 'II', 'two']);
      final toc = order.tableOfContents;
      expect(toc.map((c) => c.title), ['Alice', 'I', 'II']);
      expect(toc.map((c) => c.startIndex), [0, 2, 4]);
      expect(toc.map((c) => c.type), ['chapter', 'subchapter', 'subchapter']);
      // Every paragraph is attributed to the chapter whose start precedes it.
      expect(order.paragraphs.map((p) => p.chapterIndex), [0, 0, 1, 1, 2, 2]);
    });

    test('chapter start indexes never decrease', () async {
      final bytes = buildEpub(
        spineFiles: ['a.html', 'b.html'],
        fileBodies: {'a.html': '<p id="x">x</p><p id="y">y</p>', 'b.html': '<p>b</p>'},
        // Anchors listed out of document order must not produce a
        // decreasing index (the position lookup relies on sorted starts).
        ncxNavPoints: navPoint('n0', 'Y', 'a.html#y') + navPoint('n1', 'X', 'a.html#x') + navPoint('n2', 'B', 'b.html'),
      );
      final order = buildReadingOrder(await EpubDocument.openData(bytes));
      for (var i = 1; i < order.chapterIndexes.length; i++) {
        expect(order.chapterIndexes[i], greaterThanOrEqualTo(order.chapterIndexes[i - 1]));
      }
    });
  });

  group('EpubDocument.openData repairs missing manifest resources', () {
    test('a manifest stylesheet missing from the ZIP no longer aborts the open', () async {
      // Mirrors "Alice": its OPF lists pgepub.css, which the archive lacks;
      // epubx used to throw "file ... not found in archive".
      final bytes = buildEpub(
        spineFiles: ['a.html'],
        fileBodies: {'a.html': '<p>still readable</p>'},
        ncxNavPoints: navPoint('n0', 'Start', 'a.html'),
        extraManifestHrefs: ['missing.css'],
      );
      final book = await EpubDocument.openData(bytes);
      expect(texts(buildReadingOrder(book)), ['still readable']);
    });

    test('a missing cover image is replaced by a decodable stub', () async {
      // Alice's OPF also names a cover.jpg that isn't in the archive; epubx
      // decodes the cover while opening, so an empty stub would crash it.
      final bytes = buildEpub(
        spineFiles: ['a.html'],
        fileBodies: {'a.html': '<p>cover-less</p>'},
        ncxNavPoints: navPoint('n0', 'Start', 'a.html'),
        missingCoverHref: 'cover.jpg',
      );
      final book = await EpubDocument.openData(bytes);
      expect(texts(buildReadingOrder(book)), ['cover-less']);
    });
  });
}
