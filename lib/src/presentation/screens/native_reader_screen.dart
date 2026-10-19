import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/commands/reader_command.dart';
import '../../application/mappers/native_locator_mapper.dart';
import '../../application/mappers/sakura_epub_mapper.dart';
import '../../application/session/reading_session.dart';
import '../../data/repositories/sqlite_reader_preferences_repository.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/locator.dart';
import '../../domain/entities/nav_item.dart';
import '../../domain/entities/reader_preferences.dart';
import '../native_reader/native_reader_engine.dart';
import '../native_reader/renderer_choice.dart';
import 'sakura_reader_screen.dart';
import '../platform/app_haptics.dart';
import '../state/app_preferences.dart';
import '../state/reader_usage_mixin.dart';
import '../state/library_controller.dart';
import '../../core/constants/asset_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/app_chrome.dart';
import '../widgets/native_search_sheet.dart';
import '../widgets/page_curl.dart';
import '../widgets/reader_page_skeleton.dart';
import '../widgets/sakura_customization_sheet.dart';
import '../widgets/sakura_toc_sheet.dart';
import '../widgets/word_definition_sheet.dart';
import '../../data/dictionary/dictionary_service.dart';

/// Book view for Android on the native PageEngine (Kotlin, `:reader` module).
///
/// Same screen as [SakuraReaderScreen] - header, footer, scrubber, zoomed page strip, page curl,
/// sheets, selection menu, gestures, saving - but pages are images drawn by the native engine
/// instead of a WebView running epub.js. Flutter owns every gesture and animation; the engine
/// answers "what's on this page / where is this text" over the `fourpages/native_reader`
/// channel. Saving goes through the same [ReadingSession] as every other reader.
class NativeReaderScreen extends StatefulWidget {
  final BookItem book;
  final Locator? initialLocator;

  const NativeReaderScreen({super.key, required this.book, this.initialLocator});

  @override
  State<NativeReaderScreen> createState() => _NativeReaderScreenState();
}

class _SelectionMenuState {
  final String selectedText;
  /// `r:start:end` of the selection (kept under the old name the menu code uses).
  final String cfiRange;
  final Rect selectionRect;
  const _SelectionMenuState({
    required this.selectedText,
    required this.cfiRange,
    required this.selectionRect,
  });
}

/// One page turn in progress (paginated mode), drawn as a page curl.
class _PageTurn {
  /// 1 = next page, -1 = previous page.
  final int dir;
  final double tilt;
  _PageTurn(this.dir, this.tilt);

  /// The page doing the curling, and the one lying under it. Owned by the page cache.
  ui.Image? front;
  ui.Image? back;

  /// Where the turn goes (null = no page there: start/end of the book).
  NativePage? target;

  /// Finger offset from where the drag started, logical px.
  double dx = 0;
  double velocity = 0;

  bool ready = false;
  bool released = false;
  bool moved = false;
}

