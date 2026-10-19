import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sakura_epub/sakura_epub.dart';
import 'package:sakura_epub/src/utils.dart';

class EpubController {
  InAppWebViewController? webViewController;

  ///List of chapters from epub
  List<EpubChapter> _chapters = [];

  int _searchRequestId = 0;
  int _currentLocationRequestId = 0;

  int get activeSearchRequestId => _searchRequestId;
  int get activeLocationRequestId => _currentLocationRequestId;

  void setWebViewController(InAppWebViewController controller) {
    webViewController = controller;
  }

  void _cancelIfPending<T>(Completer<T> completer, String reason) {
    if (!completer.isCompleted) {
      completer.completeError(StateError(reason));
    }
  }

  ///Move epub view to specific area using Cfi string, XPath/XPointer, or chapter href
  void display({
    ///Cfi String, XPath/XPointer string, or chapter href of the desired location
    ///If the string starts with '/', it will be treated as XPath/XPointer
    required String cfi,
  }) {
    checkEpubLoaded();
    webViewController?.callAsyncJavaScript(
      functionBody: 'toCfi(cfi)',
      arguments: {'cfi': cfi},
    );
  }

  ///Moves to next page in epub view
  void next() {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'next()');
  }

  ///Moves to previous page in epub view
  void prev() {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'previous()');
  }

  Completer<EpubLocation> currentLocationCompleter =
      Completer<EpubLocation>();

  ///Returns current location of epub viewer
  Future<EpubLocation> getCurrentLocation() async {
    checkEpubLoaded();
    _cancelIfPending(currentLocationCompleter, 'Cancelled by new request');
    _currentLocationRequestId++;
    currentLocationCompleter = Completer<EpubLocation>();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'getCurrentLocation(requestId)',
      arguments: {'requestId': _currentLocationRequestId},
    );
    return await currentLocationCompleter.future;
  }

  ///Returns list of [EpubChapter] from epub,
  /// should be called after onChaptersLoaded callback, otherwise returns empty list
  List<EpubChapter> getChapters() {
    checkEpubLoaded();
    return _chapters;
  }

  Future<List<EpubChapter>> parseChapters() async {
    if (_chapters.isNotEmpty) return _chapters;

    checkEpubLoaded();

    final result = await webViewController!.evaluateJavascript(
      source: 'getChapters()',
    );

    _chapters = parseChapterList(result);
    return _chapters;
  }

  Future<EpubMetadata> getMetadata() async {
    checkEpubLoaded();
    final result = await webViewController!.evaluateJavascript(
      source: 'getBookInfo()',
    );
    return EpubMetadata.fromJson(result);
  }

  Completer<List<EpubSearchResult>> searchResultCompleter =
      Completer<List<EpubSearchResult>>();

  ///Search in epub using query string
  ///Returns a list of [EpubSearchResult]
  Future<List<EpubSearchResult>> search({
    ///Search query string
    required String query,
    // bool optimized = false,
  }) async {
    if (query.isEmpty) return [];
    checkEpubLoaded();
    _cancelIfPending(searchResultCompleter, 'Cancelled by new request');
    _searchRequestId++;
    searchResultCompleter = Completer<List<EpubSearchResult>>();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'searchInBook(query, requestId)',
      arguments: {'query': query, 'requestId': _searchRequestId},
    );
    return await searchResultCompleter.future;
  }

  ///Adds a highlight to epub viewer
  void addHighlight({
    ///Cfi string of the desired location
    required String cfi,

    ///Color of the highlight
    Color color = Colors.yellow,

    ///Opacity of the highlight
    double opacity = 0.3,
  }) {
    var colorHex = color.toHex();
    var opacityString = opacity.toString();
    checkEpubLoaded();
    webViewController?.callAsyncJavaScript(
      functionBody: 'addHighlight(cfi, colorHex, opacity)',
      arguments: {
        'cfi': cfi,
        'colorHex': colorHex,
        'opacity': opacityString,
      },
    );
  }

  ///Adds a underline annotation
  void addUnderline({required String cfi}) {
    checkEpubLoaded();
    webViewController?.callAsyncJavaScript(
      functionBody: 'addUnderLine(cfi)',
      arguments: {'cfi': cfi},
    );
  }

  ///Adds a mark annotation
  // addMark({required String cfi}) {
  //   checkEpubLoaded();
  //   webViewController?.evaluateJavascript(source: 'addMark("$cfi")');
  // }

  ///Removes a highlight from epub viewer
  void removeHighlight({required String cfi}) {
    checkEpubLoaded();
    webViewController?.callAsyncJavaScript(
      functionBody: 'removeHighlight(cfi)',
      arguments: {'cfi': cfi},
    );
  }

  ///Removes a underline from epub viewer
  void removeUnderline({required String cfi}) {
    checkEpubLoaded();
    webViewController?.callAsyncJavaScript(
      functionBody: 'removeUnderLine(cfi)',
      arguments: {'cfi': cfi},
    );
  }

  ///Removes a mark from epub viewer
  // removeMark({required String cfi}) {
  //   checkEpubLoaded();
  //   webViewController?.evaluateJavascript(source: 'removeMark("$cfi")');
  // }

  ///Clears any active text selection in the epub viewer
  void clearSelection() {
    checkEpubLoaded();
    webViewController?.callAsyncJavaScript(functionBody: 'clearSelection()');
  }

  ///Set [EpubSpread] value
  Future<void> setSpread({required EpubSpread spread}) async {
    checkEpubLoaded();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'setSpread(spread)',
      arguments: {'spread': spread.name},
    );
  }

  ///Set [EpubFlow] value
  Future<void> setFlow({required EpubFlow flow}) async {
    checkEpubLoaded();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'setFlow(flow)',
      arguments: {'flow': flow.name},
    );
  }

  ///Set [EpubManager] value
  Future<void> setManager({required EpubManager manager}) async {
    checkEpubLoaded();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'setManager(manager)',
      arguments: {'manager': manager.name},
    );
  }

  ///Adjust font size in epub viewer
  Future<void> setFontSize({required double fontSize}) async {
    checkEpubLoaded();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'setFontSize(fontSize)',
      arguments: {'fontSize': fontSize},
    );
  }

  ///Set font family in epub viewer.
  ///[fontBase64] is the base64-encoded font file (ttf/otf).
  ///[fontMimeType] defaults to 'font/truetype' for ttf, use 'font/opentype' for otf.
  Future<void> setFontFamily({
    required String fontFamily,
    String? fontBase64,
    String fontMimeType = 'font/truetype',
  }) async {
    checkEpubLoaded();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'setFontFamily(fontFamily, fontBase64, fontMimeType)',
      arguments: {
        'fontFamily': fontFamily,
        'fontBase64': fontBase64 ?? '',
        'fontMimeType': fontMimeType,
      },
    );
  }

  Future<void> updateTheme({required EpubTheme theme}) async {
    checkEpubLoaded();
    String? foregroundColor = theme.foregroundColor?.toHex();
    String? backgroundColor;
    final bgDecoration = theme.backgroundDecoration;
    if (bgDecoration is BoxDecoration && bgDecoration.color != null) {
      backgroundColor = bgDecoration.color!.toHex();
    }
    final customCss = theme.customCss;
    await webViewController?.callAsyncJavaScript(
      functionBody: 'updateTheme(backgroundColor, foregroundColor, customCss)',
      arguments: {
        'backgroundColor': backgroundColor,
        'foregroundColor': foregroundColor,
        'customCss': customCss,
      },
    );
  }

  Completer<EpubTextExtractRes>? _pageTextCompleter;
  Completer<Rect?> cfiRectCompleter = Completer<Rect?>();

  /// Safely complete the page text completer
  void completePageText(EpubTextExtractRes result) {
    if (_pageTextCompleter != null && !_pageTextCompleter!.isCompleted) {
      _pageTextCompleter!.complete(result);
    }
  }

  ///Extract text from a given cfi range,
  Future<EpubTextExtractRes> extractText({
    ///start cfi
    required String startCfi,

    ///end cfi
    required String endCfi,
  }) async {
    checkEpubLoaded();
    // Complete previous completer if it exists and isn't completed
    if (_pageTextCompleter != null && !_pageTextCompleter!.isCompleted) {
      try {
        _pageTextCompleter!.completeError('Cancelled by new request');
      } catch (e) {
        // Ignore if already completed
      }
    }
    _pageTextCompleter = Completer<EpubTextExtractRes>();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'getTextFromCfi(startCfi, endCfi)',
      arguments: {'startCfi': startCfi, 'endCfi': endCfi},
    );
    return _pageTextCompleter!.future;
  }

  ///Get bounding rectangle for a given CFI range
  ///Returns WebView-relative coordinates in pixels, or null if rect cannot be determined
  Future<Rect?> getRectFromCfi(String cfiRange) async {
    checkEpubLoaded();
    cfiRectCompleter = Completer<Rect?>();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'getRectFromCfi(cfiRange)',
      arguments: {'cfiRange': cfiRange},
    );
    return cfiRectCompleter.future;
  }

  ///Extracts text content from current page
  Future<EpubTextExtractRes> extractCurrentPageText() async {
    checkEpubLoaded();
    // Complete previous completer if it exists and isn't completed
    if (_pageTextCompleter != null && !_pageTextCompleter!.isCompleted) {
      try {
        _pageTextCompleter!.completeError('Cancelled by new request');
      } catch (e) {
        // Ignore if already completed
      }
    }
    _pageTextCompleter = Completer<EpubTextExtractRes>();
    await webViewController?.callAsyncJavaScript(
      functionBody: 'getCurrentPageText()',
    );
    return _pageTextCompleter!.future;
  }

  ///Given a percentage moves to the corresponding page
  ///Progress percentage should be between 0.0 and 1.0
  void toProgressPercentage(double progressPercent) {
    assert(
      progressPercent >= 0.0 && progressPercent <= 1.0,
      'Progress percentage must be between 0.0 and 1.0',
    );
    checkEpubLoaded();
    webViewController?.callAsyncJavaScript(
      functionBody: 'toProgress(progressPercent)',
      arguments: {'progressPercent': progressPercent},
    );
  }

  ///Moves to the first page of the epub
  void moveToFistPage() {
    toProgressPercentage(0.0);
  }

  ///Moves to the last page of the epub
  void moveToLastPage() {
    toProgressPercentage(1.0);
  }

  ///Moves to the first page of the epub
  void moveToFirstPage() {
    toProgressPercentage(0.0);
  }

  void checkEpubLoaded() {
    if (webViewController == null) {
      throw Exception(
        "Epub viewer is not loaded, wait for onEpubLoaded callback",
      );
    }
  }
}
