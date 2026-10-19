import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'epub_cfi_parser.dart';
import '../models/paragraph.dart';

class EpubCfiReader {
  EpubCfiReader()
      : cfiInput = null,
        chapters = [],
        paragraphs = [];

  EpubCfiReader.parser({
    required this.cfiInput,
    required this.chapters,
    required this.paragraphs,
  });

  String? cfiInput;
  final List<EpubChapter> chapters;
  final List<Paragraph> paragraphs;

  CfiFragment? _cfiFragment;
  int? _lastParagraphIndex;

  set epubCfi(String? epubCfi) {
    cfiInput = epubCfi;
    _lastParagraphIndex = null;
  }

  int? get paragraphIndexByCfiFragment {
    if (_lastParagraphIndex == null && cfiInput != null) {
      try {
        _cfiFragment = EpubCfiParser().parse(cfiInput!, 'fragment');
        _lastParagraphIndex = _paragraphIndexByCfiFragment(_cfiFragment);
      } catch (e) {
        _lastParagraphIndex = null;
      }
    }
    return _lastParagraphIndex;
  }

  int? _paragraphIndexByCfiFragment(CfiFragment? cfiFragment) {
    if (cfiFragment == null ||
        cfiFragment.path?.localPath?.steps == null ||
        cfiFragment.path!.localPath!.steps!.isEmpty) {
      return null;
    }

    final int? chapterIndex = _getChapterIndexBy(cfiStep: cfiFragment.path!.localPath!.steps!.first);
    if (chapterIndex == null || chapterIndex >= chapters.length) {
      return null;
    }
    final chapter = chapters[chapterIndex];
    final document = chapterDocument(chapter);
    if (document == null || document.documentElement == null) {
      return null;
    }
    final element = EpubCfiInterpreter().searchLocalPathForHref(
      document.documentElement!,
      cfiFragment.path!.localPath!,
    );
    final int? paragraphNumber = getParagraphIndexByElement(element);

    return paragraphNumber;
  }

  Future<String?> _cfiChapter({
    required EpubBook? book,
    required EpubChapter? chapter,
    EpubCfiGenerator generator = const EpubCfiGenerator(),
  }) async {
    if (book == null || chapter == null) {
      return null;
    }
    final document = chapterDocument(chapter);
    if (document == null) {
      return null;
    }

    return generator.generatePackageDocumentCFIComponent(
        chapter, book.Schema!.Package!);
  }

  Future<String?> generateCfi({
    required EpubBook? book,
    required EpubChapter? chapter,
    required int? paragraphIndex,
    List<String> additional = const [],
    EpubCfiGenerator generator = const EpubCfiGenerator(),
  }) async {
    if (paragraphIndex == null || paragraphIndex >= paragraphs.length) {
      return null;
    }

    final currentNode = paragraphs[paragraphIndex].element;

    final packageDocumentCFIComponent = await _cfiChapter(
      book: book,
      chapter: chapter,
      generator: generator,
    );

    final contentDocumentCFIComponent = generator.generateElementCFIComponent(currentNode);

    return generator.generateCompleteCFI([
      packageDocumentCFIComponent,
      contentDocumentCFIComponent,
      ...additional,
    ]);
  }

  Future<String?> generateCfiChapter({
    required EpubBook? book,
    required EpubChapter chapter,
    List<String> additional = const [],
    EpubCfiGenerator generator = const EpubCfiGenerator(),
  }) async {
    final packageDocumentCFIComponent = await _cfiChapter(
      book: book,
      chapter: chapter,
      generator: generator,
    );

    return generator.generateCompleteCFI([
      packageDocumentCFIComponent,
      ...additional,
    ]);
  }

  dom.Document? chapterDocument(EpubChapter? chapter) {
    if (chapter == null || chapter.HtmlContent == null || chapter.HtmlContent!.isEmpty) {
      return null;
    }
    return parse(chapter.HtmlContent!);
  }

  int? _getChapterIndexBy({CfiStep? cfiStep}) {
    if (cfiStep == null) {
      return null;
    }

    final index = chapters.indexWhere(
      (chapter) =>
          chapter.Anchor == cfiStep.idAssertion ||
          (chapter.ContentFileName != null && cfiStep.idAssertion != null && chapter.ContentFileName!.contains(cfiStep.idAssertion!)),
    );

    if (index == -1) {
      return null;
    }

    return index;
  }

  int? getParagraphIndexByElement(dom.Element? element) {
    if (element == null) {
      return null;
    }

    final index = paragraphs.indexWhere(
        (paragraph) => paragraph.element.outerHtml == element.outerHtml);

    if (index == -1) {
      return null;
    }

    return index;
  }
}
