/// Turns importable documents into something the readers open: EPUB as-is,
/// PDF as-is, and plain-text-like documents (TXT, Markdown, HTML, DOCX)
/// converted to a real EPUB 3 with chapters, so every reader feature
/// (both engines, TOC, search, highlights, progress) works on them unchanged.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../core/utils/hash_utils.dart';

enum DocumentKind { epub, pdf }

class ConvertedDocument {
  final DocumentKind kind;
  final List<int> bytes;
  const ConvertedDocument(this.kind, this.bytes);
}

/// Why a document can't be imported. The UI turns this into translated text.
enum UnsupportedReason { legacyWordDoc, unknownType, damagedFile, notWordDocument, emptyFile, pdfNotSupported }

class UnsupportedDocumentException implements Exception {
  final String fileName;
  final UnsupportedReason reason;
  const UnsupportedDocumentException(this.fileName, this.reason);
  @override
  String toString() => '$fileName: ${reason.name}';
}

class DocumentConverter {
  DocumentConverter._();

  /// File extensions the import picker offers.
  static const supportedExtensions = ['epub', 'pdf', 'txt', 'md', 'markdown', 'html', 'htm', 'xhtml', 'docx'];

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static String titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot == -1 ? fileName : fileName.substring(0, dot);
    return base.replaceAll(RegExp(r'[_]+'), ' ').trim();
  }

  static ConvertedDocument convert(String fileName, List<int> bytes) {
    final ext = extensionOf(fileName);
    final title = titleFromFileName(fileName);
    switch (ext) {
      case 'epub':
        return ConvertedDocument(DocumentKind.epub, bytes);
      case 'pdf':
        return ConvertedDocument(DocumentKind.pdf, bytes);
      case 'txt':
        return _epub(title, null, _textChapters(_decode(bytes)), bytes);
      case 'md':
      case 'markdown':
        return _epub(title, null, _markdownChapters(_decode(bytes)), bytes);
      case 'html':
      case 'htm':
      case 'xhtml':
        final (htmlTitle, chapters) = _htmlChapters(_decode(bytes));
        return _epub(htmlTitle ?? title, null, chapters, bytes);
      case 'docx':
        final (docTitle, author, chapters) = _docxChapters(fileName, bytes);
        return _epub(docTitle ?? title, author, chapters, bytes);
      case 'doc':
        throw UnsupportedDocumentException(fileName, UnsupportedReason.legacyWordDoc);
      default:
        throw UnsupportedDocumentException(fileName, UnsupportedReason.unknownType);
    }
  }

  // --- formats ---------------------------------------------------------------

  static String _decode(List<int> bytes) {
    var start = 0;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) start = 3; // BOM
    return utf8.decode(bytes.sublist(start), allowMalformed: true).replaceAll('\r\n', '\n');
  }

  static final _chapterHeading =
      RegExp(r'^\s*(chapter|part|book|prologue|epilogue)\b.{0,60}$', caseSensitive: false);

  /// Paragraphs split on blank lines; "Chapter 3" style lines start chapters.
  static List<(String, String)> _textChapters(String text) {
    final chapters = <(String, StringBuffer)>[];
    StringBuffer current() {
      if (chapters.isEmpty) chapters.add(('Start', StringBuffer()));
      return chapters.last.$2;
    }

    for (final block in text.split(RegExp(r'\n\s*\n'))) {
      final para = block.trim();
      if (para.isEmpty) continue;
      if (!para.contains('\n') && _chapterHeading.hasMatch(para)) {
        chapters.add((para, StringBuffer('<h2>${_esc(para)}</h2>\n')));
        continue;
      }
      current().write('<p>${_esc(para).replaceAll('\n', '<br/>')}</p>\n');
    }
    return _finish(chapters);
  }

  static List<(String, String)> _markdownChapters(String md) {
    final chapters = <(String, StringBuffer)>[];
    StringBuffer current() {
      if (chapters.isEmpty) chapters.add(('Start', StringBuffer()));
      return chapters.last.$2;
    }

    String inline(String s) => _esc(s)
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>')
        .replaceAllMapped(RegExp(r'(?<![*\w])\*(?!\s)(.+?)\*'), (m) => '<em>${m[1]}</em>')
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<code>${m[1]}</code>');

    final para = <String>[];
    var inList = false;
    void flushPara() {
      if (para.isNotEmpty) current().write('<p>${inline(para.join(' '))}</p>\n');
      para.clear();
    }

    void closeList() {
      if (inList) current().write('</ul>\n');
      inList = false;
    }

    for (final raw in md.split('\n')) {
      final line = raw.trimRight();
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      final item = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
      if (heading != null) {
        flushPara();
        closeList();
        final level = heading[1]!.length;
        final textOf = heading[2]!.trim();
        if (level <= 2) {
          chapters.add((textOf, StringBuffer('<h$level>${inline(textOf)}</h$level>\n')));
        } else {
          current().write('<h$level>${inline(textOf)}</h$level>\n');
        }
      } else if (item != null) {
        flushPara();
        if (!inList) current().write('<ul>\n');
        inList = true;
        current().write('<li>${inline(item[1]!)}</li>\n');
      } else if (line.trim().isEmpty) {
        flushPara();
        closeList();
      } else {
        closeList();
        para.add(line.trim());
      }
    }
    flushPara();
    closeList();
    return _finish(chapters);
  }

  static (String?, List<(String, String)>) _htmlChapters(String html) {
    final title = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html)?[1]?.trim();
    final body = RegExp(r'<body[^>]*>(.*)</body>', caseSensitive: false, dotAll: true).firstMatch(html)?[1] ?? html;
    final clean = body
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '');
    // Re-serialise through the XML-tolerant path: wrap as XHTML text. Tags
    // that aren't well-formed XHTML are escaped by stripping to text blocks.
    final paragraphs = clean
        .split(RegExp(r'</?(p|div|br|h[1-6]|li|section|article)[^>]*>', caseSensitive: false))
        .map((s) => s.replaceAll(RegExp(r'<[^>]+>'), '').trim())
        .where((s) => s.isNotEmpty)
        .map((s) => '<p>${_esc(_unescapeEntities(s))}</p>')
        .join('\n');
    return (title == null || title.isEmpty ? null : _unescapeEntities(title), [('Start', paragraphs)]);
  }

  static (String?, String?, List<(String, String)>) _docxChapters(String fileName, List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw UnsupportedDocumentException(fileName, UnsupportedReason.damagedFile);
    }
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) throw UnsupportedDocumentException(fileName, UnsupportedReason.notWordDocument);
    final doc = XmlDocument.parse(utf8.decode(docFile.content as List<int>, allowMalformed: true));

    String? title, author;
    final core = archive.findFile('docProps/core.xml');
    if (core != null) {
      final props = XmlDocument.parse(utf8.decode(core.content as List<int>, allowMalformed: true));
      title = props.findAllElements('title', namespace: '*').firstOrNull?.innerText.trim();
      author = props.findAllElements('creator', namespace: '*').firstOrNull?.innerText.trim();
    }

    final chapters = <(String, StringBuffer)>[];
    StringBuffer current() {
      if (chapters.isEmpty) chapters.add(('Start', StringBuffer()));
      return chapters.last.$2;
    }

    for (final p in doc.findAllElements('p', namespace: '*')) {
      final style = p.findAllElements('pStyle', namespace: '*').firstOrNull?.getAttribute('w:val') ?? '';
      final runs = StringBuffer();
      for (final r in p.findAllElements('r', namespace: '*')) {
        final text = r.findAllElements('t', namespace: '*').map((t) => t.innerText).join();
        if (text.isEmpty) continue;
        final props = r.findAllElements('rPr', namespace: '*').firstOrNull;
        var html = _esc(text);
        if (props?.findElements('w:i').isNotEmpty ?? false) html = '<em>$html</em>';
        if (props?.findElements('w:b').isNotEmpty ?? false) html = '<strong>$html</strong>';
        runs.write(html);
      }
      final plain = p.findAllElements('t', namespace: '*').map((t) => t.innerText).join().trim();
      if (plain.isEmpty) continue;
      final lower = style.toLowerCase();
      if (lower == 'title' || lower.startsWith('heading1') || lower == 'heading 1') {
        if (lower == 'title' && (title == null || title.isEmpty)) title = plain;
        chapters.add((plain, StringBuffer('<h1>$runs</h1>\n')));
      } else if (lower.startsWith('heading')) {
        current().write('<h2>$runs</h2>\n');
      } else {
        current().write('<p>$runs</p>\n');
      }
    }
    return (title == null || title.isEmpty ? null : title, author == null || author.isEmpty ? null : author, _finish(chapters));
  }

  // --- EPUB assembly -----------------------------------------------------------

  static List<(String, String)> _finish(List<(String, StringBuffer)> chapters) {
    final out = [
      for (final (t, b) in chapters)
        if (b.isNotEmpty) (t, b.toString()),
    ];
    return out.isEmpty ? [('Start', '<p></p>')] : out;
  }

  static ConvertedDocument _epub(String title, String? author, List<(String, String)> chapters, List<int> source) {
    // Content hash identifier: two different files with the same title are
    // different books (a title-based id would make one replace the other).
    final id = 'urn:fourpages:${HashUtils.sha256Bytes(source).substring(0, 32)}';
    final archive = Archive();
    final mimetype = utf8.encode('application/epub+zip');
    archive.addFile(ArchiveFile('mimetype', mimetype.length, mimetype)..compress = false);
    _add(archive, 'META-INF/container.xml',
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="EPUB/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>');

    final manifest = StringBuffer('<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>\n');
    final spine = StringBuffer();
    final nav = StringBuffer();
    for (var i = 0; i < chapters.length; i++) {
      final (chapterTitle, body) = chapters[i];
      final file = 'ch${i + 1}.xhtml';
      manifest.writeln('<item id="c${i + 1}" href="$file" media-type="application/xhtml+xml"/>');
      spine.writeln('<itemref idref="c${i + 1}"/>');
      nav.writeln('<li><a href="$file">${_esc(chapterTitle)}</a></li>');
      _add(archive, 'EPUB/$file', '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n'
          '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>${_esc(chapterTitle)}</title></head>'
          '<body>\n$body</body></html>');
    }
    _add(archive, 'EPUB/package.opf', '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">$id</dc:identifier>
    <dc:title>${_esc(title)}</dc:title>
    <dc:creator>${_esc(author ?? 'Unknown author')}</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
$manifest  </manifest>
  <spine>
$spine  </spine>
</package>''');
    _add(archive, 'EPUB/nav.xhtml', '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head>
<body><nav epub:type="toc"><ol>
$nav</ol></nav></body></html>''');
    return ConvertedDocument(DocumentKind.epub, ZipEncoder().encode(archive)!);
  }

  static void _add(Archive archive, String path, String text) {
    final data = utf8.encode(text);
    archive.addFile(ArchiveFile(path, data.length, data));
  }

  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static String _unescapeEntities(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}
