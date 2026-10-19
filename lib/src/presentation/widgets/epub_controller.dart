import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/epub_view_chapter.dart';
import '../../data/parsers/epub_document.dart';
import 'epub_view_builders.dart';
import 'epub_content_view.dart';

class EpubController {
  Future<EpubBook> document;
  final String? epubCfi;

  EpubViewState? _epubViewState;
  List<EpubViewChapter>? _cacheTableOfContents;
  EpubBook? _document;

  EpubBook? get loadedDocument => _document;
  EpubChapterViewValue? get currentValue => _epubViewState?.currentValue;

  /// Paragraph items in the whole book (0 until loaded).
  int get paragraphCount => _epubViewState?.paragraphs.length ?? 0;

  final isBookLoaded = ValueNotifier<bool>(false);
  final ValueNotifier<EpubViewLoadingState> loadingState = ValueNotifier(EpubViewLoadingState.loading);
  final currentValueListenable = ValueNotifier<EpubChapterViewValue?>(null);
  final tableOfContentsListenable = ValueNotifier<List<EpubViewChapter>>([]);

  EpubController({required this.document, this.epubCfi});

  void jumpTo({required int index, double alignment = 0}) =>
      _epubViewState?.itemScrollController?.jumpTo(
        index: index,
        alignment: alignment,
      );

  Future<void>? scrollTo({
    required int index,
    Duration duration = const Duration(milliseconds: 250),
    double alignment = 0,
    Curve curve = Curves.linear,
  }) =>
      _epubViewState?.itemScrollController?.scrollTo(
        index: index,
        duration: duration,
        alignment: alignment,
        curve: curve,
      );

  void gotoEpubCfi(
    String epubCfi, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    _epubViewState?.gotoEpubCfi(
      epubCfi,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
  }

  /// Turn forward by one section/paragraph smoothly
  void next({
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) {
    final state = _epubViewState;
    if (state == null || state.paragraphs.isEmpty) return;
    final positions = state.itemPositionListener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return;
    final current = positions.first.index;
    final nextIndex = (current + 1).clamp(0, state.paragraphs.length - 1);
    state.itemScrollController?.scrollTo(
      index: nextIndex,
      duration: duration,
      curve: curve,
    );
  }

  /// Turn backward by one section/paragraph smoothly
  void prev({
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) {
    final state = _epubViewState;
    if (state == null || state.paragraphs.isEmpty) return;
    final positions = state.itemPositionListener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return;
    final current = positions.first.index;
    final prevIndex = (current - 1).clamp(0, state.paragraphs.length - 1);
    state.itemScrollController?.scrollTo(
      index: prevIndex,
      duration: duration,
      curve: curve,
    );
  }

  Future<String?>? generateEpubCfi() =>
      _epubViewState?.epubCfiReader?.generateCfi(
        book: _document,
        chapter: _epubViewState?.currentValue?.chapter,
        paragraphIndex: _epubViewState?.getAbsParagraphIndexBy(
          positionIndex: _epubViewState?.currentValue?.position.index ?? 0,
          trailingEdge: _epubViewState?.currentValue?.position.itemTrailingEdge,
          leadingEdge: _epubViewState?.currentValue?.position.itemLeadingEdge,
        ),
      );

  /// The book's TOC with each entry's start paragraph, as computed by
  /// buildReadingOrder. Empty until the view has attached and loaded.
  List<EpubViewChapter> tableOfContents() {
    if (_cacheTableOfContents != null) {
      return _cacheTableOfContents!;
    }
    final entries = _epubViewState?.tableOfContentsEntries;
    if (entries == null || entries.isEmpty) {
      return [];
    }
    return _cacheTableOfContents = List.unmodifiable(entries);
  }

  Future<void> loadDocument(Future<EpubBook> document) {
    this.document = document;
    return _loadDocument(document);
  }

  Future<void> loadDocumentFromPath(String filePath) async {
    try {
      var file = File(filePath);
      var epubBook = await EpubDocument.openFile(file);
      loadDocument(Future.value(epubBook));
    } catch (e) {
      debugPrint("Failed to load document: $e");
    }
  }

  Future<void> loadDocumentFromBytes(Uint8List bytes) async {
    try {
      var epubBook = await EpubDocument.openData(bytes);
      loadDocument(Future.value(epubBook));
    } catch (e) {
      debugPrint("Failed to load document from bytes: $e");
    }
  }

  void dispose() {
    _epubViewState = null;
    isBookLoaded.dispose();
    currentValueListenable.dispose();
    tableOfContentsListenable.dispose();
    loadingState.dispose();
  }

  Future<void> _loadDocument(Future<EpubBook> document) async {
    isBookLoaded.value = false;
    try {
      loadingState.value = EpubViewLoadingState.loading;
      _document = await document;
      if (_epubViewState != null) {
        await _epubViewState!.initBook();
      }
      tableOfContentsListenable.value = tableOfContents();
      loadingState.value = EpubViewLoadingState.success;
    } catch (error) {
      if (_epubViewState != null) {
        _epubViewState!.loadingError = error is Exception ? error : Exception('An unexpected error occurred: $error');
      }
      loadingState.value = EpubViewLoadingState.error;
    }
  }

  void attach(EpubViewState epubReaderViewState) {
    _epubViewState = epubReaderViewState;
    _loadDocument(document);
  }

  void detach() {
    _epubViewState = null;
  }
}