class _NativeReaderScreenState extends State<NativeReaderScreen>
    with ReaderUsageMixin, SingleTickerProviderStateMixin {
  @override
  BookItem get usageBook => widget.book;

  late final ReadingSession _session;
  late ReaderPreferences _preferences;
  NativeReaderEngine? _engine;
  String? _openError;
  StreamSubscription<NativePageIndex>? _indexSub;

  // The page on screen and its image; neighbours and recent pages are cached as images.
  NativePage? _page;
  ui.Image? _pageImage;
  NativeLocator? _lastLocator;
  NativePage? _locatorPage; // the page _lastLocator describes
  Size _openedPx = Size.zero;
  final Map<NativePage, Future<ui.Image>> _images = {};
  // Finished images, for drawing without waiting a frame.
  final Map<NativePage, ui.Image> _ready = {};
  final List<NativePage> _imageOrder = [];
  static const _imageCacheSize = 9;
  // Known neighbours (null value = no page there: start/end of the book).
  final Map<NativePage, NativePage?> _nextOf = {};
  final Map<NativePage, NativePage?> _prevOf = {};
  int _generation = 0; // bumped when settings change; stale renders are dropped
  Size _pagePx = Size.zero;
  Size? _lastPageArea;

  bool _epubReady = false;
  bool _loadTimedOut = false;
  bool _topVisible = false;
  bool _bottomVisible = false;
  bool get _controlsVisible => _topVisible || _bottomVisible;
  Timer? _topHideTimer;
  Timer? _bottomHideTimer;
  Timer? _loadTimeoutTimer;
  static const _topAutoHide = Duration(seconds: 3);
  static const _bottomAutoHide = Duration(seconds: 5);
  double _progress = 0.0;

  double? _seekPreview;
  bool _locationsReady = false;

  // Scrolled mode: position in the chapter (0..1, -1 unknown) and visible share.
  final _chapterScrollN = ValueNotifier<(double, double)>((-1, 1));
  double get _chapterScroll => _chapterScrollN.value.$1;
  double get _chapterVisible => _chapterScrollN.value.$2;
  set _chapterScroll(double v) => _chapterScrollN.value = (v, _chapterVisible);
  bool _draggingScrollLine = false;

  double _brightness = 1.0;
  List<NavItem> _toc = [];
  _SelectionMenuState? _selectionMenu;
  NativeSelection? _selection;
  Offset? _selectionAnchor; // page px of the fixed end while extending

  Timer? _positionSaveDebounce;
  Timer? _scrollDebounceTimer;
  double _accumulatedScrollDelta = 0;

  // Chapter lock-swipe (scrolled mode).
  int _swipeDir = 0;
  double _swipeProgress = 0;
  bool _swipeAvailable = true;
  bool _swipeArmed = false;

  // Page curl (paginated mode).
  _PageTurn? _turn;
  final _turnEdgeN = ValueNotifier<double>(0);
  double get _turnEdge => _turnEdgeN.value;
  set _turnEdge(double v) => _turnEdgeN.value = v;
  late final AnimationController _turnAnim;
  ui.FragmentProgram? _curlProgram;
  double _pageWidth = 360;

  int _pagesLeft = -1;
  static const double _footerHeight = 28;

  // Zoomed-out page strip: previous/current/next page images.
  bool _zoomed = false;
  bool _zoomShrunk = false;
  bool _stripBusy = false;
  int _zoomSession = 0;
  PageController? _stripController;
  static const _zoomDuration = Duration(milliseconds: 260);
  Map<String, dynamic>? _chapterInfo;
  final _chapterDragN = ValueNotifier<double>(0);
  static const double _chapterDragCommit = 70;
  final Set<int> _stripPending = {};
  static const double _stripScale = 0.62;
  double get _stripViewportFraction => _stripScale + 0.08;

  // Scrolled mode: the chapter's slices.
  ScrollController? _scrollController;
  int _scrollChapter = -1;
  List<double> _tileHeights = const []; // logical px
  final Map<int, Future<ui.Image>> _tileImages = {};
  final Map<int, ui.Image> _tileReady = {};
  double _overscroll = 0;

  String? _defineWord;
  Future<WordDefinition>? _defineLookup;

  // Saved highlights/notes: annotation id → resolved range (old CFI ones resolved once).
  final Map<String, NativeHighlight> _highlights = {};
  final Set<String> _unplaceable = {};

  static const _highlightColors = <String, Color>{
    '#FFEB3B': Color(0xFFFFEB3B), // yellow
    '#4CAF50': Color(0xFF4CAF50), // green
    '#F44336': Color(0xFFF44336), // red
    '#2196F3': Color(0xFF2196F3), // blue
    '#9C27B0': Color(0xFF9C27B0), // purple
  };

  bool get _paginated => _preferences.scrollMode == ScrollMode.paginated;

  /// The theme pages are shown in (the book's, or the app's with "Dynamic book background").
  ReaderTheme get _theme => AppPreferences.instance.effectiveReaderTheme(_preferences.theme);

  // What the page was last laid out with, to notice app theme / setting changes from outside.
  String? _appliedLook;
  String get _look => '${_theme.name}|$_padding';

  void _onAppLook() {
    if (!mounted || _engine == null) return;
    final look = _look;
    if (look == _appliedLook) return;
    _appliedLook = look;
    setState(() {});
    _applyPreferencesLive(_preferences);
  }
  final _topBarKey = GlobalKey();
  bool _shownOnOpen = false;

  @override
  void initState() {
    super.initState();
    _session = widget.book.session;
    _preferences = _session.state.preferences;
    _progress = widget.book.progress.clamp(0.0, 1.0);
    _turnAnim = AnimationController(vsync: this);
    PageCurl.program().then((p) {
      if (mounted) _curlProgram = p;
    });
    _loadTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && !_epubReady) setState(() => _loadTimedOut = true);
    });
    AppThemeController.instance.addListener(_onAppLook);
    AppPreferences.instance.addListener(_onAppLook);
  }

  /// A book nobody has customised yet opens with today's defaults (they follow the app theme).
  Future<void> _useCurrentDefaultsIfUnsaved() async {
    try {
      final saved = await SqliteReaderPreferencesRepository().hasSavedPreferences(widget.book.publication.id);
      if (!saved && mounted) _preferences = AppPreferences.instance.readerDefaults;
    } catch (e) {
      debugPrint('NativeReader: could not check saved preferences: $e');
    }
  }

  double get _padding => AppPreferences.instance.readerPadding.clamp(12.0, 48.0);

  /// Hands the book to the original-layout (WebView) reader, keeping the place.
  Future<void> _switchToOriginal({String? notice}) async {
    final loc = _lastLocator;
    if (loc != null) {
      _positionSaveDebounce?.cancel();
      await _session.dispatchCommand(NavigateToLocatorCommand(NativeLocatorMapper.toLocator(loc)));
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SakuraReaderScreen(book: widget.book, initialLocator: widget.initialLocator)),
    );
    if (notice != null) messenger.showSnackBar(SnackBar(content: Text(notice)));
  }

  Future<void> _open(Size pagePx) async {
    // Chosen per book: straight to the original layout, no native layout at all.
    if (await RendererChoice.get(widget.book.publication.id) == RendererChoice.original) {
      if (mounted) _switchToOriginal();
      return;
    }
    try {
      final file = await LibraryController.instance.ensureBookFileOnDisk(
        widget.book.publication.id,
        widget.book.archiveBytes,
      );
      await _useCurrentDefaultsIfUnsaved();
      final prefs = await NativePrefs.from(_preferences, padding: _padding);
      final start = NativeLocatorMapper.startFor(widget.initialLocator ?? _session.state.currentLocator);
      final engine = await NativeReaderEngine.open(path: file.path, prefs: prefs, pagePx: pagePx, start: start);
      if (!mounted) {
        engine.close();
        return;
      }
      if (engine.renderer == RendererChoice.original &&
          await RendererChoice.get(widget.book.publication.id) != RendererChoice.native) {
        // RendererPolicy: this book needs its original layout (spec §5.3).
        engine.close();
        if (mounted) _switchToOriginal(notice: l10n.openedInOriginalLayout);
        return;
      }
      _engine = engine;
      _appliedLook = _look;
      if (engine.lastIndex != null) _locationsReady = true;
      _toc = engine.toc;
      _indexSub = engine.pageIndex.listen((_) => _onPageIndex());
      _openedPx = pagePx;
      await _showPage(engine.firstPage, save: false);
      if (!mounted) return;
      // Old highlights resolve after the first page is up.
      _syncHighlights();
      // Rotated while opening: lay out for the size the page has now.
      if (_pagePx != _openedPx) _queueRelayout();
      _loadTimeoutTimer?.cancel();
      setState(() {
        _epubReady = true;
        _loadTimedOut = false;
      });
      // Open with the controls showing (page zoomed out), as before.
      if (!_shownOnOpen) {
        _shownOnOpen = true;
        _setControls(true);
      }
    } catch (e) {
      debugPrint('NativeReader: open failed: $e');
      if (mounted) setState(() => _openError = '$e');
    }
  }

  /// The exact page count arrived (or changed): refresh percentages and pages left.
  Future<void> _onPageIndex() async {
    if (!mounted) return;
    if (!_locationsReady) setState(() => _locationsReady = true);
    if (_relayingOut) return; // the relayout reports the new place itself
    final page = _page;
    if (page != null) await _relocate(page, save: false);
  }

  // --- pages ------------------------------------------------------------------------------------

  Future<ui.Image> _imageFor(NativePage p) {
    final cached = _images[p];
    if (cached != null) {
      _imageOrder
        ..remove(p)
        ..add(p);
      return cached;
    }
    final gen = _generation;
    final future = _engine!.render(p);
    _images[p] = future;
    _imageOrder.add(p);
    future.then((i) {
      if (gen == _generation && identical(_images[p], future)) _ready[p] = i;
    }, onError: (Object _) {
      _images.remove(p);
    });
    while (_imageOrder.length > _imageCacheSize) {
      final old = _imageOrder.removeAt(0);
      _ready.remove(old);
      final img = _images.remove(old);
      // Free it once nothing on screen can still be drawing it.
      if (img != null) {
        img.then((i) => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isOnScreen(i)) i.dispose();
            }));
      }
    }
    return future;
  }

  bool _isOnScreen(ui.Image i) =>
      identical(i, _pageImage) ||
      _stripAt.keys.any((k) => identical(_stripImage(k), i)) ||
      identical(_turn?.front, i) ||
      identical(_turn?.back, i);

  /// Page images only (scrolled-mode slices stay until replaced).
  void _dropPageImages() {
    final old = [..._ready.values];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final i in old) {
        if (!_isOnScreen(i)) i.dispose();
      }
    });
    _images.clear();
    _ready.clear();
    _imageOrder.clear();
    _nextOf.clear();
    _prevOf.clear();
  }

  void _dropImages() {
    final old = [..._ready.values, ..._tileReady.values];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final i in old) {
        if (!_isOnScreen(i)) i.dispose();
      }
    });
    _images.clear();
    _ready.clear();
    _imageOrder.clear();
    _nextOf.clear();
    _prevOf.clear();
    _tileImages.clear();
    _tileReady.clear();
  }

  /// The page [dir] away from [p] (cached after the first ask).
  Future<NativePage?> _neighbour(NativePage p, int dir) async {
    final known = dir > 0 ? _nextOf : _prevOf;
    if (known.containsKey(p)) return known[p];
    final gen = _generation;
    final n = await _engine!.step(p, dir);
    if (gen == _generation) {
      known[p] = n;
      if (n != null) (dir > 0 ? _prevOf : _nextOf)[n] = p;
    }
    return n;
  }

  /// Shows [p], reports its position, saves it (debounced) and prefetches its neighbours.
  Future<void> _showPage(NativePage p, {bool save = true}) async {
    final engine = _engine;
    if (engine == null) return;
    final gen = _generation;
    final image = await _imageFor(p);
    if (!mounted || gen != _generation) return;
    setState(() {
      _page = p;
      _pageImage = image;
      _pageImageStale = false;
    });
    await _relocate(p, save: save);
    _prefetch(p);
  }

  Future<void> _relocate(NativePage p, {required bool save}) async {
    final engine = _engine;
    if (engine == null) return;
    final NativeLocator loc;
    try {
      loc = await engine.locator(p);
    } catch (e) {
      return; // a relayout replaced the layout meanwhile
    }
    if (!mounted || _page != p) return;
    _locatorPage = p;
    setState(() {
      _lastLocator = loc;
      if (_locationsReady) _progress = loc.totalProgression;
      _pagesLeft = loc.pagesLeft ?? -1;
    });
    if (save) {
      _positionSaveDebounce?.cancel();
      _positionSaveDebounce = Timer(const Duration(milliseconds: 600), () => _savePosition(loc));
    }
  }

  void _savePosition(NativeLocator loc) {
    var locator = NativeLocatorMapper.toLocator(loc);
    if (!_locationsReady) {
      // Page count not known yet: keep the saved percentage instead of an estimate.
      locator = locator.copyWith(
        locations: LocationParameters(
          progression: loc.progression,
          totalProgression: _progress,
          charOffset: loc.charOffset,
        ),
      );
    }
    _session.dispatchCommand(NavigateToLocatorCommand(locator));
  }

  /// Renders the pages around [p] ahead of time (two each way paginated, so turns and the zoomed
  /// strip never wait). Scrolled mode draws slices instead, so nothing here.
  Future<void> _prefetch(NativePage p) async {
    if (_engine == null || !_paginated) return;
    try {
      for (final dir in [1, -1]) {
        var at = p;
        for (var k = 0; k < 2; k++) {
          if (!mounted || _page != p) return;
          final n = await _neighbour(at, dir);
          if (n == null || !mounted) break;
          await _imageFor(n);
          at = n;
        }
      }
    } catch (_) {
      // Layout replaced meanwhile; the next page shown prefetches again.
    }
  }

  Future<void> _goTo(Future<NativePage> where) async {
    _clearSelection();
    final p = await where;
    if (!mounted) return;
    await _showPage(p);
    if (!_paginated) _syncScrolledChapter(p, jump: true);
    if (_zoomed) _refreshStrip(_zoomSession);
  }

  // --- controls ---------------------------------------------------------------------------------

  void _toggleControls() => _setControls(!_controlsVisible);

  void _setControls(bool visible) {
    if (!mounted) return;
    setState(() {
      _topVisible = visible;
      _bottomVisible = visible;
    });
    if (visible) {
      _enterZoom();
      _scheduleAutoHide();
    } else {
      _exitZoom();
      _topHideTimer?.cancel();
      _bottomHideTimer?.cancel();
    }
  }

  void _scheduleAutoHide() {
    _topHideTimer?.cancel();
    _bottomHideTimer?.cancel();
    if (_topVisible) _topHideTimer = Timer(_topAutoHide, () => _autoHide(top: true));
    if (_bottomVisible) _bottomHideTimer = Timer(_bottomAutoHide, () => _autoHide(top: false));
  }

  void _onUserActivity() {
    if (_controlsVisible) _scheduleAutoHide();
  }

  void _autoHide({required bool top}) {
    if (!mounted) return;
    final busy = !(ModalRoute.of(context)?.isCurrent ?? true) ||
        _seekPreview != null ||
        _draggingScrollLine ||
        _stripBusy ||
        _zoomed ||
        _selectionMenu != null;
    if (busy) {
      final retry = Timer(const Duration(seconds: 1), () => _autoHide(top: top));
      if (top) {
        _topHideTimer = retry;
      } else {
        _bottomHideTimer = retry;
      }
      return;
    }
    setState(() {
      if (top) {
        _topVisible = false;
      } else {
        _bottomVisible = false;
      }
    });
    if (!_controlsVisible) _exitZoom();
  }

  @override
  void dispose() {
    AppThemeController.instance.removeListener(_onAppLook);
    AppPreferences.instance.removeListener(_onAppLook);
    _topHideTimer?.cancel();
    _bottomHideTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    // Leaving within the save debounce must not drop the last position.
    if (_positionSaveDebounce?.isActive ?? false) {
      _positionSaveDebounce!.cancel();
      final loc = _lastLocator;
      if (loc != null) _savePosition(loc);
    }
    _scrollDebounceTimer?.cancel();
    _indexSub?.cancel();
    final engine = _engine;
    final page = _page;
    if (engine != null && page != null && page != _locatorPage) {
      // Left right after a page turn: save that page, then close.
      engine.locator(page).then(_savePosition, onError: (Object _) {}).whenComplete(engine.close);
    } else {
      engine?.close();
    }
    _turnAnim.dispose();
    _turnEdgeN.dispose();
    _chapterDragN.dispose();
    _chapterScrollN.dispose();
    _stripController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  void _seekTo(double fraction) {
    _onUserActivity();
    setState(() => _seekPreview = null);
    final engine = _engine;
    if (engine == null || !_locationsReady) return;
    _goTo(engine.atProgression(fraction.clamp(0.0, 1.0)));
  }

  // --- selection --------------------------------------------------------------------------------

  double get _dpr => MediaQuery.of(context).devicePixelRatio;
  Offset _toPx(Offset logical) => logical * _dpr;
  Rect _toLogical(Rect px) => Rect.fromLTRB(px.left / _dpr, px.top / _dpr, px.right / _dpr, px.bottom / _dpr);

  Future<void> _selectWordAt(Offset local) async {
    final engine = _engine;
    final page = _page;
    if (engine == null || page == null || _turn != null) return;
    final sel = await engine.wordAt(page, _toPx(local));
    if (!mounted || sel == null) return;
    AppHaptics.tick();
    _selectionAnchor = null;
    _applySelection(sel, map: _toLogical);
  }

  /// Extends the selection: one end fixed, the other under the finger (page px).
  Future<void> _extendSelection(Offset fixedPx, Offset localMoving) async {
    final engine = _engine;
    final page = _page;
    if (engine == null || page == null) return;
    final sel = await engine.rangeBetween(page, fixedPx, _toPx(localMoving));
    if (!mounted || sel == null) return;
    _applySelection(sel, showMenu: !_pressing && !_handleDragging);
  }

  /// Page px → page-area logical rects for the current selection (paginated: plain scale).
  Rect Function(Rect)? _selectionMap;

  void _applySelection(NativeSelection sel, {bool showMenu = true, Rect Function(Rect)? map}) {
    if (map != null) _selectionMap = map;
    final toView = map ?? _selectionMap ?? _toLogical;
    final text = sel.text;
    final word = DictionaryService.wordFrom(text);
    final trimmed = text.trim().replaceAll(RegExp(r'[^\p{L}]+$', unicode: true), '');
    final single = word != null && word.length >= trimmed.length;
    setState(() {
      _selection = sel;
      _selectionMenu = showMenu
          ? _SelectionMenuState(
              selectedText: text,
              cfiRange: '${sel.resourceIndex}:${sel.start}:${sel.end}',
              selectionRect: toView(sel.bounds),
            )
          : null;
      if (!single || !showMenu) {
        _defineWord = null;
        _defineLookup = null;
      } else if (word != _defineWord) {
        _defineWord = word;
        _defineLookup = DictionaryService.instance.define(word);
        _defineLookup!.ignore();
      }
    });
  }

  void _clearSelection() {
    if (_selection == null && _selectionMenu == null) return;
    _selectionMap = null;
    _scrollAnchor = null;
    setState(() {
      _selection = null;
      _selectionMenu = null;
      _defineWord = null;
      _defineLookup = null;
    });
  }

  ({int r, int start, int end}) _parseRange(String key) {
    final p = key.split(':').map(int.parse).toList();
    return (r: p[0], start: p[1], end: p[2]);
  }

  void _defineSelection(String text) {
    _clearSelection();
    final word = DictionaryService.wordFrom(text);
    if (word == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => WordDefinitionSheet(
        word: word,
        onSearchInBook: () {
          Navigator.of(sheetContext).pop();
          _searchSelection(word);
        },
      ),
    );
  }

  String? get _chapterHref => _lastLocator?.href;

  Future<void> _addHighlight(String rangeKey, String text, String colorHex, {String? note}) async {
    final r = _parseRange(rangeKey);
    final selHref = _selection?.href;
    final href = (selHref != null && selHref.isNotEmpty) ? selHref : _chapterHref;
    if (href == null) return;
    _clearSelection();
    // A range CFI too, so the original-layout reader shows this highlight.
    String? cfi;
    try {
      cfi = await _engine?.cfiRange(r.r, r.start, r.end);
    } catch (_) {}
    await _session.dispatchCommand(
      CreateAnnotationCommand(
        locator: NativeLocatorMapper.rangeLocator(href, r.start, r.end, text, cfi: cfi),
        textQuote: text,
        note: note,
        colorHex: colorHex,
        type: note == null ? AnnotationType.highlight : AnnotationType.note,
      ),
    );
    await _syncHighlights();
  }

  Future<void> _copySelection(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
    }
  }

  void _searchSelection(String text) {
    _clearSelection();
    _showSearchSheet(initialQuery: text);
  }

  Future<void> _shareSelection(String text) async {
    _clearSelection();
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _addNote(String rangeKey, String text) async {
    setState(() => _selectionMenu = null);
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheetSurface,
        title: Text(l10n.addNote, style: TextStyle(color: AppColors.fg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$text"',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 13, color: AppColors.textFaint, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 3,
              style: TextStyle(color: AppColors.fg),
              decoration: InputDecoration(hintText: l10n.writeANote, hintStyle: TextStyle(color: AppColors.fgFaint)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(noteController.text.trim()), child: Text(l10n.save)),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || note.isEmpty) {
      _clearSelection();
      return;
    }
    _addHighlight(rangeKey, text, '#FFEB3B', note: note);
  }

  /// Sends the saved highlights/notes to the engine (old CFI ones resolved once) and redraws.
  Future<void> _syncHighlights({bool render = true}) async {
    final engine = _engine;
    if (engine == null) return;
    final live = <String>{};
    for (final a in _session.state.annotations) {
      if (a.type != AnnotationType.highlight && a.type != AnnotationType.note) continue;
      live.add(a.id);
      if (_highlights.containsKey(a.id) || _unplaceable.contains(a.id)) continue;
      final color = NativeLocatorMapper.colorOf(a.colorHex);
      final range = NativeLocatorMapper.rangeOf(a);
      if (range != null) {
        _highlights[a.id] = NativeHighlight(a.id, href: range.href, start: range.start, end: range.end, color: color);
        continue;
      }
      try {
        final cfi = a.locator.locations.cfi ?? a.locator.href;
        final r = await engine.resolveLegacy(cfi, a.textQuote, a.locator.locations.progression);
        if (r != null && r.end > r.start) {
          _highlights[a.id] = NativeHighlight(a.id, resourceIndex: r.resourceIndex, start: r.start, end: r.end, color: color);
          // Migrated for good: saved with char offsets (old CFI kept) so it isn't resolved again.
          final href = await engine.chapterHref(r.resourceIndex);
          await _session.dispatchCommand(UpdateAnnotationCommand(_withAnnotation(
            a,
            locator: NativeLocatorMapper.rangeLocator(href, r.start, r.end, a.textQuote ?? '', cfi: cfi),
          )));
        } else {
          _unplaceable.add(a.id);
        }
      } catch (e) {
        debugPrint('NativeReader: highlight ${a.id} could not be placed: $e');
      }
    }
    _highlights.removeWhere((id, _) => !live.contains(id));
    await engine.setHighlights(_highlights.values.toList());
    if (!render || !mounted) return;
    _dropImages();
    final page = _page;
    if (page != null) await _showPage(page, save: false);
  }

  /// Tap on a highlight/note: a small menu by the finger - change its colour or remove it
  /// (removing can be undone from the bar that follows).
  Future<void> _onHighlightTapped(String id, Offset globalPosition) async {
    final match = _session.state.annotations.where((a) => a.id == id);
    if (match.isEmpty) return;
    final annotation = match.first;
    final size = MediaQuery.of(context).size;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy + 12,
        size.width - globalPosition.dx,
        size.height - globalPosition.dy,
      ),
      color: AppColors.popoverSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in _highlightColors.entries)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop('color:${e.key}'),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: e.key.toUpperCase() == annotation.colorHex.toUpperCase()
                          ? Border.all(color: AppColors.fg, width: 2)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'remove',
          height: 46,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.fgMuted),
              const SizedBox(width: 12),
              Text(l10n.removeHighlight, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fg)),
            ],
          ),
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      await _removeHighlight(annotation);
    } else if (choice.startsWith('color:')) {
      await _session.dispatchCommand(UpdateAnnotationCommand(_withAnnotation(annotation, colorHex: choice.substring(6))));
      _highlights.remove(annotation.id);
      await _syncHighlights();
    }
  }

  Annotation _withAnnotation(Annotation a, {String? colorHex, Locator? locator}) => Annotation(
        id: a.id,
        publicationId: a.publicationId,
        locator: locator ?? a.locator,
        textQuote: a.textQuote,
        textPrefix: a.textPrefix,
        textSuffix: a.textSuffix,
        note: a.note,
        colorHex: colorHex ?? a.colorHex,
        type: a.type,
        createdAt: a.createdAt,
        updatedAt: DateTime.now(),
      );

  Future<void> _removeHighlight(Annotation annotation) async {
    await _session.dispatchCommand(DeleteAnnotationCommand(annotation.id));
    await _syncHighlights();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.highlightRemoved),
        duration: const Duration(seconds: 6),
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.undo,
          textColor: AppColors.accentLime,
          onPressed: () async {
            // Same annotation back (same id), so the Saved list and notes are unchanged.
            await _session.dispatchCommand(UpdateAnnotationCommand(annotation));
            await _syncHighlights();
          },
        ),
      ),
    );
  }

  void _addBookmark() {
    final loc = _lastLocator;
    if (loc == null) return;
    _session.dispatchCommand(
      CreateBookmarkCommand(
        locator: NativeLocatorMapper.toLocator(loc),
        title: l10n.bookmarkAtPercent((_progress * 100).round()),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.bookmarkedCurrentLocation), backgroundColor: AppColors.accentLime),
    );
  }

  // --- taps & gestures --------------------------------------------------------------------------

  Future<void> _onPageTapUp(TapUpDetails d) async {
    _onUserActivity();
    if (_selection != null || _selectionMenu != null) {
      _clearSelection();
      return;
    }
    final engine = _engine;
    final page = _page;
    if (engine != null && page != null && _highlights.isNotEmpty) {
      final id = await engine.highlightAt(page, _toPx(d.localPosition));
      if (!mounted) return;
      if (id != null) {
        _onHighlightTapped(id, d.globalPosition);
        return;
      }
    }
    _toggleControls();
  }

  // --- settings ---------------------------------------------------------------------------------

  Future<void> _applyPreferencesLive(ReaderPreferences prefs) async => _queueRelayout();

  /// Rotation / window resize: lay out again for the new page size at the same text.
  Future<void> _onPageAreaResized(Size pagePx) async {
    _pageImageStale = true; // old image has the old shape: letterbox it until the new one is in
    _clearSelection();
    _zoomSession++;
    setState(() {
      _zoomed = false;
      _zoomShrunk = false;
    });
    _queueRelayout();
  }

  bool _relayingOut = false;
  bool _pageImageStale = false;
  int _imageEpoch = 0; // bumped per relayout: the page cross-fades instead of popping
  bool _relayoutAgain = false;

  /// Lays the book out again for the current settings and page size, keeping the exact text in
  /// view. Runs one at a time; requests arriving meanwhile collapse into one more run (latest wins).
  Future<void> _queueRelayout() async {
    if (_relayingOut) {
      _relayoutAgain = true;
      return;
    }
    final engine = _engine;
    if (engine == null || _page == null) return;
    _relayingOut = true;
    try {
      do {
        _relayoutAgain = false;
        _cancelTurn();
        if (!_paginated) _tilesFrozen = true;
        final keep = _lastLocator;
        final page = _page!;
        _generation++;
        setState(() => _locationsReady = false);
        final native = await NativePrefs.from(_preferences, padding: _padding);
        final p = await engine.setPrefsAt(
          native,
          _pagePx,
          keep?.resourceIndex ?? page.resourceIndex,
          keep?.charOffset ?? 0,
        );
        if (!mounted) return;
        _appliedLook = _look;
        _openedPx = _pagePx;
        _dropPageImages();
        if (engine.lastIndex != null && !_locationsReady) setState(() => _locationsReady = true);
        if (_relayoutAgain) continue;
        await _showPage(p, save: false);
        if (mounted) setState(() => _imageEpoch++);
        if (!_paginated) await _syncScrolledChapter(p, jump: true, force: true);
      } while (_relayoutAgain && mounted);
    } catch (e) {
      debugPrint('NativeReader: relayout failed: $e');
    } finally {
      _relayingOut = false;
    }
  }

  // --- page curl --------------------------------------------------------------------------------

  double _edgeFor(_PageTurn turn) {
    final w = _pageWidth;
    final flat = PageCurl.flatEdge(w);
    final gone = PageCurl.goneEdge(w);
    final start = turn.dir > 0 ? flat : gone;
    final edge = start + turn.dx * 1.15;
    return edge.clamp(gone, flat);
  }

  Future<void> _startTurn(int dir, double y) async {
    _clearSelection();
    if (_turn != null || !_paginated || _selectionMenu != null || _page == null) return;
    _onUserActivity();
    final turn = _PageTurn(dir, ((y - 0.5) * 0.5).clamp(-0.25, 0.25));
    _turn = turn;
    _turnAnim.stop();
    _turnEdge = _edgeFor(turn);
    final current = _pageImage;
    final page = _page!;
    final known = dir > 0 ? _nextOf : _prevOf;
    // Usually prefetched: start curling this frame, no waiting.
    final NativePage? target;
    final ui.Image? next;
    if (known.containsKey(page) && (known[page] == null || _ready[known[page]] != null)) {
      target = known[page];
      next = target == null ? null : _ready[target];
    } else {
      try {
        target = await _neighbour(page, dir);
        if (!mounted || _turn != turn) return;
        next = target == null ? null : await _imageFor(target);
      } catch (_) {
        if (_turn == turn) setState(() => _turn = null);
        return;
      }
      if (!mounted || _turn != turn) return;
    }
    turn.target = target;
    turn.moved = target != null;
    if (dir > 0) {
      // Forward: the current page curls away over the next one.
      turn.front = current;
      turn.back = next;
    } else {
      // Back: the previous page curls in over the current one.
      turn.back = current;
      turn.front = next ?? current;
    }
    turn.ready = true;
    setState(() {});
    if (turn.released) {
      _releaseTurn(turn);
    } else {
      _turnEdge = _edgeFor(turn);
    }
  }

  void _moveTurn(double dx) {
    final turn = _turn;
    if (turn == null || turn.released) return;
    turn.dx = (turn.ready && !turn.moved) ? dx * 0.15 : dx;
    if (turn.ready) _turnEdge = _edgeFor(turn);
  }

  void _endTurnGesture(double dx, double velocityPxPerSec) {
    final turn = _turn;
    if (turn == null || turn.released) return;
    turn.dx = (turn.ready && !turn.moved) ? dx * 0.15 : dx;
    turn.velocity = velocityPxPerSec / 1000; // px/ms, as the commit rule expects
    turn.released = true;
    if (turn.ready) _releaseTurn(turn);
  }

  bool _shouldCommit(_PageTurn turn) {
    final v = turn.velocity * turn.dir;
    final dx = turn.dx * turn.dir / _pageWidth;
    if (v < -0.3) return true;
    if (v > 0.3) return false;
    return dx < -0.12;
  }

  Future<void> _releaseTurn(_PageTurn turn) async {
    final commit = turn.moved && _shouldCommit(turn);
    final w = _pageWidth;
    final target = (commit == (turn.dir > 0)) ? PageCurl.goneEdge(w) : PageCurl.flatEdge(w);
    await _animateEdge(target);
    if (!mounted || _turn != turn) return;
    if (commit && turn.target != null) {
      AppHaptics.tick();
      final image = _ready[turn.target!] ?? await _imageFor(turn.target!);
      if (!mounted) return;
      setState(() {
        _page = turn.target;
        _pageImage = image;
        _turn = null;
      });
      _relocate(turn.target!, save: true);
      _prefetch(turn.target!);
    } else {
      setState(() => _turn = null);
    }
  }

  Future<void> _animateEdge(double target) async {
    final from = _turnEdge;
    final span = (PageCurl.flatEdge(_pageWidth) - PageCurl.goneEdge(_pageWidth)).abs();
    final ms = (340 * (target - from).abs() / span).clamp(120.0, 340.0).round();
    _turnAnim.duration = Duration(milliseconds: ms);
    final curve = CurvedAnimation(parent: _turnAnim, curve: Curves.easeOutCubic);
    void tick() {
      if (mounted) _turnEdge = from + (target - from) * curve.value;
    }

    _turnAnim.addListener(tick);
    try {
      await _turnAnim.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Stopped by a new turn or a settings change.
    } finally {
      _turnAnim.removeListener(tick);
      curve.dispose();
    }
  }

  void _cancelTurn() {
    if (_turn == null) return;
    _turnAnim.stop();
    if (mounted) {
      setState(() => _turn = null);
    } else {
      _turn = null;
    }
  }

  /// A page turn not driven by a finger (keyboard, mouse wheel): animated in paginated mode.
  Future<void> _turnPage(int dir) async {
    final engine = _engine;
    final page = _page;
    if (engine == null || page == null) return;
    if (!_paginated) {
      final next = await engine.step(page, dir);
      if (next != null) _goTo(Future.value(next));
      return;
    }
    if (_turn != null) return;
    await _startTurn(dir, 0.5);
    final turn = _turn;
    if (turn == null || turn.released) return;
    turn.velocity = -dir * 2.0;
    turn.dx = -dir * _pageWidth * 0.5;
    turn.released = true;
    if (turn.ready) await _releaseTurn(turn);
  }

  // Horizontal drag on the page → curl. Direction from the first movement.
  double _dragDx = 0;
  bool _dragStarted = false;

  void _onHDragStart(DragStartDetails d) {
    _dragDx = 0;
    _dragStarted = false;
    _dragY = d.localPosition.dy;
  }

  double _dragY = 0;

  void _onHDragUpdate(DragUpdateDetails d, double pageHeight) {
    _dragDx += d.delta.dx;
    if (!_dragStarted) {
      if (_dragDx.abs() < 6) return;
      _dragStarted = true;
      _startTurn(_dragDx < 0 ? 1 : -1, (_dragY / pageHeight).clamp(0.0, 1.0));
    }
    _moveTurn(_dragDx);
  }

  void _onHDragEnd(DragEndDetails d) {
    if (!_dragStarted) return;
    _endTurnGesture(_dragDx, d.velocity.pixelsPerSecond.dx);
  }

  // --- zoomed-out page strip --------------------------------------------------------------------
  // A continuous PageView: index _stripBase is the page the strip opened on, neighbours are
  // resolved as the strip moves. Cards never shuffle or jump, so swiping doesn't flash.

  static const int _stripBase = 100000;
  final Map<int, NativePage?> _stripAt = {};
  int _stripIndex = _stripBase;

  ui.Image? _stripImage(int index) {
    final page = _stripAt[index];
    return page == null ? null : _ready[page];
  }

  Future<void> _enterZoom() async {
    final page = _page;
    if (_engine == null || _zoomed || _turn != null || _selectionMenu != null || page == null) return;
    final session = ++_zoomSession;
    // Scrolled mode doesn't keep page images: draw the current one now.
    if (_ready[page] == null) await _imageFor(page);
    if (!mounted || session != _zoomSession || !_controlsVisible || _page != page) return;
    _stripController?.dispose();
    _stripController = PageController(initialPage: _stripBase, viewportFraction: _stripViewportFraction);
    _stripAt
      ..clear()
      ..[_stripBase] = page;
    _stripIndex = _stripBase;
    setState(() {
      _zoomed = true;
      _zoomShrunk = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && session == _zoomSession) setState(() => _zoomShrunk = true);
    });
    _refreshChapterInfo();
    await _resolveAround(_stripBase, session);
  }

  /// Makes sure the two cards each side of [index] know their page and have their image.
  Future<void> _resolveAround(int index, int session) async {
    Future<void> side(int dir) async {
      for (var k = 1; k <= 2; k++) {
        final idx = index + dir * k;
        if (!_stripAt.containsKey(idx)) {
          final from = _stripAt[idx - dir];
          if (from == null) return;
          if (mounted) setState(() => _stripPending.add(idx));
          try {
            final n = await _neighbour(from, dir);
            if (!mounted || session != _zoomSession) return;
            _stripAt[idx] = n;
            if (n != null && _ready[n] == null) await _imageFor(n);
          } finally {
            if (mounted) setState(() => _stripPending.remove(idx));
          }
        } else {
          final n = _stripAt[idx];
          if (n == null) return;
          if (_ready[n] == null) {
            await _imageFor(n);
            if (mounted) setState(() {});
          }
        }
        if (!mounted || session != _zoomSession) return;
      }
    }

    await Future.wait([side(1), side(-1)]);
  }

  Future<void> _refreshChapterInfo() async {
    final engine = _engine;
    final page = _page;
    if (engine == null || page == null) return;
    final info = await engine.chapterInfo(page);
    if (mounted) setState(() => _chapterInfo = info.toScreenMap());
  }

  String? _chapterTitle(String key) {
    final entry = _chapterInfo?[key];
    if (entry is! Map) return null;
    final title = (entry['title'] as String?)?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  void _goChapterInZoom(int dir) {
    final entry = _chapterInfo?[dir > 0 ? 'next' : 'prev'];
    final href = entry is Map ? entry['href'] as String? : null;
    final engine = _engine;
    if (href == null || !_zoomed || engine == null) return;
    _onUserActivity();
    AppHaptics.tick();
    _goTo(engine.atHref(href)).then((_) => _refreshChapterInfo());
  }

  /// The place changed from outside the strip (scrubber, chapter box): re-centre on it in place.
  Future<void> _refreshStrip(int session) async {
    if (!mounted || !_zoomed || session != _zoomSession) return;
    final page = _page;
    if (page == null) return;
    if (_ready[page] == null) await _imageFor(page);
    if (!mounted || session != _zoomSession) return;
    setState(() {
      _stripAt
        ..clear()
        ..[_stripIndex] = page;
    });
    await _resolveAround(_stripIndex, session);
  }

  Future<void> _exitZoom() async {
    if (!_zoomed) return;
    final session = ++_zoomSession;
    setState(() => _zoomShrunk = false);
    await Future<void>.delayed(_zoomDuration);
    if (!mounted || session != _zoomSession) return;
    setState(() {
      _zoomed = false;
      _stripAt.clear();
      _stripPending.clear();
    });
  }

  /// The strip settled on another card: that page becomes the current one. Nothing moves.
  Future<void> _onStripPageChanged(int index) async {
    if (!_zoomed || index == _stripIndex) return;
    _onUserActivity();
    final session = _zoomSession;
    final target = _stripAt[index];
    if (target == null) {
      // No page there (start/end of the book), or not known yet: back to the current card.
      _stripController?.animateToPage(_stripIndex, duration: _zoomDuration, curve: Curves.easeOut);
      return;
    }
    _stripIndex = index;
    await _showPage(target);
    if (!mounted || session != _zoomSession) return;
    if (!_paginated) _syncScrolledChapter(target, jump: true);
    _refreshChapterInfo();
    _stripAt.removeWhere((i, _) => (i - index).abs() > 3);
    await _resolveAround(index, session);
  }

  // --- scrolled mode ----------------------------------------------------------------------------

  /// Makes the scrolled view show [p]'s chapter, optionally jumping to [p].
  /// [force]: the layout changed (rotation, settings): swap to the new slices only once the ones
  /// around [p] are drawn, so the old text stays on screen until then (no blank reload).
  Future<void> _syncScrolledChapter(NativePage p, {bool jump = false, bool force = false}) async {
    final engine = _engine;
    if (engine == null) return;
    if (_scrollChapter != p.resourceIndex || force) {
      final heights = await engine.tiles(p.resourceIndex);
      if (!mounted) return;
      final dpr = _dpr;
      final drawn = <int, ui.Image>{};
      for (final t in [p.page, p.page + 1]) {
        if (t >= 0 && t < heights.length) drawn[t] = await engine.renderTile(p.resourceIndex, t);
      }
      if (!mounted) return;
      final old = _tileReady.values.toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final i in old) {
          i.dispose();
        }
      });
      _tileImages
        ..clear()
        ..addAll({for (final e in drawn.entries) e.key: Future.value(e.value)});
      setState(() {
        _tilesFrozen = false;
        _scrollChapter = p.resourceIndex;
        _tileHeights = [for (final h in heights) h / dpr];
        _tileReady
          ..clear()
          ..addAll(drawn);
      });
      jump = true;
    }
    if (!jump) return;
    final offset = _tileHeights.take(p.page).fold<double>(0, (a, b) => a + b);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _scrollController;
      if (c != null && c.hasClients) c.jumpTo(offset.clamp(0.0, c.position.maxScrollExtent));
      _onScrolled();
    });
  }

  /// True while a relayout is replacing the slices: keep showing the old ones, start no new ones.
  bool _tilesFrozen = false;

  Future<ui.Image>? _tileImage(int tile) => _tilesFrozen ? null : _tileImages.putIfAbsent(tile, () {
        final chapter = _scrollChapter;
        final gen = _generation;
        final f = _engine!.renderTile(chapter, tile);
        f.then((i) {
          if (!mounted || chapter != _scrollChapter || gen != _generation) return;
          setState(() => _tileReady[tile] = i);
        }, onError: (Object _) {
          _tileImages.remove(tile);
        });
        return f;
      });

  /// Keeps the slices around [tile] drawn ahead, and drops far ones.
  void _preloadTiles(int tile) {
    if (_tilesFrozen) return;
    for (var i = tile - 1; i <= tile + 2; i++) {
      if (i >= 0 && i < _tileHeights.length) _tileImage(i);
    }
    _tileImages.removeWhere((i, _) => (i - tile).abs() > 4);
    final far = _tileReady.entries.where((e) => (e.key - tile).abs() > 4).toList();
    for (final e in far) {
      _tileReady.remove(e.key);
      WidgetsBinding.instance.addPostFrameCallback((_) => e.value.dispose());
    }
  }

  void _scrollToRatio(double ratio) {
    final c = _scrollController;
    if (c == null || !c.hasClients) return;
    c.jumpTo(ratio * c.position.maxScrollExtent);
  }

  /// Scroll moved: scroll line, and the position (first visible slice = that page).
  void _onScrolled() {
    final c = _scrollController;
    if (c == null || !c.hasClients || _tileHeights.isEmpty) return;
    final max = c.position.maxScrollExtent;
    final viewport = c.position.viewportDimension;
    final total = max + viewport;
    if (!_draggingScrollLine) {
      _chapterScrollN.value = (max <= 0 ? 0 : (c.offset / max).clamp(0.0, 1.0), total <= 0 ? 1 : (viewport / total).clamp(0.0, 1.0));
    }
    var acc = 0.0;
    var tile = 0;
    for (var i = 0; i < _tileHeights.length; i++) {
      if (acc + _tileHeights[i] > c.offset + 1) {
        tile = i;
        break;
      }
      acc += _tileHeights[i];
      tile = i;
    }
    _preloadTiles(tile);
    if (_selection != null && !_selectingInScroll) _clearSelection();
    final p = NativePage(_scrollChapter, tile);
    if (p != _page) {
      _page = p;
      _relocate(p, save: true);
    }
  }

  // --- scrolled mode: taps and selection ---------------------------------------------------------

  bool _selectingInScroll = false;

  // Long-press in progress: where it started, and whether the finger is still down. Tiny moves
  // (finger jitter) don't count as dragging the selection; a drag result that arrives after the
  // finger lifted still shows the menu.
  bool _pressing = false;
  bool _handleDragging = false;
  Offset _pressStart = Offset.zero;
  static const double _dragSlop = 12;

  void _pressBegan(Offset at) {
    _pressing = true;
    _pressStart = at;
  }

  bool _isSelectionDrag(Offset at) => (at - _pressStart).distance >= _dragSlop;

  void _pressEnded() {
    _pressing = false;
    final sel = _selection;
    if (sel != null) _applySelection(sel);
  }

  /// Viewport point → (page, point in that page's pixels, slice top on screen in logical px).
  ({NativePage page, Offset px, double tileTop})? _scrolledHit(Offset local) {
    final c = _scrollController;
    if (c == null || !c.hasClients || _tileHeights.isEmpty) return null;
    final y = local.dy + c.offset - _padding;
    var top = 0.0;
    for (var i = 0; i < _tileHeights.length; i++) {
      final h = _tileHeights[i];
      if (y < top + h || i == _tileHeights.length - 1) {
        final yIn = (y - top).clamp(0.0, h);
        return (
          page: NativePage(_scrollChapter, i),
          px: Offset(local.dx * _dpr, (yIn + _padding) * _dpr),
          tileTop: top + _padding - c.offset,
        );
      }
      top += h;
    }
    return null;
  }

  Future<void> _onScrolledTapUp(TapUpDetails d) async {
    _onUserActivity();
    if (_selection != null || _selectionMenu != null) {
      _clearSelection();
      return;
    }
    final hit = _scrolledHit(d.localPosition);
    final engine = _engine;
    if (hit != null && engine != null && _highlights.isNotEmpty) {
      final id = await engine.highlightAt(hit.page, hit.px);
      if (!mounted) return;
      if (id != null) {
        _onHighlightTapped(id, d.globalPosition);
        return;
      }
    }
    _toggleControls();
  }

  Future<void> _onScrolledLongPress(Offset local) async {
    _pressBegan(local);
    final hit = _scrolledHit(local);
    final engine = _engine;
    if (hit == null || engine == null) return;
    final sel = await engine.wordAt(hit.page, hit.px);
    if (!mounted || sel == null) return;
    AppHaptics.tick();
    _scrollAnchor = hit;
    _applySelection(sel, map: _scrolledRect(hit.tileTop));
  }

  ({NativePage page, Offset px, double tileTop})? _scrollAnchor;

  Future<void> _onScrolledLongPressMove(Offset local) async {
    final anchor = _scrollAnchor;
    final sel = _selection;
    final engine = _engine;
    if (anchor == null || sel == null || engine == null || sel.rects.isEmpty) return;
    if (!_isSelectionDrag(local)) return;
    final hit = _scrolledHit(local);
    if (hit == null || hit.page != anchor.page) return; // one slice at a time
    final fixed = Offset(sel.rects.first.left + 1, sel.rects.first.center.dy);
    final next = await engine.rangeBetween(anchor.page, fixed, hit.px);
    if (!mounted || next == null) return;
    _selectingInScroll = true;
    _applySelection(next, showMenu: !_pressing, map: _scrolledRect(anchor.tileTop));
    _selectingInScroll = false;
  }

  /// Page-pixel rect of a slice whose top is at [tileTop] → viewport logical rect.
  Rect Function(Rect) _scrolledRect(double tileTop) => (r) => Rect.fromLTRB(
        r.left / _dpr,
        r.top / _dpr - _padding + tileTop,
        r.right / _dpr,
        r.bottom / _dpr - _padding + tileTop,
      );

  /// Chapter lock-swipe: pulling past either end fills the ring; releasing when full changes chapter.
  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollUpdateNotification) _onScrolled();
    if (n is OverscrollNotification) {
      final dir = n.overscroll > 0 ? 1 : -1;
      _overscroll += n.overscroll.abs();
      final available = dir > 0 ? _scrollChapter + 1 < (_engine?.chapterCount ?? 0) : _scrollChapter > 0;
      final progress = (_overscroll / 140).clamp(0.0, 1.0);
      final armed = available && progress >= 1.0;
      if (AppPreferences.instance.swipeHaptics) {
        if (armed && !_swipeArmed) {
          AppHaptics.confirm();
        } else if (!armed && _swipeArmed) {
          AppHaptics.tick();
        }
      }
      setState(() {
        _swipeDir = dir;
        _swipeProgress = progress;
        _swipeAvailable = available;
        _swipeArmed = armed;
      });
    }
    if (n is ScrollEndNotification || (n is UserScrollNotification && n.direction == ScrollDirection.idle)) {
      final go = _swipeArmed ? _swipeDir : 0;
      _overscroll = 0;
      if (_swipeDir != 0) setState(_resetSwipe);
      if (go != 0) _goChapter(go, atEnd: go < 0);
    }
    return false;
  }

  double _chapterSwipeDx = 0;
  static const double _chapterSwipeDistance = 160;

  void _onChapterSwipe(double delta) {
    _onUserActivity();
    _chapterSwipeDx += delta;
    final dir = _chapterSwipeDx < 0 ? 1 : -1; // swipe left = next chapter
    final engine = _engine;
    final available = engine != null && (dir > 0 ? _scrollChapter + 1 < engine.chapterCount : _scrollChapter > 0);
    final progress = (_chapterSwipeDx.abs() / _chapterSwipeDistance).clamp(0.0, 1.0);
    final armed = available && progress >= 1.0;
    if (AppPreferences.instance.swipeHaptics) {
      if (armed && !_swipeArmed) {
        AppHaptics.confirm();
      } else if (!armed && _swipeArmed) {
        AppHaptics.tick();
      }
    }
    setState(() {
      _swipeDir = dir;
      _swipeProgress = progress;
      _swipeAvailable = available;
      _swipeArmed = armed;
    });
  }

  void _endChapterSwipe() {
    final go = _swipeArmed ? _swipeDir : 0;
    _chapterSwipeDx = 0;
    if (_swipeDir != 0) setState(_resetSwipe);
    if (go != 0) _goChapter(go);
  }

  void _resetSwipe() {
    _swipeDir = 0;
    _swipeProgress = 0;
    _swipeArmed = false;
  }

  Future<void> _goChapter(int dir, {bool atEnd = false}) async {
    final engine = _engine;
    if (engine == null) return;
    final target = _scrollChapter + dir;
    if (target < 0 || target >= engine.chapterCount) return;
    // Start of the chapter, or (pulling up past the top) the end of the previous one.
    await _goTo(engine.at(target, atEnd ? 1 << 30 : 0));
  }

  bool _scrollSyncing = false;

  Widget _buildScrolled(BuildContext context) {
    final c = _scrollController ??= ScrollController();
    if (_scrollChapter < 0 && _page != null && !_scrollSyncing) {
      _scrollSyncing = true;
      _syncScrolledChapter(_page!, jump: true).whenComplete(() => _scrollSyncing = false);
    }
    final pageColor = SakuraEpubMapper.pageColorFor(_theme);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onScrolledTapUp,
        onLongPressStart: (d) => _onScrolledLongPress(d.localPosition),
        onLongPressMoveUpdate: (d) => _onScrolledLongPressMove(d.localPosition),
        onLongPressEnd: (_) => _pressEnded(),
        // Long horizontal swipe = previous/next chapter (the ring fills; release when full).
        onHorizontalDragStart: (_) => _chapterSwipeDx = 0,
        onHorizontalDragUpdate: (d) => _onChapterSwipe(d.delta.dx),
        onHorizontalDragEnd: (_) => _endChapterSwipe(),
        onHorizontalDragCancel: _endChapterSwipe,
        child: ColoredBox(
          color: pageColor,
          child: ListView.builder(
            controller: c,
            physics: const _HeavyScrollPhysics(parent: ClampingScrollPhysics()),
            padding: EdgeInsets.only(top: _padding, bottom: _padding),
            itemCount: _tileHeights.length,
            itemExtentBuilder: (i, _) => i < _tileHeights.length ? _tileHeights[i] : null,
            itemBuilder: (context, i) {
              final image = _tileReady[i];
              if (image == null) {
                _tileImage(i);
                return const SizedBox.expand();
              }
              if (_tilesFrozen) return RawImage(image: image, fit: BoxFit.fitWidth, alignment: Alignment.topCenter);
              return RawImage(image: image, fit: BoxFit.fill);
            },
          ),
        ),
      ),
    );
  }

  // --- sheets -----------------------------------------------------------------------------------

  void _showCustomizationSheet() {
    _exitZoom();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SakuraCustomizationSheet(
        preferences: _preferences,
        onChanged: (newPrefs) {
          final modeChanged = newPrefs.scrollMode != _preferences.scrollMode;
          setState(() => _preferences = newPrefs);
          _session.dispatchCommand(UpdatePreferencesCommand(newPrefs));
          if (modeChanged) {
            _scrollChapter = -1;
            setState(() {});
          } else {
            _applyPreferencesLive(newPrefs);
          }
        },
        brightness: _brightness,
        onBrightnessChanged: (value) => setState(() => _brightness = value),
      ),
    );
  }

  /// TOC entries, note hrefs (`…#aread:<offset>`) and old CFI notes all navigate here.
  Future<void> _navigateToHref(String href) async {
    final engine = _engine;
    if (engine == null) return;
    if (href.startsWith('epubcfi(')) {
      final r = await engine.resolveLegacy(href, null, null);
      if (r != null) await _goTo(engine.at(r.resourceIndex, r.start));
      return;
    }
    await _goTo(engine.atHref(href));
  }

  void _showTocSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SakuraTocSheet(
        chapters: _toc,
        notes: _session.state.annotations,
        onNavigateToHref: _navigateToHref,
      ),
    );
  }

  void _showSearchSheet({String? initialQuery}) {
    final engine = _engine;
    if (engine == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NativeSearchSheet(
        engine: engine,
        initialQuery: initialQuery,
        onNavigate: (hit) => _goTo(engine.at(hit.resourceIndex, hit.start)),
      ),
    );
  }

  // --- build ------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: SakuraEpubMapper.pageColorFor(_theme),
      body: Builder(
        builder: (context) {
          if (_openError != null) return _buildLoadFailure(context, l10n.couldNotOpenBookFile(_openError!));
          final media = MediaQuery.of(context);
          final insetTop = media.padding.top;
          final insetBottom = media.padding.bottom;
          final pageBottom = insetBottom + _footerHeight;
          _pageWidth = media.size.width;
          final area = Size(media.size.width, media.size.height - insetTop - pageBottom);
          final px = Size((area.width * media.devicePixelRatio).roundToDouble(), (area.height * media.devicePixelRatio).roundToDouble());
          if (_lastPageArea == null) {
            _pagePx = px;
            WidgetsBinding.instance.addPostFrameCallback((_) => _open(px));
          } else if (_lastPageArea != area) {
            _pagePx = px;
            WidgetsBinding.instance.addPostFrameCallback((_) => _onPageAreaResized(px));
          }
          _lastPageArea = area;
          final pageColor = SakuraEpubMapper.pageColorFor(_theme);
          final turn = _turn;
          final laidOut = _pageImage != null;

          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: insetTop,
                bottom: pageBottom,
                child: _paginated || !laidOut
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _onPageTapUp,
                        onLongPressStart: (d) {
                          _pressBegan(d.localPosition);
                          _selectWordAt(d.localPosition);
                        },
                        onLongPressMoveUpdate: (d) {
                          final sel = _selection;
                          if (sel == null || sel.rects.isEmpty || !_isSelectionDrag(d.localPosition)) return;
                          _selectionAnchor ??= Offset(sel.rects.first.left + 1, sel.rects.first.center.dy);
                          _extendSelection(_selectionAnchor!, d.localPosition);
                        },
                        onLongPressEnd: (_) => _pressEnded(),
                        onHorizontalDragStart: _paginated ? _onHDragStart : null,
                        onHorizontalDragUpdate: _paginated ? (d) => _onHDragUpdate(d, area.height) : null,
                        onHorizontalDragEnd: _paginated ? _onHDragEnd : null,
                        child: laidOut
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: RawImage(
                                  key: ValueKey(_imageEpoch),
                                  image: _pageImage,
                                  fit: _pageImageStale ? BoxFit.contain : BoxFit.fill,
                                ),
                              )
                            : const SizedBox.expand(),
                      )
                    : _buildScrolled(context),
              ),
              if (_selection != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: insetTop,
                  bottom: pageBottom,
                  child: _SelectionHandles(
                    rects: [for (final r in _selection!.rects) (_selectionMap ?? _toLogical)(r)],
                    showHandles: _paginated,
                    color: AppColors.accentLime,
                    onDragStart: (startHandle) {
                      final rects = _selection!.rects;
                      if (rects.isEmpty) return;
                      _handleDragging = true;
                      // Fix the opposite end (page px).
                      _selectionAnchor = startHandle
                          ? Offset(rects.last.right - 1, rects.last.center.dy)
                          : Offset(rects.first.left + 1, rects.first.center.dy);
                      setState(() => _selectionMenu = null);
                    },
                    onDrag: (local) => _extendSelection(_selectionAnchor!, local),
                    onDragEnd: () {
                      _handleDragging = false;
                      final sel = _selection;
                      if (sel != null) _applySelection(sel);
                    },
                  ),
                ),
              if (turn != null && turn.front != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: insetTop,
                  bottom: pageBottom,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PageCurlPainter(
                        program: _curlProgram,
                        front: turn.front,
                        back: turn.back,
                        edge: _turnEdgeN,
                        tilt: turn.tilt,
                        paper: pageColor,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: insetTop,
                bottom: pageBottom,
                child: IgnorePointer(
                  ignoring: laidOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: laidOut ? 0 : 1,
                    child: ReaderPageSkeleton(
                      pageColor: pageColor,
                      inkColor: SakuraEpubMapper.textColorFor(_theme),
                      padding: _padding,
                    ),
                  ),
                ),
              ),
              if (_zoomed) _buildPageStrip(context, insetTop, pageBottom, pageColor),
              _buildFooter(insetBottom),
              if (_brightness < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Colors.black.withValues(alpha: (1 - _brightness) * 0.8)),
                  ),
                ),
              if (_preferences.scrollMode == ScrollMode.continuous) _buildScrollLine(context, insetTop, insetBottom),
              _animatedChrome(visible: _topVisible, fromTop: true, child: _buildTopBar(context)),
              _animatedChrome(visible: _bottomVisible, fromTop: false, child: _buildBottomBar(context)),
              _buildChapterSwipeIndicator(context),
              if (_selectionMenu != null) _buildSelectionOverlay(context, _selectionMenu!, insetTop, pageBottom),
              if (_loadTimedOut && !_epubReady) _buildLoadTimeoutBanner(context),
            ],
          );
        },
      ),
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (!_paginated && (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowLeft)) {
          _goChapter(key == LogicalKeyboardKey.arrowRight ? 1 : -1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.pageDown ||
            key == LogicalKeyboardKey.space) {
          _turnPage(1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.pageUp) {
          _turnPage(-1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyM) {
          _toggleControls();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyB) {
          _addBookmark();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent && _paginated) {
            _accumulatedScrollDelta += pointerSignal.scrollDelta.dy;
            _scrollDebounceTimer?.cancel();
            _scrollDebounceTimer = Timer(const Duration(milliseconds: 80), () {
              if (_accumulatedScrollDelta.abs() >= 40.0) _turnPage(_accumulatedScrollDelta > 0 ? 1 : -1);
              _accumulatedScrollDelta = 0;
            });
          }
        },
        child: scaffold,
      ),
    );
  }

  /// Edge indicator for the chapter lock-swipe: slides in from the side the
  /// next/previous chapter is on, its ring fills with the drag, and turns
  /// solid (with a haptic) once releasing would change chapter.
  Widget _buildChapterSwipeIndicator(BuildContext context) {
    final visible = _swipeDir != 0 && _swipeProgress > 0;
    final forward = _swipeDir >= 0;
    final appear = (_swipeProgress * 3).clamp(0.0, 1.0);
    final accent = _swipeAvailable ? AppColors.accentLime : AppColors.fgFaint;
    final label = !_swipeAvailable
        ? (forward ? l10n.lastChapter : l10n.firstChapter)
        : _swipeArmed
        ? l10n.releaseToOpen
        : (forward ? l10n.nextChapter : l10n.previousChapter);

    return Positioned(
      top: 0,
      bottom: 0,
      left: forward ? null : -24 + 40 * appear,
      right: forward ? -24 + 40 * appear : null,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: visible ? appear : 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _swipeArmed ? accent : AppColors.popoverSurface.withValues(alpha: 0.92),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 14),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: _swipeProgress,
                          strokeWidth: 3,
                          backgroundColor: AppColors.fg.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(
                            _swipeArmed ? Colors.transparent : accent,
                          ),
                        ),
                      ),
                      Icon(
                        !_swipeAvailable
                            ? Icons.block_rounded
                            : (forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
                        size: 30,
                        color: _swipeArmed ? Colors.black : accent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.popoverSurface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.sora(fontSize: 11, color: AppColors.fgMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Play Books-style line under the page: pages left, and the percentage.
  Widget _buildFooter(double insetBottom) {
    final color = SakuraEpubMapper.textColorFor(_theme).withValues(alpha: 0.6);
    final style = GoogleFonts.dmSans(fontSize: 11, color: color);
    final pad = AppPreferences.instance.readerPadding.clamp(12.0, 48.0);
    final showPages = _paginated && _pagesLeft >= 0;
    // While the progress bar shows, the line moves up above it instead of
    // hiding behind it (bar: 24 from the bottom, 52 tall).
    final lifted = _bottomVisible && _epubReady;
    // The strip under the page grows (in the page colour) so the line sits
    // above the bar; it shrinks back when the bar hides.
    final textBottom = lifted ? math.max(insetBottom, 24.0 + 52 + 6) : insetBottom;
    return AnimatedPositioned(
      duration: _chromeDuration,
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: 0,
      height: textBottom + _footerHeight,
      child: IgnorePointer(
        child: ColoredBox(
          color: SakuraEpubMapper.pageColorFor(_theme),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: _footerHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Row(
          children: [
            Expanded(
              child: Text(
                showPages ? l10n.pagesLeftInBook(_pagesLeft) : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            Text('${(_progress * 100).round()}%', style: style),
          ],
        ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The zoomed-out page cards, between the header and the footer pill.
  Widget _buildPageStrip(
    BuildContext context,
    double insetTop,
    double pageBottom,
    Color pageColor,
  ) {
    final media = MediaQuery.of(context);
    final pageH = media.size.height - insetTop - pageBottom;
    final scale = _zoomShrunk ? _stripScale : 1.0;
    Widget card(int index) {
      final current = index == _stripIndex;
      final image = _stripImage(index);
      // No page there (start/end): nothing. Known but still drawing: a skeleton card.
      final pending = image == null &&
          !current &&
          (_stripPending.contains(index) || (_stripAt.containsKey(index) && _stripAt[index] != null));
      if (image == null && !current && !pending) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () {
          if (current) {
            _setControls(false);
          } else {
            _stripController?.animateToPage(index, duration: _zoomDuration, curve: Curves.easeOut);
          }
        },
        child: Center(
          child: AnimatedOpacity(
            duration: _zoomDuration,
            opacity: current || _zoomShrunk ? 1 : 0,
            child: AnimatedScale(
              duration: _zoomDuration,
              curve: Curves.easeOutCubic,
              scale: current ? scale : _stripScale,
              child: SizedBox(
                width: media.size.width,
                height: pageH,
                child: AnimatedContainer(
                  duration: _zoomDuration,
                  curve: Curves.easeOutCubic,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: pageColor,
                    // 8px corners on screen; the card is drawn full size
                    // and scaled down, so the radius is scaled up to match.
                    borderRadius: BorderRadius.circular(
                      !current || _zoomShrunk ? 8 / _stripScale : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _zoomShrunk ? 0.28 : 0),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: image != null
                      ? RawImage(image: image, fit: BoxFit.fill)
                      : pending
                      ? ReaderPageSkeleton(
                          pageColor: pageColor,
                          inkColor: SakuraEpubMapper.textColorFor(_theme),
                          padding: AppPreferences.instance.readerPadding.clamp(12.0, 48.0),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final vertical = _paginated; // chapter axis
    final prevTitle = _chapterTitle('prev');
    final nextTitle = _chapterTitle('next');
    final currentTitle = _chapterTitle('current');
    void dragUpdate(DragUpdateDetails d) {
      final delta = vertical ? d.delta.dy : d.delta.dx;
      var v = _chapterDragN.value + delta;
      // Resist where there's no chapter to go to.
      if ((v > 0 && prevTitle == null) || (v < 0 && nextTitle == null)) v = _chapterDragN.value + delta * 0.25;
      _chapterDragN.value = v.clamp(-140.0, 140.0);
    }

    void dragEnd(DragEndDetails d) {
      final velocity = vertical ? d.velocity.pixelsPerSecond.dy : d.velocity.pixelsPerSecond.dx;
      final v = _chapterDragN.value;
      _chapterDragN.value = 0;
      // Pulling down/right brings the previous chapter, up/left the next.
      if ((v > _chapterDragCommit || velocity > 700) && prevTitle != null) {
        _goChapterInZoom(-1);
      } else if ((v < -_chapterDragCommit || velocity < -700) && nextTitle != null) {
        _goChapterInZoom(1);
      }
    }

    final strip = PageView.builder(
            controller: _stripController,
            itemCount: _stripBase * 2,
            onPageChanged: _onStripPageChanged,
            // Cards stay full width until shrunk; no peeking before then.
            physics: _zoomShrunk ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
            // Scrolled mode: neighbours are the screens above and below.
            scrollDirection: _paginated ? Axis.horizontal : Axis.vertical,
            itemBuilder: (context, i) => OverflowBox(
              maxWidth: media.size.width,
              maxHeight: pageH,
              child: card(i),
            ),
          );

    // Under the header (paginated: the top box sits below it).
    final headerBox = _topBarKey.currentContext?.findRenderObject() as RenderBox?;
    final headerH = headerBox != null && headerBox.hasSize ? headerBox.size.height - insetTop : 76.0;

    return Positioned(
      left: 0,
      right: 0,
      top: insetTop,
      bottom: pageBottom,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setControls(false),
        onVerticalDragUpdate: vertical && _zoomShrunk ? dragUpdate : null,
        onVerticalDragEnd: vertical && _zoomShrunk ? dragEnd : null,
        onHorizontalDragUpdate: !vertical && _zoomShrunk ? dragUpdate : null,
        onHorizontalDragEnd: !vertical && _zoomShrunk ? dragEnd : null,
        child: ColoredBox(
          color: AppColors.figmaReaderBackground,
          child: ValueListenableBuilder<double>(
            valueListenable: _chapterDragN,
            builder: (context, drag, _) {
              final armedPrev = drag > _chapterDragCommit;
              final armedNext = drag < -_chapterDragCommit;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: vertical ? Offset(0, drag * 0.5) : Offset(drag * 0.5, 0),
                      child: strip,
                    ),
                  ),
                  if (_zoomShrunk && currentTitle != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: pageH * (0.5 + _stripScale / 2) + 8 + (vertical ? drag * 0.5 : 0),
                      child: Center(child: _chapterLabel(currentTitle)),
                    ),
                  if (_zoomShrunk && vertical) ...[
                    if (prevTitle != null)
                      Positioned(
                        left: 24,
                        right: 24,
                        top: headerH + 10,
                        child: _chapterBox(prevTitle, up: true, armed: armedPrev, onTap: () => _goChapterInZoom(-1)),
                      ),
                    if (nextTitle != null)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 60,
                        child: _chapterBox(nextTitle, up: false, armed: armedNext, onTap: () => _goChapterInZoom(1)),
                      ),
                  ],
                  if (_zoomShrunk && !vertical) ...[
                    if (prevTitle != null)
                      Positioned(
                        left: 6,
                        top: pageH * 0.3,
                        bottom: pageH * 0.3,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: _chapterBox(prevTitle, up: true, armed: armedPrev, onTap: () => _goChapterInZoom(-1)),
                        ),
                      ),
                    if (nextTitle != null)
                      Positioned(
                        right: 6,
                        top: pageH * 0.3,
                        bottom: pageH * 0.3,
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: _chapterBox(nextTitle, up: false, armed: armedNext, onTap: () => _goChapterInZoom(1)),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Previous/next chapter box in the zoomed view; lights up once a drag
  /// would open it.
  Widget _chapterBox(String title, {required bool up, required bool armed, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: armed ? AppColors.accentLime.withValues(alpha: 0.9) : AppColors.figmaSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fg.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              up ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: armed ? Colors.black : AppColors.fgSubtle,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    up ? l10n.previousChapter : l10n.nextChapter,
                    style: GoogleFonts.sora(fontSize: 10, color: armed ? Colors.black54 : AppColors.fgSubtle),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 13, color: armed ? Colors.black : AppColors.fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Current chapter name under the centre card.
  Widget _chapterLabel(String title) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.figmaSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fg.withValues(alpha: 0.08)),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(fontSize: 12, color: AppColors.fgMuted),
        ),
      ),
    );
  }

  /// Definition of the selected word, on the half of the page away from it.
  Widget _buildLoadFailure(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.fgFaint, size: 40),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.goBack)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadTimeoutBanner(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.popoverSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fg.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.hourglass_empty_rounded, color: AppColors.fgSubtle, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.stillOpeningThisBook,
                  style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => NativeReaderScreen(
                        book: widget.book,
                        initialLocator: widget.initialLocator,
                      ),
                    ),
                  );
                },
                child: Text(l10n.reload),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Duration _chromeDuration = Duration(milliseconds: 260);

  /// Slides + fades the reader controls in/out instead of popping them.
  Widget _animatedChrome({required bool visible, required bool fromTop, required Widget child}) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          duration: _chromeDuration,
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : Offset(0, fromTop ? -0.12 : 0.12),
          child: AnimatedOpacity(
            duration: _chromeDuration,
            curve: Curves.easeOut,
            opacity: visible ? 1 : 0,
            child: Stack(children: [child]),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Figma opened_book header: back | title + position | menu, on the
    // reader background (no gradient, unlike the library screens).
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        key: _topBarKey,
        color: AppColors.figmaReaderBackground,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 15, 10),
            child: SegmentedTopBar(
              leading: const FigmaIcon(AssetConstants.iconBack, width: 9, height: 14),
              onLeadingTap: () => Navigator.of(context).pop(),
              middle: Padding(
                padding: const EdgeInsets.only(left: 29, right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.book.publication.metadata.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 15, height: 21 / 15, color: AppColors.fg),
                    ),
                    Text(
                      l10n.percentRead((_progress * 100).round()),
                      maxLines: 1,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        height: 20 / 13,
                        color: AppColors.figmaTextFaint,
                      ),
                    ),
                  ],
                ),
              ),
              onMiddleTap: _showTocSheet,
              trailing: const _ReaderMenuGlyph(),
              onTrailingTap: _showReaderMenu,
            ),
          ),
        ),
      ),
    );
  }

  /// The header's right-hand menu (design/reference-screenshots/boot_view_menu.png).
  Future<void> _showReaderMenu() async {
    final media = MediaQuery.of(context);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(media.size.width - 220, media.padding.top + 80, 15, 0),
      color: AppColors.figmaSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      items: [
        for (final (value, label) in [
          ('customize', l10n.customization),
          ('bookmark', l10n.bookmarkThisPage),
          ('search', l10n.searchInBook),
          ('chapters', l10n.chapters),
          ('original', l10n.originalLayout),
        ])
          PopupMenuItem<String>(
            value: value,
            height: 52,
            child: Text(label, style: GoogleFonts.sora(fontSize: 16, color: AppColors.fg)),
          ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'customize':
        _showCustomizationSheet();
      case 'bookmark':
        _addBookmark();
      case 'search':
        _showSearchSheet();
      case 'chapters':
        _showTocSheet();
      case 'original':
        await RendererChoice.set(widget.book.publication.id, RendererChoice.original);
        await _switchToOriginal();
    }
  }

  Widget _buildBottomBar(BuildContext context) {
    final shown = (_seekPreview ?? _progress).clamp(0.0, 1.0);
    // The bar itself seeks (tap or drag); anywhere else on the pill - the
    // percentage, the padding - opens Chapters & Notes, as it always did.
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showTocSheet,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
          decoration: BoxDecoration(
            color: AppColors.pillSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.fg.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ProgressScrubber(
                  value: shown,
                  enabled: _locationsReady,
                  onChanged: (v) {
                    _onUserActivity();
                    setState(() => _seekPreview = v);
                  },
                  onChangeEnd: _seekTo,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${(shown * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    color: _seekPreview != null ? AppColors.fg : AppColors.textFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scrolled mode: a thin line on the right edge showing where you are in
  /// the chapter. Drag it (or tap the track) to scroll there.
  Widget _buildScrollLine(BuildContext context, double insetTop, double insetBottom) {
    return ValueListenableBuilder<(double, double)>(
      valueListenable: _chapterScrollN,
      builder: (context, _, _) => _scrollLine(context, insetTop, insetBottom),
    );
  }

  Widget _scrollLine(BuildContext context, double insetTop, double insetBottom) {
    final visible = _chapterScroll >= 0 && _chapterVisible < 0.98;
    const trackPad = 12.0;
    return Positioned(
      top: insetTop + trackPad,
      bottom: insetBottom + trackPad,
      right: 0,
      width: 28,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: visible ? 1 : 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackH = constraints.maxHeight;
              final thumbH = (trackH * _chapterVisible).clamp(36.0, trackH);
              final top = (trackH - thumbH) * _chapterScroll.clamp(0.0, 1.0);
              void scrollToDy(double dy) {
                _onUserActivity();
                final ratio = ((dy - thumbH / 2) / (trackH - thumbH)).clamp(0.0, 1.0);
                _chapterScroll = ratio;
                _scrollToRatio(ratio);
              }

              final active = _draggingScrollLine;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (d) => scrollToDy(d.localPosition.dy),
                onVerticalDragStart: (d) {
                  setState(() => _draggingScrollLine = true);
                  scrollToDy(d.localPosition.dy);
                },
                onVerticalDragUpdate: (d) => scrollToDy(d.localPosition.dy),
                onVerticalDragEnd: (_) => setState(() => _draggingScrollLine = false),
                onVerticalDragCancel: () => setState(() => _draggingScrollLine = false),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 6,
                      width: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.fg.withValues(
                            alpha: _controlsVisible || active ? 0.10 : 0.0,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: active ? Duration.zero : const Duration(milliseconds: 90),
                      top: top,
                      right: active ? 4 : 5,
                      width: active ? 6 : 3,
                      height: thumbH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.accentLime
                              : AppColors.fg.withValues(alpha: _controlsVisible ? 0.55 : 0.32),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionMenu(BuildContext context, _SelectionMenuState menu) {
    const menuWidth = 220.0;
    return Container(
        width: menuWidth,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.popoverSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _highlightColors.entries
                    .map(
                      (e) => GestureDetector(
                        onTap: () => _addHighlight(menu.cfiRange, menu.selectedText, e.key),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: e.value, shape: BoxShape.circle),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Divider(height: 12, color: AppColors.dividerSubtle),
            ),
            _selectionMenuAction(
              Icons.note_add_outlined,
              l10n.addNote,
              () => _addNote(menu.cfiRange, menu.selectedText),
            ),
            _selectionMenuAction(
              Icons.menu_book_rounded,
              l10n.define,
              () => _defineSelection(menu.selectedText),
            ),
            _selectionMenuAction(
              Icons.copy_rounded,
              l10n.copy,
              () => _copySelection(menu.selectedText),
            ),
            _selectionMenuAction(
              Icons.search_rounded,
              l10n.search,
              () => _searchSelection(menu.selectedText),
            ),
            _selectionMenuAction(
              Icons.share_rounded,
              l10n.share,
              () => _shareSelection(menu.selectedText),
            ),
          ],
        ),
    );
  }

  /// Selection menu (next to the word) and the definition card (in the
  /// free space left), laid out from their real sizes.
  Widget _buildSelectionOverlay(
    BuildContext context,
    _SelectionMenuState menu,
    double insetTop,
    double pageBottom,
  ) {
    final size = MediaQuery.of(context).size;
    // sakura reports the selection relative to the page view, which starts
    // below the status bar.
    final word = menu.selectionRect.shift(Offset(0, insetTop));
    final defineWord = _defineWord;
    final lookup = _defineLookup;
    return Positioned.fill(
      child: CustomMultiChildLayout(
        delegate: _SelectionLayout(
          word: word,
          areaTop: insetTop + 8,
          areaBottom: size.height - pageBottom - 8,
        ),
        children: [
          LayoutId(id: _SelectionLayout.menu, child: _buildSelectionMenu(context, menu)),
          if (defineWord != null && lookup != null)
            LayoutId(
              id: _SelectionLayout.card,
              child: WordDefinitionCard(
                word: defineWord,
                lookup: lookup,
                onExpand: () => _defineSelection(defineWord),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionMenuAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.fgMuted),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fg)),
          ],
        ),
      ),
    );
  }
}

/// Figma "Group 651": two short bars, one long bar and three dots (15x15).
class _ReaderMenuGlyph extends StatelessWidget {
  const _ReaderMenuGlyph();

  @override
  Widget build(BuildContext context) {
    final faint = AppColors.figmaTextFaint;
    Widget bar(double w, Color c) => Container(
      width: w,
      height: 3.33,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
    );
    Widget dot() => Container(
      width: 3.89,
      height: 3.89,
      decoration: BoxDecoration(color: faint, borderRadius: BorderRadius.circular(10)),
    );
    return SizedBox(
      width: 15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [bar(8.89, AppColors.fg), const SizedBox(width: 1.11), bar(5, faint)]),
          const SizedBox(height: 2.2),
          bar(15, faint),
          const SizedBox(height: 2.2),
          Row(
            children: [
              dot(),
              const SizedBox(width: 1.66),
              dot(),
              const SizedBox(width: 1.66),
              dot(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Footer progress bar you can tap or drag to jump through the book.
/// Reports the dragged position live and commits it on release.
class _ProgressScrubber extends StatefulWidget {
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _ProgressScrubber({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<_ProgressScrubber> createState() => _ProgressScrubberState();
}

class _ProgressScrubberState extends State<_ProgressScrubber> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 12.0;
        final width = constraints.maxWidth - hPad * 2;
        double at(double dx) => ((dx - hPad) / width).clamp(0.0, 1.0);
        final x = hPad + width * widget.value;
        final thumb = _dragging ? 16.0 : 10.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.enabled ? (d) => widget.onChangeEnd(at(d.localPosition.dx)) : null,
          onHorizontalDragStart: widget.enabled
              ? (d) {
                  setState(() => _dragging = true);
                  widget.onChanged(at(d.localPosition.dx));
                }
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (d) => widget.onChanged(at(d.localPosition.dx))
              : null,
          onHorizontalDragEnd: widget.enabled
              ? (_) {
                  setState(() => _dragging = false);
                  widget.onChangeEnd(widget.value);
                }
              : null,
          child: SizedBox(
            height: 42,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: hPad,
                  right: hPad,
                  height: _dragging ? 5 : 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.fg.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: hPad,
                  width: (x - hPad).clamp(0.0, width),
                  height: _dragging ? 5 : 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accentLime,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: x - thumb / 2,
                  width: thumb,
                  height: thumb,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: widget.enabled ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accentLime,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Places the selection menu by the selected word (above it, or below when
/// there's no room) and the definition card in the larger free space left,
/// so neither covers the word or the other.
class _SelectionLayout extends MultiChildLayoutDelegate {
  static const menu = 'menu';
  static const card = 'card';
  static const _gap = 10.0;

  final Rect word;
  final double areaTop;
  final double areaBottom;

  _SelectionLayout({required this.word, required this.areaTop, required this.areaBottom});

  @override
  void performLayout(Size size) {
    final menuSize = layoutChild(menu, BoxConstraints.loose(size));
    var menuTop = word.top - _gap - menuSize.height;
    if (menuTop < areaTop) menuTop = word.bottom + _gap;
    menuTop = menuTop.clamp(areaTop, math.max(areaTop, areaBottom - menuSize.height)).toDouble();
    final double menuLeft = (word.center.dx - menuSize.width / 2).clamp(
      12.0,
      math.max(12.0, size.width - menuSize.width - 12),
    );
    positionChild(menu, Offset(menuLeft, menuTop));

    if (!hasChild(card)) return;
    final busyTop = math.min(word.top, menuTop) - _gap;
    final busyBottom = math.max(word.bottom, menuTop + menuSize.height) + _gap;
    final above = busyTop - areaTop;
    final below = areaBottom - busyBottom;
    final useBelow = below >= above;
    final room = math.max(96.0, useBelow ? below : above);
    final cardSize = layoutChild(
      card,
      BoxConstraints(minWidth: size.width - 24, maxWidth: size.width - 24, maxHeight: room),
    );
    positionChild(
      card,
      Offset(12, useBelow ? areaBottom - cardSize.height : areaTop),
    );
  }

  @override
  bool shouldRelayout(_SelectionLayout old) =>
      old.word != word || old.areaTop != areaTop || old.areaBottom != areaBottom;
}


/// Scrolled mode: heavier fling than the platform default (the reader's feel).
class _HeavyScrollPhysics extends ScrollPhysics {
  const _HeavyScrollPhysics({super.parent});

  @override
  _HeavyScrollPhysics applyTo(ScrollPhysics? ancestor) => _HeavyScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final sim = super.createBallisticSimulation(position, velocity);
    if (sim is ClampingScrollSimulation) {
      return ClampingScrollSimulation(
        position: position.pixels,
        velocity: velocity,
        friction: 0.03,
        tolerance: toleranceFor(position),
      );
    }
    return sim;
  }
}

/// The selection on the page (tinted line rects) with a drag handle at each end.
class _SelectionHandles extends StatelessWidget {
  final List<Rect> rects;
  final Color color;
  final void Function(bool startHandle) onDragStart;
  final void Function(Offset local) onDrag;
  final VoidCallback onDragEnd;
  final bool showHandles;

  const _SelectionHandles({
    required this.rects,
    this.showHandles = true,
    required this.color,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (rects.isEmpty) return const SizedBox.shrink();
    Widget handle(Offset at, bool start) => Positioned(
          left: at.dx - 16,
          top: at.dy - 4,
          width: 32,
          height: 32,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onDragStart(start),
            onPanUpdate: (d) {
              final box = context.findRenderObject() as RenderBox;
              // The finger sits below the line it's selecting.
              onDrag(box.globalToLocal(d.globalPosition) - const Offset(0, 22));
            },
            onPanEnd: (_) => onDragEnd(),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        );
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _SelectionPainter(rects, color.withValues(alpha: 0.3)))),
        ),
        if (showHandles) handle(rects.first.bottomLeft, true),
        if (showHandles) handle(rects.last.bottomRight, false),
      ],
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final List<Rect> rects;
  final Color color;
  _SelectionPainter(this.rects, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final r in rects) {
      canvas.drawRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => old.rects != rects || old.color != color;
}
