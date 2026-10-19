import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import '../../domain/entities/epub_view_chapter.dart';
import '../models/paragraph.dart';

List<dom.Element> convertDocumentToElements(dom.Document document) {
  final bodies = document.getElementsByTagName('body');
  if (bodies.isNotEmpty && bodies.first.children.isNotEmpty) {
    return bodies.first.children;
  }
  if (document.documentElement != null) {
    return document.documentElement!.children;
  }
  return document.children;
}

bool _isBlockElement(dom.Element element) {
  final tag = element.localName?.toLowerCase() ?? '';
  return {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'blockquote', 'ul', 'ol', 'li', 'img', 'image',
    'figure', 'div', 'section', 'article', 'table', 'hr'
  }.contains(tag);
}

List<dom.Element> _extractBlockElements(List<dom.Element> elements) {
  final List<dom.Element> result = [];

  for (final node in elements) {
    final name = node.localName?.toLowerCase() ?? '';
    if ((name == 'div' || name == 'section' || name == 'article' || name == 'main' || name == 'body') &&
        node.children.any(_isBlockElement)) {
      result.addAll(_extractBlockElements(node.children));
    } else {
      result.add(node);
    }
  }

  return result;
}

/// The epubx view's reading order: what is rendered, in which order, and
/// where each TOC entry starts.
class ReadingOrder {
  ReadingOrder({
    required this.chapters,
    required this.paragraphs,
    required this.chapterIndexes,
    required this.tableOfContents,
  });

  /// One or more chapters per spine document, in spine order. A spine
  /// document no TOC entry points to gets an untitled chapter (`Title ==
  /// null`) so its text is still rendered.
  final List<EpubChapter> chapters;

  /// Block elements of every spine document, in spine order.
  final List<Paragraph> paragraphs;

  /// First paragraph index of `chapters[i]`. Never decreasing - the
  /// position lookup in EpubViewState relies on that.
  final List<int> chapterIndexes;

  /// The book's own TOC (titled entries, publisher order, nested entries as
  /// [EpubViewSubChapter]), each pointing at the paragraph it starts on.
  final List<EpubViewChapter> tableOfContents;
}

/// Builds the reading order from the OPF **spine**, using the TOC only for
/// titles and jump targets.
///
/// epubx's `Chapters` is the NCX/nav, not the reading order. Rendering it
/// directly (as this view used to) drops every spine document the TOC
/// doesn't list - real books ship a single "Start" entry for 30+ files -
/// reorders content to TOC order, and duplicated a whole file once per
/// anchored entry inside it. The sakura/epub.js engine already reads by
/// spine, so this also keeps both engines showing the same text.
ReadingOrder buildReadingOrder(EpubBook book) {
  final flatToc = <(EpubChapter, int)>[];
  void flatten(List<EpubChapter> chapters, int depth) {
    for (final chapter in chapters) {
      flatToc.add((chapter, depth));
      flatten(chapter.SubChapters ?? const [], depth + 1);
    }
  }

  flatten(book.Chapters ?? const [], 0);

  final html = book.Content?.Html ?? const <String, EpubTextContentFile>{};
  final spineFiles = _spineHtmlFiles(book, html);
  if (spineFiles.isEmpty) {
    // No usable spine: fall back to the documents the TOC references.
    for (final (chapter, _) in flatToc) {
      final name = chapter.ContentFileName;
      if (name != null && !spineFiles.any((f) => f.$1 == name)) {
        spineFiles.add((name, chapter.HtmlContent ?? ''));
      }
    }
  }

  final chapters = <EpubChapter>[];
  final chapterIndexes = <int>[];
  final paragraphs = <Paragraph>[];
  final readingIndexOfToc = <int, int>{}; // flatToc index -> chapters index

  for (final (fileName, content) in spineFiles) {
    final elements = content.isEmpty
        ? <dom.Element>[]
        : _extractBlockElements(convertDocumentToElements(parse(content)));
    final fileStart = paragraphs.length;

    final starts = <(int, int?, EpubChapter)>[]; // (start, flatToc index, chapter)
    for (var t = 0; t < flatToc.length; t++) {
      final chapter = flatToc[t].$1;
      if (readingIndexOfToc.containsKey(t) || chapter.ContentFileName != fileName) continue;
      final anchor = chapter.Anchor;
      var offset = 0;
      if (anchor != null && anchor.isNotEmpty) {
        final found = elements.indexWhere(
          (e) => e.id == anchor || e.outerHtml.contains('id="$anchor"') || e.outerHtml.contains("id='$anchor'"),
        );
        if (found > 0) offset = found;
      }
      starts.add((fileStart + offset, t, chapter));
    }
    if (starts.isEmpty) {
      starts.add((
        fileStart,
        null,
        EpubChapter()
          ..ContentFileName = fileName
          ..HtmlContent = content
          ..SubChapters = [],
      ));
    }
    // Stable sort by start so anchors listed out of document order can't
    // make chapterIndexes decrease.
    final ordered = [for (var i = 0; i < starts.length; i++) (i, starts[i])]
      ..sort((a, b) {
        final byStart = a.$2.$1.compareTo(b.$2.$1);
        return byStart != 0 ? byStart : a.$1.compareTo(b.$1);
      });

    final firstChapterOfFile = chapters.length;
    for (final (_, (start, tocIndex, chapter)) in ordered) {
      if (tocIndex != null) readingIndexOfToc[tocIndex] = chapters.length;
      chapters.add(chapter);
      chapterIndexes.add(start);
    }

    var owner = firstChapterOfFile;
    for (var j = 0; j < elements.length; j++) {
      final position = fileStart + j;
      while (owner + 1 < chapters.length && chapterIndexes[owner + 1] <= position) {
        owner++;
      }
      paragraphs.add(Paragraph(elements[j], owner));
    }
  }

  final tableOfContents = <EpubViewChapter>[];
  for (var t = 0; t < flatToc.length; t++) {
    final readingIndex = readingIndexOfToc[t];
    if (readingIndex == null) continue; // points at a non-spine document
    final (chapter, depth) = flatToc[t];
    final start = chapterIndexes[readingIndex];
    tableOfContents.add(depth == 0 ? EpubViewChapter(chapter.Title, start) : EpubViewSubChapter(chapter.Title, start));
  }

  return ReadingOrder(
    chapters: chapters,
    paragraphs: paragraphs,
    chapterIndexes: chapterIndexes,
    tableOfContents: tableOfContents,
  );
}

/// `(decoded file name, html)` for each spine item that is an HTML document,
/// first occurrence only. File names are decoded the same way epubx decodes
/// `EpubChapter.ContentFileName`, so the two can be compared directly.
List<(String, String)> _spineHtmlFiles(EpubBook book, Map<String, EpubTextContentFile> html) {
  final package = book.Schema?.Package;
  final manifest = {
    for (final item in package?.Manifest?.Items ?? const <EpubManifestItem>[])
      if (item.Id != null && item.Href != null) item.Id!: item.Href!,
  };
  final result = <(String, String)>[];
  final seen = <String>{};
  for (final ref in package?.Spine?.Items ?? const <EpubSpineItemRef>[]) {
    final href = manifest[ref.IdRef];
    if (href == null) continue;
    final file = html[href] ?? html[Uri.decodeFull(href)];
    if (file == null) continue; // e.g. an image-only spine item
    final name = Uri.decodeFull(href);
    if (seen.add(name)) result.add((name, file.Content ?? ''));
  }
  return result;
}
