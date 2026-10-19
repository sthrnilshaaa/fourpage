import 'dart:async';
import 'dart:typed_data';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_html/flutter_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../domain/entities/epub_view_chapter.dart';
import '../../domain/entities/selected_text_model.dart';
import '../../data/models/paragraph.dart';
import '../../data/parsers/epub_cfi_reader.dart';
import '../../data/parsers/epub_view_parser.dart';
import '../utils/html_stylist.dart';
import 'epub_controller.dart';
import 'epub_view_builders.dart';

const _minTrailingEdge = 0.55;
const _minLeadingEdge = -0.05;

typedef ExternalLinkPressed = void Function(String href);

class EpubView extends StatefulWidget {
  const EpubView({
    required this.controller,
    this.onHighlightTap,
    this.paragraphIndexOnDispose,
    this.onExternalLinkPressed,
    this.onChapterChanged,
    this.onDocumentLoaded,
    this.onDocumentError,
    this.builders = const EpubViewBuilders<DefaultBuilderOptions>(
      options: DefaultBuilderOptions(),
    ),
    this.shrinkWrap = false,
    this.replacedParagraphs,
    this.scrollDirection = Axis.vertical,
    this.physics,
    super.key,
  });

  final EpubController controller;
  final ExternalLinkPressed? onExternalLinkPressed;
  final bool shrinkWrap;
  final void Function(EpubChapterViewValue? value)? onChapterChanged;
  final void Function(EpubBook document)? onDocumentLoaded;
  final void Function(Exception? error)? onDocumentError;
  final EpubViewBuilders builders;
  final Function(SelectedTextModel callback)? onHighlightTap;
  final Function(int paragraphIndex)? paragraphIndexOnDispose;
  final List<SelectedTextModel>? replacedParagraphs;
  final Axis scrollDirection;
  final ScrollPhysics? physics;

  @override
  State<EpubView> createState() => EpubViewState();
}

class EpubViewState extends State<EpubView> {
  Exception? loadingError;
  ItemScrollController? itemScrollController;
  ItemPositionsListener? itemPositionListener;
  List<EpubChapter> chapters = [];
  List<Paragraph> paragraphs = [];
  EpubCfiReader? epubCfiReader;
  EpubChapterViewValue? _currentValue;
  final chapterIndexes = <int>[];
  List<EpubViewChapter> tableOfContentsEntries = [];
  static final highlightedStream = ValueNotifier<SelectedTextModel?>(null);
  static final paragraphList = ValueNotifier<List<String>>([]);

  EpubController get _controller => widget.controller;
  EpubChapterViewValue? get currentValue => _currentValue;

  @override
  void initState() {
    super.initState();
    itemScrollController = ItemScrollController();
    itemPositionListener = ItemPositionsListener.create();
    _controller.attach(this);
    highlightedStream.addListener(_onHighlightChanged);
    _controller.loadingState.addListener(_onLoadingStateChanged);
  }

  void _onHighlightChanged() {
    if (widget.onHighlightTap != null && highlightedStream.value != null) {
      widget.onHighlightTap!(highlightedStream.value!);
    }
  }

