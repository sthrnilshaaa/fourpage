import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:aread/src/data/importers/document_converter.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Publication> parse(ConvertedDocument doc) => EpubPublicationParser().parsePublication(doc.bytes);

List<int> docx({required String title, required List<(String style, String text)> paragraphs}) {
  final body = paragraphs
      .map((p) => '<w:p><w:pPr><w:pStyle w:val="${p.$1}"/></w:pPr><w:r><w:t>${p.$2}</w:t></w:r></w:p>')
      .join();
  final archive = Archive();
  void add(String path, String text) {
    final data = utf8.encode(text);
    archive.addFile(ArchiveFile(path, data.length, data));
  }

  add('word/document.xml',
      '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>');
  add('docProps/core.xml',
      '<?xml version="1.0"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>$title</dc:title><dc:creator>Ann Author</dc:creator></cp:coreProperties>');
  return ZipEncoder().encode(archive)!;
}

void main() {
  test('EPUB and PDF pass through unchanged', () {
    final bytes = [1, 2, 3];
    expect(DocumentConverter.convert('a.epub', bytes).kind, DocumentKind.epub);
    expect(DocumentConverter.convert('a.PDF', bytes).kind, DocumentKind.pdf);
    expect(DocumentConverter.convert('a.pdf', bytes).bytes, bytes);
  });

  test('TXT becomes an EPUB with chapters from "Chapter N" lines', () async {
    const text = 'Opening line.\n\nChapter 1\n\nIt was a dark night.\nStill dark.\n\nChapter 2\n\nMorning came — café open.';
    final pub = await parse(DocumentConverter.convert('My_Story.txt', utf8.encode(text)));
    expect(pub.metadata.title, 'My Story');
    expect(pub.tableOfContents.items.map((i) => i.title), ['Start', 'Chapter 1', 'Chapter 2']);
    expect(pub.spine, hasLength(3));
  });

  test('Markdown headings split chapters; non-ASCII survives', () async {
    const md = '# Première partie\n\nSome *emphasis* and **bold**.\n\n- one\n- two\n\n## Deuxième\n\nText.';
    final pub = await parse(DocumentConverter.convert('notes.md', utf8.encode(md)));
    expect(pub.tableOfContents.items.map((i) => i.title), ['Première partie', 'Deuxième']);
  });

  test('HTML keeps its <title> and text, drops scripts', () async {
    const html = '<html><head><title>Web &amp; Page</title><script>alert(1)</script></head>'
        '<body><h1>Hello</h1><p>First para</p><script>x()</script><p>Second</p></body></html>';
    final doc = DocumentConverter.convert('page.html', utf8.encode(html));
    final pub = await parse(doc);
    expect(pub.metadata.title, 'Web & Page');
    final chapter = OcfContainer.fromBytes(doc.bytes).readText(pub.spine.first.href);
    expect(chapter, contains('First para'));
    expect(chapter, isNot(contains('alert')));
  });

  test('DOCX uses Title/Heading1 for chapters and core.xml metadata', () async {
    final bytes = docx(title: 'Quarterly Report', paragraphs: [
      ('Title', 'Quarterly Report'),
      ('Normal', 'Intro text'),
      ('Heading1', 'Results'),
      ('Normal', 'Numbers went up'),
    ]);
    final pub = await parse(DocumentConverter.convert('report.docx', bytes));
    expect(pub.metadata.title, 'Quarterly Report');
    expect(pub.metadata.authors, ['Ann Author']);
    expect(pub.tableOfContents.items.map((i) => i.title), ['Quarterly Report', 'Results']);
  });

  test('two different files with the same name are different books', () async {
    final a = await parse(DocumentConverter.convert('same.txt', utf8.encode('one')));
    final b = await parse(DocumentConverter.convert('same.txt', utf8.encode('two')));
    expect(a.id, isNot(b.id));
  });

  test('legacy .doc and unknown types are rejected with a reason', () {
    expect(() => DocumentConverter.convert('old.doc', [0]), throwsA(isA<UnsupportedDocumentException>()));
    expect(() => DocumentConverter.convert('x.xyz', [0]), throwsA(isA<UnsupportedDocumentException>()));
  });
}