  void _onLoadingStateChanged() {
    switch (_controller.loadingState.value) {
      case EpubViewLoadingState.loading:
        break;
      case EpubViewLoadingState.success:
        if (_controller.loadedDocument != null) {
          widget.onDocumentLoaded?.call(_controller.loadedDocument!);
        }
        break;
      case EpubViewLoadingState.error:
        widget.onDocumentError?.call(loadingError);
        break;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    highlightedStream.removeListener(_onHighlightChanged);
    _controller.loadingState.removeListener(_onLoadingStateChanged);
    itemPositionListener?.itemPositions.removeListener(_changeListener);
    _controller.detach();
    if (widget.paragraphIndexOnDispose != null && _controller.currentValue != null) {
      widget.paragraphIndexOnDispose!(_controller.currentValue!.paragraphNumber);
    }
    super.dispose();
  }

  Future<bool> initBook() async {
    if (_controller.isBookLoaded.value || _controller.loadedDocument == null) {
      return true;
    }
    final doc = _controller.loadedDocument!;
    final order = buildReadingOrder(doc);
    chapters = order.chapters;
    paragraphs = order.paragraphs;
    chapterIndexes.clear();
    chapterIndexes.addAll(order.chapterIndexes);
    tableOfContentsEntries = order.tableOfContents;
    final list = paragraphs.map((e) => e.element.outerHtml).toList();

    for (SelectedTextModel element in widget.replacedParagraphs ?? []) {
      if (element.paragraphIndex >= 0 && element.paragraphIndex < list.length) {
        list[element.paragraphIndex] = element.selectedText;
      }
    }

    paragraphList.value = list;

    epubCfiReader = EpubCfiReader.parser(
      cfiInput: _controller.epubCfi,
      chapters: chapters,
      paragraphs: paragraphs,
    );
    itemPositionListener!.itemPositions.addListener(_changeListener);
    _controller.isBookLoaded.value = true;

    return true;
  }

  void _changeListener() {
    if (paragraphs.isEmpty || itemPositionListener!.itemPositions.value.isEmpty) {
      return;
    }
    final position = itemPositionListener!.itemPositions.value.first;
    final chapterIndex = _getChapterIndexBy(
      positionIndex: position.index,
      trailingEdge: position.itemTrailingEdge,
      leadingEdge: position.itemLeadingEdge,
    );
    final paragraphIndex = getParagraphIndexBy(
      positionIndex: position.index,
      trailingEdge: position.itemTrailingEdge,
      leadingEdge: position.itemLeadingEdge,
    );
    _currentValue = EpubChapterViewValue(
      chapter: chapterIndex >= 0 && chapterIndex < chapters.length ? chapters[chapterIndex] : null,
      chapterNumber: chapterIndex + 1,
      paragraphNumber: paragraphIndex + 1,
      position: position,
    );
    _controller.currentValueListenable.value = _currentValue;
    widget.onChapterChanged?.call(_currentValue);
  }

  void gotoEpubCfi(
    String? epubCfi, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    epubCfiReader?.epubCfi = epubCfi;
    final index = epubCfiReader?.paragraphIndexByCfiFragment;

    if (index == null) {
      return;
    }

    itemScrollController?.scrollTo(
      index: index,
      duration: duration,
      alignment: alignment,
      curve: curve,
    );
  }

  void _onLinkPressed(String href) {
    if (href.contains('://')) {
      widget.onExternalLinkPressed?.call(href);
      return;
    }

    String? hrefIdRef;
    String? hrefFileName;

    if (href.contains('#')) {
      final dividedHref = href.split('#');
      if (dividedHref.length == 1) {
        hrefIdRef = href;
      } else {
        hrefFileName = dividedHref[0];
        hrefIdRef = dividedHref[1];
      }
    } else {
      hrefFileName = href;
    }

    if (hrefIdRef == null) {
      final chapter = _chapterByFileName(hrefFileName);
      if (chapter != null) {
        final cfi = epubCfiReader?.generateCfiChapter(
          book: _controller.loadedDocument,
          chapter: chapter,
          additional: ['/4/2'],
        );

        cfi?.then((val) {
          if (val != null) gotoEpubCfi(val);
        });
      }
      return;
    } else {
      final paragraph = _paragraphByIdRef(hrefIdRef);
      final chapter = paragraph != null && paragraph.chapterIndex < chapters.length
          ? chapters[paragraph.chapterIndex]
          : null;

      if (chapter != null && paragraph != null) {
        final paragraphIndex = epubCfiReader?.getParagraphIndexByElement(paragraph.element);
        final cfi = epubCfiReader?.generateCfi(
          book: _controller.loadedDocument,
          chapter: chapter,
          paragraphIndex: paragraphIndex,
        );

        cfi?.then((val) {
          if (val != null) gotoEpubCfi(val);
        });
      }

      return;
    }
  }

  Paragraph? _paragraphByIdRef(String idRef) => paragraphs.firstWhereOrNull((paragraph) {
        if (paragraph.element.id == idRef) {
          return true;
        }

        return paragraph.element.children.isNotEmpty &&
            paragraph.element.children[0].id == idRef;
      });

  EpubChapter? _chapterByFileName(String? fileName) => chapters.firstWhereOrNull((chapter) {
        if (fileName != null) {
          if (chapter.ContentFileName != null && chapter.ContentFileName!.contains(fileName)) {
            return true;
          }
        }
        return false;
      });

  int _getChapterIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    if (chapterIndexes.isEmpty) return 0;
    final posIndex = getAbsParagraphIndexBy(
      positionIndex: positionIndex,
      trailingEdge: trailingEdge,
      leadingEdge: leadingEdge,
    );
    final index = posIndex >= chapterIndexes.last
        ? chapterIndexes.length
        : chapterIndexes.indexWhere((chapterIndex) {
            if (posIndex < chapterIndex) {
              return true;
            }
            return false;
          });

    return index - 1;
  }

  int getParagraphIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    final posIndex = getAbsParagraphIndexBy(
      positionIndex: positionIndex,
      trailingEdge: trailingEdge,
      leadingEdge: leadingEdge,
    );

    final index = _getChapterIndexBy(positionIndex: posIndex);

    if (index == -1 || index >= chapterIndexes.length) {
      return posIndex;
    }

    return posIndex - chapterIndexes[index];
  }

  int getAbsParagraphIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    int posIndex = positionIndex;
    if (trailingEdge != null &&
        leadingEdge != null &&
        trailingEdge < _minTrailingEdge &&
        leadingEdge < _minLeadingEdge) {
      posIndex += 1;
    }

    return posIndex;
  }

  static List<Widget> _toolbarSelectionActions(
      EditableTextState state, List<Color> options, int index) {
    return [
      Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildHighlightColorButton(state, index, 'tgYellow', const Color(0xFFFFFF00)),
            _buildHighlightColorButton(state, index, 'tgCyan', const Color(0xFF00FFFF)),
            _buildHighlightColorButton(state, index, 'tgPink', const Color(0xFFFF69B4)),
            _buildHighlightColorButton(state, index, 'tgGreen', const Color(0xFF90EE90)),
            _buildHighlightColorButton(state, index, 'tgOrange', const Color(0xFFFFA07A)),
            _buildHighlightColorButton(state, index, 'tgLilac', const Color(0xFFDDA0DD)),
            Material(
              borderRadius: BorderRadius.circular(50),
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  final text = state.textEditingValue.selection.textInside(state.textEditingValue.text);
                  if (text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                  }
                  state.hideToolbar();
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            Material(
              borderRadius: BorderRadius.circular(50),
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: () {
                  applyHighlight(
                    state: state,
                    index: index,
                    tag: null,
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static Widget _buildHighlightColorButton(
      EditableTextState state, int index, String tag, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        borderRadius: BorderRadius.circular(50),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () {
            applyHighlight(
              state: state,
              index: index,
              tag: tag,
            );
          },
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 1),
            ),
          ),
        ),
      ),
    );
  }

  static TextAlign _resolveTextAlign(dynamic element, TextAlign fallback) {
    if (element == null) return fallback;
    final alignAttr = element.attributes['align']?.toString().toLowerCase().trim();
    if (alignAttr != null) {
      if (alignAttr == 'center') return TextAlign.center;
      if (alignAttr == 'right') return TextAlign.right;
      if (alignAttr == 'left') return TextAlign.left;
      if (alignAttr == 'justify') return TextAlign.justify;
    }
    final styleAttr = element.attributes['style']?.toString().toLowerCase();
    if (styleAttr != null && styleAttr.contains('text-align')) {
      if (styleAttr.contains('text-align: center') || styleAttr.contains('text-align:center')) {
        return TextAlign.center;
      }
      if (styleAttr.contains('text-align: right') || styleAttr.contains('text-align:right')) {
        return TextAlign.right;
      }
      if (styleAttr.contains('text-align: left') || styleAttr.contains('text-align:left')) {
        return TextAlign.left;
      }
      if (styleAttr.contains('text-align: justify') || styleAttr.contains('text-align:justify')) {
        return TextAlign.justify;
      }
    }
    final className = (element.className ?? '').toString().toLowerCase();
    if (className.contains('center')) return TextAlign.center;
    if (className.contains('right')) return TextAlign.right;
    if (className.contains('justify')) return TextAlign.justify;

    return fallback;
  }

  Widget _chapterBuilder(
    BuildContext context,
    EpubViewBuilders builders,
    EpubBook document,
    List<EpubChapter> chapters,
    List<Paragraph> paragraphs,
    int index,
    int chapterIndex,
    int paragraphIndex,
    ExternalLinkPressed onExternalLinkPressed,
  ) {
    if (paragraphs.isEmpty || index >= paragraphs.length) {
      return Container();
    }

    final options = builders.options;

    final paragraph = paragraphs[index];
    final hasText = paragraph.element.text.isNotEmpty;
    final hasImage = paragraph.element.outerHtml.contains('<img') ||
        paragraph.element.outerHtml.contains('<image');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chapterIndex >= 0 && chapterIndex < chapters.length && paragraphIndex == 0)
          builders.chapterDividerBuilder(chapters[chapterIndex]),
        if (hasText && !hasImage)
          Padding(
            padding: options.paragraphPadding as EdgeInsets? ?? EdgeInsets.zero,
            child: Stack(
              children: [
                ValueListenableBuilder<List<String>>(
                  valueListenable: paragraphList,
                  builder: (context, value, child) {
                    final rawHtml = index < value.length ? value[index] : paragraph.element.outerHtml;
                    var htmlText = HTML.toRichText(
                      context,
                      rawHtml,
                      defaultStyle: options.textStyle,
                    );
                    final resolvedAlign = _resolveTextAlign(paragraph.element, options.textAlign);
                    return SelectableText.rich(
                      TextSpan(
                        children: [htmlText.text],
                        style: options.textStyle,
                      ),
                      textAlign: resolvedAlign,
                      contextMenuBuilder: (_, EditableTextState state) {
                        return AdaptiveTextSelectionToolbar(
                          anchors: state.contextMenuAnchors,
                          children: (!state.textEditingValue.selection.isCollapsed)
                              ? _toolbarSelectionActions(
                                  state,
                                  options.toolbarSelectionActionsColor,
                                  index,
                                )
                              : [const Material(color: Colors.transparent)],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          )
        else
          Html(
            data: paragraph.element.outerHtml,
            onLinkTap: (href, context, element) {
              if (href != null) onExternalLinkPressed(href);
            },
            style: {
              'html': Style(
                padding: HtmlPaddings.only(
                  top: (options.paragraphPadding as EdgeInsets?)?.top,
                  right: (options.paragraphPadding as EdgeInsets?)?.right,
                  bottom: (options.paragraphPadding as EdgeInsets?)?.bottom,
                  left: (options.paragraphPadding as EdgeInsets?)?.left,
                ),
              ),
            },
            extensions: [
              TagExtension(
                tagsToExtend: {"img", "image"},
                builder: (imageContext) {
                  final srcAttr = imageContext.attributes['src'] ??
                      imageContext.attributes['xlink:href'] ??
                      imageContext.attributes['href'];
                  if (srcAttr == null || srcAttr.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final cleanedUrl = srcAttr.replaceAll('../', '').trim();
                  Uint8List? imageContent;

                  final imagesMap = document.Content?.Images;
                  if (imagesMap != null && imagesMap.isNotEmpty) {
                    if (imagesMap.containsKey(cleanedUrl)) {
                      imageContent = Uint8List.fromList(imagesMap[cleanedUrl]!.Content!);
                    } else {
                      final decodedUrl = Uri.decodeFull(cleanedUrl);
                      final baseName = path.basename(cleanedUrl);
                      for (final entry in imagesMap.entries) {
                        if (entry.key == decodedUrl ||
                            entry.key.endsWith(cleanedUrl) ||
                            path.basename(entry.key) == baseName) {
                          imageContent = Uint8List.fromList(entry.value.Content!);
                          break;
                        }
                      }
                    }
                  }

                  if (imageContent != null && imageContent.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            imageContent,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        if (index < paragraphs.length - 1) const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context) => ScrollablePositionedList.builder(
        scrollDirection: widget.scrollDirection,
        physics: widget.physics ?? (widget.scrollDirection == Axis.horizontal ? const PageScrollPhysics() : null),
        shrinkWrap: widget.shrinkWrap,
        initialScrollIndex: epubCfiReader?.paragraphIndexByCfiFragment ?? 0,
        itemCount: paragraphs.length,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionListener,
        itemBuilder: (BuildContext context, int index) => _chapterBuilder(
          context,
          widget.builders,
          _controller.loadedDocument!,
          chapters,
          paragraphs,
          index,
          _getChapterIndexBy(positionIndex: index),
          getParagraphIndexBy(positionIndex: index),
          _onLinkPressed,
        ),
      );

  @override
  Widget build(BuildContext context) => widget.builders.builder(
        context,
        widget.builders,
        _controller.loadingState.value,
        _buildLoaded,
        loadingError,
      );

  static void applyHighlight({
    required EditableTextState state,
    required String? tag,
    required int index,
  }) {
    if (index < 0 || index >= paragraphList.value.length) return;
    String paragraphText = paragraphList.value[index];
    final selectedStartIndex = state.textEditingValue.selection.start;
    final selectedEndIndex = state.textEditingValue.selection.end;

    final initialTagRegExp = RegExp(r'^<[^>]+>');
    final lastTagRegExp = RegExp(r'</[^>]+>$');

    final initialTagMatch = initialTagRegExp.firstMatch(paragraphText);
    final lastTagMatch = lastTagRegExp.firstMatch(paragraphText);

    final initialTag = initialTagMatch != null ? initialTagMatch.group(0)! : '';
    final lastTag = lastTagMatch != null ? lastTagMatch.group(0)! : '';

    paragraphText = paragraphText.replaceAll(initialTag, '').replaceAll(lastTag, '');

    final spanStartTagRegExp = RegExp(r'^<span [^>]+>');
    final spanEndTagRegExp = RegExp(r'</span>$');

    final spanStartTagMatch = spanStartTagRegExp.firstMatch(paragraphText);
    final spanEndTagMatch = spanEndTagRegExp.firstMatch(paragraphText);

    final spanStartTag = spanStartTagMatch != null ? spanStartTagMatch.group(0)! : '';
    final spanEndTag = spanEndTagMatch != null ? spanEndTagMatch.group(0)! : '';

    paragraphText = paragraphText.replaceAll(spanStartTag, '').replaceAll(spanEndTag, '');

    final htmlStartIndex = mapPlainTextIndexToHtmlIndex(
      paragraphText,
      selectedStartIndex,
    );
    final htmlEndIndex = mapPlainTextIndexToHtmlIndex(
      paragraphText,
      selectedEndIndex,
    );

    if (htmlStartIndex < 0 || htmlEndIndex > paragraphText.length || htmlStartIndex >= htmlEndIndex) {
      return;
    }

    final formattedText = existingColorTagFormat(
      beforeSelectedText: paragraphText.substring(0, htmlStartIndex),
      selectedText: paragraphText.substring(htmlStartIndex, htmlEndIndex),
      afterSelectedText: paragraphText.substring(htmlEndIndex),
      tag: tag,
    );

    final formattedParagraph = '$initialTag$spanStartTag$formattedText$spanEndTag$lastTag';

    if (html_parser.parse(formattedParagraph).outerHtml.isNotEmpty) {
      final newList = List<String>.from(paragraphList.value);
      newList[index] = formattedParagraph;
      paragraphList.value = newList;
      highlightedStream.value = SelectedTextModel(
        paragraphIndex: index,
        tag: tag,
        paragraphText: formattedParagraph,
        selectedText: state.textEditingValue.selection.textInside(
          state.textEditingValue.text,
        ),
      );
    }
  }

  static int mapPlainTextIndexToHtmlIndex(String html, int plainTextIndex) {
    int plainIndex = 0;
    int htmlIndex = 0;

    while (htmlIndex < html.length && plainIndex < plainTextIndex) {
      if (html[htmlIndex] == '<') {
        while (htmlIndex < html.length && html[htmlIndex] != '>') {
          htmlIndex++;
        }
        if (htmlIndex < html.length) htmlIndex++;
      } else {
        plainIndex++;
        htmlIndex++;
      }
    }

    return htmlIndex;
  }

  static String existingColorTagFormat({
    required String beforeSelectedText,
    required String selectedText,
    required String afterSelectedText,
    required String? tag,
  }) {
    String before = beforeSelectedText;
    String selected = selectedText;
    String after = afterSelectedText;

    final openTagRegExp = RegExp(r'<(tg(?:Yellow|Cyan|Pink|Green|Orange|Lilac))>');
    final closeTagRegExp = RegExp(r'</(tg(?:Yellow|Cyan|Pink|Green|Orange|Lilac))>');
    final fullTagRegExp = RegExp(r'<(tg(?:Yellow|Cyan|Pink|Green|Orange|Lilac))>(.*?)</\1>');

    while (after.startsWith(closeTagRegExp)) {
      final match = closeTagRegExp.firstMatch(after);
      if (match != null) {
        final matchTag = match.group(1);
        if (matchTag != null) {
          final closingTag = '</$matchTag>';
          after = after.substring(closingTag.length);
          selected = '$selected$closingTag';
        }
      }
    }

    while (fullTagRegExp.hasMatch(selected)) {
      final match = openTagRegExp.allMatches(selected).toList();
      for (var element in match) {
        final matchTag = element.group(1);
        if (matchTag != null) {
          selected = selected.replaceAll('<$matchTag>', '').replaceAll('</$matchTag>', '');
        }
      }
    }

    if (openTagRegExp.hasMatch(selected)) {
      final match = openTagRegExp.firstMatch(selected);
      final matchTag = match?.group(1);
      if (matchTag != null) {
        after = '<$matchTag>$after';
        selected = selected.replaceAll(match?.group(0) ?? '', '');
      }
    }

    if (closeTagRegExp.hasMatch(selected)) {
      final match = closeTagRegExp.firstMatch(selected);
      final matchTag = match?.group(1);
      if (matchTag != null) {
        before = '$before</$matchTag>';
        selected = selected.replaceAll(match?.group(0) ?? '', '');
      }
    }

    return tag != null
        ? '$before<$tag>$selected</$tag>$after'
        : '$before$selected$after';
  }
}
