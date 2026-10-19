import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show CompressFormat, PermissionResponse, PermissionResponseAction, ScreenshotConfiguration;
import 'package:google_fonts/google_fonts.dart';
import 'package:sakura_epub/sakura_epub.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/commands/reader_command.dart';
import '../../application/mappers/sakura_epub_mapper.dart';
import '../../application/session/reading_session.dart';
import '../../data/engine/sakura_fonts.dart';
import '../../data/engine/sakura_reading_behavior.dart';
import '../../data/repositories/sqlite_reader_preferences_repository.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/locator.dart';
import '../../domain/entities/nav_item.dart';
import '../../domain/entities/reader_preferences.dart';
import '../platform/app_haptics.dart';
import '../platform/epub_unpacker.dart';
import '../state/app_preferences.dart';
import '../state/reader_usage_mixin.dart';
import '../state/library_controller.dart';
import '../utils/reader_tap_tracker.dart';
import '../../core/constants/asset_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_controller.dart';
import '../layout/adaptive_sheet.dart';
import '../layout/reader_pane_layout.dart';
import '../layout/spread.dart';
import '../widgets/app_chrome.dart';
import '../widgets/page_curl.dart';
import '../widgets/reader_page_skeleton.dart';
import '../widgets/sakura_customization_sheet.dart';
import '../widgets/sakura_search_sheet.dart';
import '../widgets/sakura_toc_sheet.dart';
import '../widgets/word_definition_sheet.dart';
import '../native_reader/renderer_choice.dart';
import 'native_reader_screen.dart';
import '../../data/dictionary/dictionary_service.dart';

/// Book view screen for the sakura_epub (WebView + epub.js) rendering engine
/// - used on Android/iOS/Windows/macOS. See ReaderScreen for the Linux/Web
/// fallback built on the pure-Flutter epubx renderer; ReaderLauncher picks
/// between the two per platform. Persistence (annotations, bookmarks,
/// progress, per-book preferences) goes through the same ReadingSession/
/// SQLite repositories either engine uses, so switching engines never means
/// switching storage.
class SakuraReaderScreen extends StatefulWidget {
  final BookItem book;
  final Locator? initialLocator;

  const SakuraReaderScreen({super.key, required this.book, this.initialLocator});

  @override
  State<SakuraReaderScreen> createState() => _SakuraReaderScreenState();
}

class _SelectionMenuState {
  final String selectedText;
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

  /// The page doing the curling, and the one lying under it (null = the
  /// live WebView shows through).
  ui.Image? front;
  ui.Image? back;

  /// Finger offset from where the drag started, logical px.
  double dx = 0;
  double velocity = 0;

  /// Where the page was before the turn (to return to on cancel).
  String? originCfi;

  /// Snapshots taken and the WebView already moved underneath.
  bool ready = false;
  bool released = false;

  /// The WebView moved a page for this turn (undone if it's cancelled).
  bool moved = false;

  /// No snapshot could be taken: just turn the page, no animation.
  bool plain = false;

  void dispose() {
    front?.dispose();
    back?.dispose();
  }
}

class _SakuraReaderScreenState extends State<SakuraReaderScreen>
    with ReaderUsageMixin, SingleTickerProviderStateMixin {
  @override
  BookItem get usageBook => widget.book;

  late final ReadingSession _session;
  late final EpubController _epubController;
  late final Future<File> _bookFileFuture;
  late ReaderPreferences _preferences;

  // The reading mode the open page is currently laid out in.
  late ScrollMode _appliedScrollMode;

  bool _epubReady = false;
  bool _loadTimedOut = false;
  bool _loadWatchdogStarted = false;
  Timer? _loadTimeoutTimer;
  // Header and footer show/hide together on tap, but auto-hide separately
  // after a stretch without interaction: header first, then the footer.
  // Hidden on open, so the header never covers the first lines; a tap
  // shows them.
  bool _topVisible = false;
  bool _bottomVisible = false;
  bool get _controlsVisible => _topVisible || _bottomVisible;

  /// Expanded windows: panes and toolbar show unless the reader tapped into
  /// focus mode. The phone-style floating bars (and their zoom-out) stay off.
  bool _focusMode = false;
  bool _panes = false;

  /// Two-page spread currently applied to epub.js (book pane >= 900 wide).
  bool _spread = false;
  Timer? _spreadTimer;

  final _readerFocus = FocusNode(debugLabel: 'sakura-reader');
  Timer? _topHideTimer;
  Timer? _bottomHideTimer;
  static const _topAutoHide = Duration(seconds: 3);
  static const _bottomAutoHide = Duration(seconds: 5);
  double _progress = 0.0;

  // Footer scrubber: the position being dragged to (null when idle), and
  // whether epub.js has counted the book's locations (needed to jump).
  double? _seekPreview;
  bool _locationsReady = false;

  // Scrolled mode: position inside the current chapter (0..1, -1 when
  // unknown/paginated) and how much of the chapter fits on screen.
  // Updated on every scroll frame, so kept out of setState: only the
  // scroll line listens to it.
  final _chapterScrollN = ValueNotifier<(double, double)>((-1, 1));
  double get _chapterScroll => _chapterScrollN.value.$1;
  double get _chapterVisible => _chapterScrollN.value.$2;
  set _chapterScroll(double v) => _chapterScrollN.value = (v, _chapterVisible);
  bool _draggingScrollLine = false;

  // In-app dimming from the customization sheet's Brightness slider (1 = off).
  double _brightness = 1.0;
  EpubLocation? _lastLocation;
  List<NavItem> _toc = [];
  _SelectionMenuState? _selectionMenu;

  Timer? _positionSaveDebounce;
  Timer? _scrollDebounceTimer;
  double _accumulatedScrollDelta = 0;

  // A GestureDetector wrapping EpubViewer never actually sees taps: the
  // native WebView underneath claims the pointer before Flutter's gesture
  // arena does (this is why "tap to toggle controls" looked unresponsive -
  // it wasn't debounced or slow, it just never fired). EpubViewer's own
  // onTouchDown/onTouchUp report normalized coordinates via its JS bridge
  // instead, which does work reliably; a real tap is a down/up pair close
  // together, a swipe/page-turn is one far apart.
  Timer? _pendingTapToggle;

  // Chapter lock-swipe (scrolled mode), reported by SakuraReadingBehavior:
  // direction (1 next, -1 previous, 0 idle), fill 0..1, whether that
  // chapter exists, and whether the fill has reached the lock point.
  int _swipeDir = 0;
  double _swipeProgress = 0;
  bool _swipeAvailable = true;
  bool _swipeArmed = false;
  final _tapTracker = ReaderTapTracker();

  // Page curl (paginated mode).
  _PageTurn? _turn;
  bool _ignoreTurnGesture = false;
  // Curl position, updated every animation frame: only the curl painter
  // listens to it (a setState per frame rebuilt the whole reader).
  final _turnEdgeN = ValueNotifier<double>(0);
  double get _turnEdge => _turnEdgeN.value;
  set _turnEdge(double v) => _turnEdgeN.value = v;

  // Unpacked book served natively (Android), or null for the bytes path.
  EpubServedBook? _servedBook;

  // The WebView widget, built once: rebuilding the screen (page turns,
  // controls, footer) then never touches the platform view.
  Widget? _viewer;

  // Skeleton over the page until the first layout has settled.
  bool _laidOut = false;


  late final AnimationController _turnAnim;
  ui.FragmentProgram? _curlProgram;
  // Width of the page area, for turning finger movement into curl position.
  double _pageWidth = 360;

  // Footer: estimated pages left in the book (-1 = not known yet).
  int _pagesLeft = -1;
  static const double _footerHeight = 28;

  // Zoomed-out page strip (paginated, while the header/footer show): the
  // page shrinks into a card with its neighbours beside it, swipeable.
  // Snapshots of the previous/current/next page; null = none/not yet.
  final List<ui.Image?> _strip = [null, null, null];
  bool _zoomed = false; // strip on screen
  bool _zoomShrunk = false; // card at its small size (animates from full)
  bool _stripBusy = false; // WebView being moved to take neighbour shots
  // Position reports from those moves arrive a little late; ignore them
  // until this time too, then re-read the real position.
  DateTime _stripQuietUntil = DateTime(0);
  bool get _stripQuiet => _stripBusy || DateTime.now().isBefore(_stripQuietUntil);
  Timer? _stripSyncTimer;
  Future<void> _stripQueue = Future.value();
  int _zoomSession = 0;
  PageController? _stripController;
  static const _zoomDuration = Duration(milliseconds: 260);

  // Chapters in the zoomed view: current/previous/next (title + href), and
  // the cross-axis drag that changes chapter (vertical when paginated,
  // horizontal when scrolled).
  Map<String, dynamic>? _chapterInfo;
  final _chapterDragN = ValueNotifier<double>(0);
  static const double _chapterDragCommit = 70;

  // Inline dictionary card for a selected single word.
  String? _defineWord;
  Future<WordDefinition>? _defineLookup;

  static const _highlightColors = <String, Color>{
    '#FFEB3B': Color(0xFFFFEB3B), // yellow
    '#4CAF50': Color(0xFF4CAF50), // green
    '#F44336': Color(0xFFF44336), // red
    '#2196F3': Color(0xFF2196F3), // blue
    '#9C27B0': Color(0xFF9C27B0), // purple
  };

  @override
  void initState() {
    super.initState();
    _session = widget.book.session;
    _preferences = _session.state.preferences;
    _appliedScrollMode = _preferences.scrollMode;
    // Show the saved progress right away instead of 0% until the first
    // relocation arrives.
    _progress = widget.book.progress.clamp(0.0, 1.0);
    _epubController = EpubController();
    _turnAnim = AnimationController(vsync: this);
    PageCurl.program().then((p) {
      if (mounted) _curlProgram = p;
    });
    // Must be a real file on disk (EpubSource.fromFile reads it directly) -
    // getBookFile alone only builds the path, it doesn't guarantee the file
    // is actually there. A restored publication whose app_books/<id>.epub
    // was never written (or fell back to an in-memory sample) used to hang
    // forever on "loading chapters" here with no visible error, since the
    // WebView's loadBook() throws trying to read a file that doesn't exist.
    final file = LibraryController.instance.ensureBookFileOnDisk(
      widget.book.publication.id,
      widget.book.archiveBytes,
    );
    _bookFileFuture = Future.wait<Object?>([
      // Android: unpack natively once and serve the files to the WebView
      // (much faster than pushing the whole book through the JS bridge).
      file.then((f) async {
        _servedBook = await EpubUnpacker.serve(widget.book.publication.id, f);
        return f;
      }),
      _useCurrentDefaultsIfUnsaved().then((_) => _loadOpeningShot()),
    ]).then((results) => results.first as File);
  }

  /// A book nobody has customised yet opens with today's defaults - they
  /// follow the app theme, which may have changed since the library loaded
  /// this book's (default) settings.
  Future<void> _useCurrentDefaultsIfUnsaved() async {
    try {
      final saved = await SqliteReaderPreferencesRepository().hasSavedPreferences(
        widget.book.publication.id,
      );
      if (!saved && mounted) {
        _preferences = AppPreferences.instance.readerDefaults;
        _appliedScrollMode = _preferences.scrollMode;
      }
    } catch (e) {
      debugPrint('SakuraReader: could not check saved preferences: $e');
    }
  }

  void _toggleControls() {
    if (_panes) {
      setState(() => _focusMode = !_focusMode);
      return;
    }
    _setControls(!_controlsVisible);
  }

  /// Book pane width changed: switch between one and two pages (debounced,
  /// so dragging a window edge doesn't re-lay out the book every frame).
  void _syncSpread(double paneWidth) {
    final want = useSpread(paneWidth) && _preferences.scrollMode != ScrollMode.continuous;
    if (want == _spread) {
      _spreadTimer?.cancel();
      return;
    }
    _spreadTimer?.cancel();
    _spreadTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !_epubReady) return;
      _spread = want;
      _epubController.setSpread(spread: want ? EpubSpread.always : EpubSpread.none);
    });
  }

  // Header measured for the scrolled-mode shift (see _syncHeaderShift).
  final _topBarKey = GlobalKey();
  bool _shownOnOpen = false;

  /// Scrolled mode: while the header shows, the text moves down by its
  /// height so nothing is hidden behind it (paginated zooms out instead).
  void _syncHeaderShift() {
    if (!_epubReady) return;
    // Both modes now zoom the page out below the header, so the text is
    // never covered and must not be moved (it would also spoil the zoomed
    // snapshot). Keeps any earlier shift reset.
    SakuraReadingBehavior.shiftTop(_epubController, 0);
  }

  void _setControls(bool visible) {
    if (!mounted) return;
    // Expanded: the toolbar and panes replace the floating bars.
    if (visible && _panes) return;
    setState(() {
      _topVisible = visible;
      _bottomVisible = visible;
    });
    // After the frame, so the header has a size to measure.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncHeaderShift();
    });
    if (visible) {
      _enterZoom();
    } else {
      _exitZoom();
    }
    if (visible) {
      _scheduleAutoHide();
    } else {
      _topHideTimer?.cancel();
      _bottomHideTimer?.cancel();
    }
  }

  /// Restarts the inactivity countdowns for whichever bars are showing.
  void _scheduleAutoHide() {
    _topHideTimer?.cancel();
    _bottomHideTimer?.cancel();
    if (_topVisible) _topHideTimer = Timer(_topAutoHide, () => _autoHide(top: true));
    if (_bottomVisible) _bottomHideTimer = Timer(_bottomAutoHide, () => _autoHide(top: false));
  }

  /// Any interaction counts as activity and restarts the countdowns.
  void _onUserActivity() {
    if (_controlsVisible) _scheduleAutoHide();
  }

  void _autoHide({required bool top}) {
    if (!mounted) return;
    // Hold while something is in use: a sheet/menu/dialog over the reader,
    // a drag on the scrubber or scroll line, or the selection menu.
    final busy =
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
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
    if (top) _syncHeaderShift();
    if (!_controlsVisible) _exitZoom();
  }

  @override
  void dispose() {
    _topHideTimer?.cancel();
    _bottomHideTimer?.cancel();
    // Leaving within the save debounce used to drop the last position.
    if (_positionSaveDebounce?.isActive ?? false) {
      _positionSaveDebounce!.cancel();
      final loc = _lastLocation;
      if (loc != null) _savePosition(loc);
    }
    _scrollDebounceTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    _pendingTapToggle?.cancel();
    _stripSyncTimer?.cancel();
    _shotSaveTimer?.cancel();
    _resizeTimer?.cancel();
    _spreadTimer?.cancel();
    _readerFocus.dispose();
    _openingShot?.dispose();
    _turnAnim.dispose();
    _turn?.dispose();
    _turnEdgeN.dispose();
    _chapterDragN.dispose();
    _chapterScrollN.dispose();
    _stripController?.dispose();
    for (final img in _strip) {
      img?.dispose();
    }
    super.dispose();
  }

  /// Where to open: an explicit target (Saved screen), else where the
  /// reader left off, else the start of the book.
  String? get _startCfi {
    // After a reading-mode switch the view restarts where the reader was.
    final reopen = _reopenCfi;
    if (reopen != null) return reopen;
    final target = widget.initialLocator ?? _session.state.currentLocator;
    final cfi = target?.locations.cfi ?? target?.href;
    return cfi != null && cfi.startsWith('epubcfi(') ? cfi : (widget.initialLocator?.href);
  }

  Color _colorForHex(String hex) =>
      _highlightColors[hex.toUpperCase()] ?? _highlightColors.values.first;

  /// If the book still hasn't loaded after a generous wait, say so instead
  /// of leaving what looks like a permanently stuck spinner - the WebView
  /// gives no error callback for "the page never called back", so this is
  /// the only way to surface a hang instead of silently doing nothing.
  void _startLoadTimeoutWatchdog() {
    if (_loadWatchdogStarted) return;
    _loadWatchdogStarted = true;
    _loadTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && !_epubReady) setState(() => _loadTimedOut = true);
    });
  }

  void _onEpubLoaded() async {
    // sakura_epub calls this on *every* epub.js "displayed" event (each
    // chapter/re-render), not once. Setting up again each time re-rendered
    // the book in a loop - the open-book flicker. Set up once.
    if (_epubReady) return;
    _loadTimeoutTimer?.cancel();
    Timer(const Duration(seconds: 6), () {
      if (mounted && !_laidOut) setState(() => _laidOut = true);
    });
    setState(() {
      _epubReady = true;
      _loadTimedOut = false;
    });
    _scheduleAutoHide();
    _epubController.webViewController?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.navigatedHandler,
      callback: (_) => _pendingTapToggle?.cancel(),
    );

    _epubController.webViewController?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.swipeProgressHandler,
      callback: _onSwipeProgress,
    );
    _epubController.webViewController?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.swipeEndHandler,
      callback: (_) {
        if (mounted) setState(_resetSwipe);
      },
    );

    _epubController.webViewController?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.scrollHandler,
      callback: _onChapterScroll,
    );
    final js = _epubController.webViewController;
    js?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.turnStartHandler,
      callback: _onTurnStart,
    );
    js?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.turnMoveHandler,
      callback: _onTurnMove,
    );
    js?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.turnEndHandler,
      callback: _onTurnEnd,
    );
    js?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.tapHandler,
      callback: (_) => _onPageTap(),
    );
    js?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.dragHandler,
      callback: (_) => _pendingTapToggle?.cancel(),
    );
    js?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.laidOutHandler,
      callback: (_) {
        if (!mounted) return;
        _layoutConfirmed = true;
        if (!_laidOut) setState(() => _laidOut = true);
        _syncHeaderShift();
        // Open with the controls showing, the page zoomed out (paginated)
        // or moved below the header (scrolled), so nothing is covered.
        if (!_shownOnOpen) {
          _shownOnOpen = true;
          _setControls(true);
        }
      },
    );
    js?.addJavaScriptHandler(
      handlerName: SakuraReadingBehavior.pagesHandler,
      callback: (args) {
        if (!mounted || args.isEmpty || _stripQuiet) return;
        final left = (args[0] as num?)?.toInt() ?? -1;
        if (left != _pagesLeft) setState(() => _pagesLeft = left);
      },
    );
    _epubController.webViewController?.addJavaScriptHandler(
      handlerName: 'areadToggleMenu',
      callback: (_) {
        if (mounted) {
          _toggleControls();
        }
      },
    );
    final webView = _epubController.webViewController;
    final currentSettings = await webView?.getSettings();
    if (currentSettings != null) {
      final scrolled = _preferences.scrollMode == ScrollMode.continuous;
      currentSettings.disableVerticalScroll = !scrolled;
      await webView?.setSettings(settings: currentSettings);
    }
    await SakuraReadingBehavior.apply(
      _epubController,
      chapterScroll: _preferences.scrollMode == ScrollMode.continuous,
      marginHorizontal: AppPreferences.instance.readerPadding,
      backgroundColor: SakuraEpubMapper.hexPageColorFor(_preferences.theme),
      pageCurl: true,
    );
    // The saved font was only ever sent on a live change, so every book
    // opened in the engine's default font.
    await _applyFont(_preferences);
    await _loadCachedLocations();
    // Re-apply any highlights/notes saved from a previous session - sakura_epub
    // only knows about highlights added in the current page's JS DOM. Notes
    // are shown as highlights too (in their saved color), so you can see
    // where a note is attached.
    for (final a in _session.state.annotations) {
      if (a.type != AnnotationType.highlight && a.type != AnnotationType.note) continue;
      final cfi = a.locator.locations.cfi ?? a.locator.href;
      if (cfi.isEmpty) continue;
      _epubController.addHighlight(cfi: cfi, color: _colorForHex(a.colorHex));
    }
  }

  void _onSwipeProgress(List<dynamic> args) {
    if (!mounted || args.length < 3) return;
    final dir = (args[0] as num).toInt();
    final progress = (args[1] as num).toDouble().clamp(0.0, 1.0);
    final available = args[2] == true;
    // A drag that became a swipe is not a tap.
    _pendingTapToggle?.cancel();
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

  void _resetSwipe() {
    _swipeDir = 0;
    _swipeProgress = 0;
    _swipeArmed = false;
  }

  void _onChaptersLoaded(List<EpubChapter> chapters) {
    setState(() => _toc = SakuraEpubMapper.navItemsFromChapters(chapters));
  }

  void _onRelocated(EpubLocation location) {
    // The strip moves the hidden WebView back and forth to photograph the
    // neighbouring pages; those moves aren't the reader's position.
    if (_stripQuiet) return;
    setState(() {
      _lastLocation = location;
      // Before epub.js has counted the book's locations every position
      // reads 0% - keep showing the saved progress until then.
      if (_locationsReady) _progress = location.progress;
    });

    _scheduleShotSave(location);
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(milliseconds: 600), () => _savePosition(location));
  }

  void _savePosition(EpubLocation location) {
    _session.dispatchCommand(
      NavigateToLocatorCommand(
        SakuraEpubMapper.locatorFromLocation(
          location,
          // Not counted yet: saving 0% would wipe the real progress.
          progress: _locationsReady ? null : _progress,
        ),
      ),
    );
  }

  /// epub.js has counted the book's locations: re-report the position so
  /// the percentage is real (the first report always says 0%).
  void _onLocationLoaded() {
    if (!mounted) return;
    final cached = _cachedLocations;
    if (cached != null) {
      // Background count finished anyway; reload the saved list so nothing
      // it appended meanwhile lingers.
      SakuraReadingBehavior.loadLocations(_epubController, cached);
    } else {
      _saveLocations();
    }
    setState(() => _locationsReady = true);
    SakuraReadingBehavior.reportLocation(_epubController);
    // The book is counted: now load the rest of it in the background so
    // jumps anywhere are quick.
    SakuraReadingBehavior.preloadBook(_epubController);
  }

  // --- saved locations ---------------------------------------------------
  // epub.js counts the whole book (fixed-size text chunks) on every open
  // before it can give percentages, page counts or jump anywhere - seconds
  // on a long book. The count is saved per book and loaded on later opens.

  String? _cachedLocations;

  Future<File> _locationsFile() async {
    final book = await LibraryController.instance.getBookFile(widget.book.publication.id);
    return File('${book.path}.locations.json');
  }

  Future<void> _loadCachedLocations() async {
    try {
      final file = await _locationsFile();
      if (!await file.exists()) return;
      final json = await file.readAsString();
      final count = await SakuraReadingBehavior.loadLocations(_epubController, json);
      if (count > 0 && mounted) {
        _cachedLocations = json;
        setState(() => _locationsReady = true);
      }
    } catch (e) {
      debugPrint('SakuraReader: saved locations unusable: $e');
    }
  }

  Future<void> _saveLocations() async {
    try {
      final json = await SakuraReadingBehavior.saveLocations(_epubController);
      if (json != null) await (await _locationsFile()).writeAsString(json);
    } catch (e) {
      debugPrint('SakuraReader: could not save locations: $e');
    }
  }

  void _onChapterScroll(List<dynamic> args) {
    if (!mounted || args.length < 2 || _draggingScrollLine) return;
    final ratio = (args[0] as num).toDouble();
    final visible = (args[1] as num).toDouble();
    if ((ratio - _chapterScroll).abs() < 0.002 && (visible - _chapterVisible).abs() < 0.01) return;
    _chapterScrollN.value = (ratio, visible.clamp(0.0, 1.0));
  }

  void _seekTo(double fraction) {
    _onUserActivity();
    setState(() => _seekPreview = null);
    if (!_epubReady || !_locationsReady) return;
    _epubController.toProgressPercentage(fraction.clamp(0.0, 1.0));
    if (_zoomed) {
      // The cards showed the old place: photograph the new one.
      final session = _zoomSession;
      Timer(const Duration(milliseconds: 500), () => _refreshStrip(session));
    }
  }

  void _defineSelection(String text) {
    setState(() => _selectionMenu = null);
    _epubController.clearSelection();
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

  void _onSelection(String text, String cfiRange, Rect selectionRect, Rect viewRect) {
    // A single word gets its definition straight away, like Play Books.
    final word = DictionaryService.wordFrom(text);
    final trimmed = text.trim().replaceAll(RegExp(r'[^\p{L}]+$', unicode: true), '');
    final single = word != null && word.length >= trimmed.length;
    setState(() {
      _selectionMenu = _SelectionMenuState(
        selectedText: text,
        cfiRange: cfiRange,
        selectionRect: selectionRect,
      );
      if (!single) {
        _defineWord = null;
        _defineLookup = null;
      } else if (word != _defineWord) {
        _defineWord = word;
        _defineLookup = DictionaryService.instance.define(word);
        // A failed lookup must not surface as an unhandled error.
        _defineLookup!.ignore();
      }
    });
  }

  void _onDeselection() {
    setState(() {
      _selectionMenu = null;
      _defineWord = null;
      _defineLookup = null;
    });
  }

  void _onTouchDown(double x, double y) {
    // A fresh down means any previous up callback was either duplicated by
    // the WebView bridge or belonged to a gesture that did not complete.
    _pendingTapToggle?.cancel();
    _tapTracker.start(x, y);
    _onUserActivity();
  }

  void _onTouchUp(double x, double y) {
    // Taps are detected by the page itself (areadTap): sakura reports
    // down/up from several listeners, in an order that let swipes pass as
    // taps.
    _tapTracker.finish(x, y);
  }

  void _onPageTap() {
    // A tap that ends a text selection shouldn't also toggle the controls.
    if (!mounted || _selectionMenu != null) return;
    // Wait a beat: if the touch turned out to navigate, the page reports it
    // (areadNavigated) and the toggle is cancelled.
    _pendingTapToggle?.cancel();
    _pendingTapToggle = Timer(const Duration(milliseconds: 150), () {
      if (mounted && _selectionMenu == null) _toggleControls();
    });
  }

  void _addHighlight(String cfiRange, String text, String colorHex) {
    _epubController.addHighlight(cfi: cfiRange, color: _colorForHex(colorHex));
    _epubController.clearSelection();
    _session.dispatchCommand(
      CreateAnnotationCommand(
        locator: Locator(
          href: cfiRange,
          locations: LocationParameters(cfi: cfiRange),
        ),
        textQuote: text,
        colorHex: colorHex,
        type: AnnotationType.highlight,
      ),
    );
    setState(() => _selectionMenu = null);
  }

  Future<void> _copySelection(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _selectionMenu = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
    }
  }

  void _searchSelection(String text) {
    setState(() => _selectionMenu = null);
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SakuraSearchSheet(
        controller: _epubController,
        initialQuery: text,
        onNavigateToCfi: (cfi) => _epubController.display(cfi: cfi),
      ),
    );
  }

  Future<void> _shareSelection(String text) async {
    setState(() => _selectionMenu = null);
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _addNote(String cfiRange, String text) async {
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
              style: GoogleFonts.sora(
                fontSize: 13,
                color: AppColors.textFaint,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              autofocus: true,
              maxLines: 3,
              style: TextStyle(color: AppColors.fg),
              decoration: InputDecoration(
                hintText: l10n.writeANote,
                hintStyle: TextStyle(color: AppColors.fgFaint),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(noteController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || note.isEmpty) return;

    const colorHex = '#FFEB3B';
    _epubController.addHighlight(cfi: cfiRange, color: _colorForHex(colorHex));
    _session.dispatchCommand(
      CreateAnnotationCommand(
        locator: Locator(
          href: cfiRange,
          locations: LocationParameters(cfi: cfiRange),
        ),
        textQuote: text,
        note: note,
        colorHex: colorHex,
        type: AnnotationType.note,
      ),
    );
  }

  void _onAnnotationClicked(String cfiRange, Map<String, dynamic>? rect) {
    final match = _session.state.annotations.where(
      (a) => (a.locator.locations.cfi ?? a.locator.href) == cfiRange,
    );
    if (match.isEmpty) return;
    final annotation = match.first;

    _epubController.removeHighlight(cfi: cfiRange);
    _session.dispatchCommand(DeleteAnnotationCommand(annotation.id));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.highlightRemoved),
          persist: false,
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () {
              _epubController.addHighlight(cfi: cfiRange, color: _colorForHex(annotation.colorHex));
              _session.dispatchCommand(
                CreateAnnotationCommand(
                  locator: annotation.locator,
                  textQuote: annotation.textQuote,
                  colorHex: annotation.colorHex,
                  type: AnnotationType.highlight,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _addBookmark() {
    final loc = _lastLocation;
    if (loc == null) return;
    _session.dispatchCommand(
      CreateBookmarkCommand(
        locator: SakuraEpubMapper.locatorFromLocation(loc),
        title: l10n.bookmarkAtPercent((loc.progress * 100).round()),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.bookmarkedCurrentLocation),
        backgroundColor: AppColors.accentLime,
      ),
    );
  }

  Future<void> _applyPreferencesLive(ReaderPreferences prefs) async {
    if (!_epubReady) return;
    // The zoom strip moves the hidden page to photograph its neighbours;
    // let that finish (and stop more) so the position below is the real one.
    _zoomSession++;
    await _stripQueue;
    if (!mounted) return;
    final scrolled = prefs.scrollMode == ScrollMode.continuous;
    // Where the reader is now, captured before anything re-lays out.
    final restoreCfi =
        await SakuraReadingBehavior.currentCfi(_epubController) ?? _lastLocation?.startCfi;
    if (!mounted) return;
    final flowChanged = prefs.scrollMode != _appliedScrollMode;
    _appliedScrollMode = prefs.scrollMode;
    if (flowChanged) {
      // Restart the book view in the new mode (a fresh WebView at the same
      // place). Re-laying out the old one in place left images missing
      // until the book was reopened.
      _restartViewer(restoreCfi);
      return;
    }

    await _epubController.setFontSize(fontSize: prefs.fontSize);
    // The reading mode itself is switched by SakuraReadingBehavior.apply
    // below, not sakura's setFlow: that re-displays the book on its own, and
    // racing apply's own re-display left a blank page.

    // setFlow only changes epub.js's own layout. EpubViewer separately
    // disables the *native* WebView's vertical scroll at creation time
    // (tied to EpubDisplaySettings.snap, which can't be changed live), so
    // switching to Scrolled without this leaves content that's logically
    // scrollable but a WebView that still blocks the scroll gesture.
    final webView = _epubController.webViewController;
    final currentSettings = await webView?.getSettings();
    if (currentSettings != null) {
      currentSettings.disableVerticalScroll = !scrolled;
      await webView?.setSettings(settings: currentSettings);
    }

    await _epubController.updateTheme(theme: SakuraEpubMapper.themeForPreferences(prefs));
    await _applyFont(prefs);
    await SakuraReadingBehavior.apply(
      _epubController,
      chapterScroll: scrolled,
      marginHorizontal: AppPreferences.instance.readerPadding,
      backgroundColor: SakuraEpubMapper.hexPageColorFor(prefs.theme),
      restoreCfi: restoreCfi,
      pageCurl: true,
    );
  }

  /// Shows the skeleton until the page reports its new layout (with a
  /// fallback, so a lost signal can never leave it covered).
  // Rotation / window resize: the page must be laid out again for the new
  // size. With a word selected, sakura blocked epub.js's own re-layout
  // (it reverts any move while a selection is active) and the page stayed
  // blank behind the selection menu.
  Size? _lastScreenSize;
  Timer? _resizeTimer;

  void _onScreenResized() {
    if (!mounted || !_epubReady) return;
    final cfi = _lastLocation?.startCfi;
    _epubController.clearSelection();
    _cancelTurn();
    _zoomSession++;
    setState(() {
      _selectionMenu = null;
      _defineWord = null;
      _defineLookup = null;
      _zoomed = false;
      _zoomShrunk = false;
    });
    for (var i = 0; i < 3; i++) {
      _setStrip(i, null);
    }
    _coverUntilLaidOut();
    // Let the WebView finish resizing, then lay out once at the old place.
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) SakuraReadingBehavior.relayout(_epubController, cfi);
    });
  }

  // After a mode switch the opening picture no longer matches the page.
  bool _appliedModeChangedSinceOpen = false;

  void _coverUntilLaidOut() {
    _layoutConfirmed = false;
    setState(() {
      _laidOut = false;
      _appliedModeChangedSinceOpen = true;
    });
    Timer(const Duration(seconds: 4), () {
      if (mounted && !_laidOut) setState(() => _laidOut = true);
    });
  }

  // Set when the view restarts (mode switch): where to open it.
  String? _reopenCfi;
  int _viewerGeneration = 0;

  void _restartViewer(String? cfi) {
    _cancelTurn();
    _zoomSession++;
    _resizeTimer?.cancel();
    for (var i = 0; i < 3; i++) {
      _setStrip(i, null);
    }
    _reopenCfi = cfi ?? _lastLocation?.startCfi;
    _layoutConfirmed = false;
    setState(() {
      _viewer = null; // rebuilt with the new flow and a new key
      _viewerGeneration++;
      _epubReady = false;
      _loadWatchdogStarted = false;
      _loadTimedOut = false;
      _laidOut = false;
      _appliedModeChangedSinceOpen = true;
      _locationsReady = false;
      _zoomed = false;
      _zoomShrunk = false;
      _chapterScroll = -1;
      _pagesLeft = -1;
      _selectionMenu = null;
    });
  }

  // --- page curl -------------------------------------------------------

  bool get _paginated => _preferences.scrollMode == ScrollMode.paginated;

  /// [width] (logical px) scales the snapshot down - strip cards are shown
  /// at 62% size, so photographing them full size only cost time.
  Future<Uint8List?> _captureBytes({double? width}) async {
    try {
      final bytes = await _epubController.webViewController?.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: width == null ? 92 : 85,
          snapshotWidth: width,
        ),
      );
      return bytes == null || bytes.isEmpty ? null : bytes;
    } catch (e) {
      debugPrint('SakuraReader: page snapshot failed: $e');
      return null;
    }
  }

  // --- instant open --------------------------------------------------------
  // A picture of the page last shown is saved with the book; the next open
  // shows it straight away (if the place and appearance still match) while
  // the real page loads underneath, then fades to the live page.

  ui.Image? _openingShot;
  // The page itself reported its layout done (not just the fallback timer):
  // only then is it safe to photograph for the next open.
  bool _layoutConfirmed = false;
  Timer? _shotSaveTimer;

  String get _shotKey => jsonEncode([
        _preferences.toJson(),
        AppPreferences.instance.readerPadding,
        AppThemeController.instance.isLight,
      ]);

  Future<File> _shotFile(String ext) async {
    final book = await LibraryController.instance.getBookFile(widget.book.publication.id);
    return File('${book.path}.page.$ext');
  }

  Future<void> _loadOpeningShot() async {
    try {
      final meta = await _shotFile('json');
      if (!await meta.exists()) return;
      final info = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      if (info['cfi'] != _startCfi || info['key'] != _shotKey) return;
      final bytes = await (await _shotFile('jpg')).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        _openingShot = frame.image;
      } else {
        frame.image.dispose();
      }
    } catch (e) {
      debugPrint('SakuraReader: no opening picture: $e');
    }
  }

  /// Saves the page on screen once reading pauses on it.
  void _scheduleShotSave(EpubLocation location) {
    _shotSaveTimer?.cancel();
    _shotSaveTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted || !_laidOut || !_layoutConfirmed || _turn != null || _zoomed || _stripQuiet || _selectionMenu != null) return;
      final bytes = await _captureBytes();
      if (bytes == null || !mounted) return;
      try {
        await (await _shotFile('jpg')).writeAsBytes(bytes);
        await (await _shotFile('json')).writeAsString(
          jsonEncode({'cfi': location.startCfi, 'key': _shotKey}),
        );
      } catch (e) {
        debugPrint('SakuraReader: could not save page picture: $e');
      }
    });
  }

  /// Snapshot of the page as the WebView shows it right now.
  Future<ui.Image?> _capturePage({double? width}) async {
    try {
      final bytes = await _captureBytes(width: width);
      if (bytes == null) return null;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (e) {
      debugPrint('SakuraReader: page snapshot failed: $e');
      return null;
    }
  }

  /// Where the turning page's free edge is for the turn's current drag.
  double _edgeFor(_PageTurn turn) {
    final w = _pageWidth;
    final flat = PageCurl.flatEdge(w);
    final gone = PageCurl.goneEdge(w);
    // The page follows the finger (a touch faster, so a short drag turns it).
    final start = turn.dir > 0 ? flat : gone;
    final edge = start + turn.dx * 1.15;
    return edge.clamp(gone, flat);
  }

  Future<void> _onTurnStart(List<dynamic> args) async {
    if (!mounted || args.isEmpty) return;
    _pendingTapToggle?.cancel();
    _onUserActivity();
    if (_turn != null || !_paginated || _selectionMenu != null) {
      // One turn at a time: this drag just gets ignored.
      _ignoreTurnGesture = true;
      return;
    }
    _ignoreTurnGesture = false;
    final dir = (args[0] as num).toInt() >= 0 ? 1 : -1;
    final y = args.length > 1 ? (args[1] as num).toDouble() : 0.5;
    final turn = _PageTurn(dir, ((y - 0.5) * 0.5).clamp(-0.25, 0.25));
    _turn = turn;
    _turnAnim.stop();
    _turnEdge = _edgeFor(turn);

    final current = await _capturePage();
    if (!mounted || _turn != turn) {
      current?.dispose();
      return;
    }
    turn.originCfi = await SakuraReadingBehavior.currentCfi(_epubController);
    if (!mounted || _turn != turn) {
      current?.dispose();
      return;
    }
    if (current == null) {
      turn.plain = true;
    } else if (dir > 0) {
      // Forward: the current page curls away; the WebView (already on the
      // next page) shows through underneath.
      setState(() => turn.front = current);
      turn.moved = await SakuraReadingBehavior.turn(_epubController, 1);
    } else {
      // Back: the current page stays put while the previous one curls in
      // over it, so both need snapshots.
      setState(() => turn.back = current);
      turn.moved = await SakuraReadingBehavior.turn(_epubController, -1);
      if (turn.moved && mounted && _turn == turn) {
        turn.front = await _capturePage();
      }
    }
    if (!mounted || _turn != turn) return;
    turn.ready = true;
    if (turn.released) {
      _releaseTurn(turn);
    } else {
      _turnEdge = _edgeFor(turn);
    }
  }

  void _onTurnMove(List<dynamic> args) {
    final turn = _turn;
    if (!mounted || args.isEmpty || _ignoreTurnGesture || turn == null || turn.released) return;
    var dx = (args[0] as num).toDouble() * _pageWidth;
    // Nowhere to go (start/end of the book): the page only gives a little.
    if (turn.ready && !turn.moved) dx *= 0.15;
    turn.dx = dx;
    if (turn.ready && !turn.plain) _turnEdge = _edgeFor(turn);
  }

  void _onTurnEnd(List<dynamic> args) {
    if (_ignoreTurnGesture) {
      _ignoreTurnGesture = false;
      return;
    }
    final turn = _turn;
    if (!mounted || turn == null || turn.released) return;
    if (args.isNotEmpty) turn.dx = (args[0] as num).toDouble() * _pageWidth;
    turn.velocity = args.length > 1 ? (args[1] as num).toDouble() : 0;
    turn.released = true;
    if (turn.ready) _releaseTurn(turn);
  }

  /// Whether a released drag completes the turn: a flick in the turn's
  /// direction, or a long enough drag that isn't flicked back.
  bool _shouldCommit(_PageTurn turn) {
    final v = turn.velocity * turn.dir; // >0 = moving back, <0 = onward
    final dx = turn.dx * turn.dir / _pageWidth; // <0 = dragged onward
    if (v < -0.3) return true;
    if (v > 0.3) return false;
    return dx < -0.12;
  }

  Future<void> _releaseTurn(_PageTurn turn) async {
    if (turn.plain) {
      if (_shouldCommit(turn)) await SakuraReadingBehavior.turn(_epubController, turn.dir);
      _endTurn(turn);
      return;
    }
    final commit = turn.moved && _shouldCommit(turn);
    final w = _pageWidth;
    // Forward: completing curls the page away, cancelling lays it back.
    // Back: completing lays the previous page down, cancelling lifts it away.
    final target = (commit == (turn.dir > 0)) ? PageCurl.goneEdge(w) : PageCurl.flatEdge(w);
    if (turn.front != null) await _animateEdge(target);
    if (!mounted || _turn != turn) return;
    if (!commit && turn.moved) {
      // Undo the move made underneath; the snapshot covers it meanwhile.
      final origin = turn.originCfi;
      if (origin != null) {
        await SakuraReadingBehavior.displayCfi(_epubController, origin);
      } else {
        await SakuraReadingBehavior.turn(_epubController, -turn.dir);
      }
    }
    _endTurn(turn);
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
      // Stopped by a new turn or a mode switch.
    } finally {
      _turnAnim.removeListener(tick);
      curve.dispose();
    }
  }

  void _endTurn(_PageTurn turn) {
    if (_turn != turn) return;
    if (mounted) setState(() => _turn = null);
    // Free the snapshots once the frame without them is out.
    WidgetsBinding.instance.addPostFrameCallback((_) => turn.dispose());
  }

  void _cancelTurn() {
    final turn = _turn;
    if (turn == null) return;
    _turnAnim.stop();
    _turn = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => turn.dispose());
  }

  /// A page turn not driven by a finger (keyboard, mouse wheel): animated
  /// in paginated mode, plain otherwise.
  Future<void> _turnPage(int dir) async {
    if (!_paginated) {
      dir > 0 ? _epubController.next() : _epubController.prev();
      return;
    }
    if (_turn != null) return;
    await _onTurnStart([dir, 0.5]);
    final turn = _turn;
    if (turn == null || turn.released) return;
    turn.velocity = -dir * 2.0;
    turn.dx = -dir * _pageWidth * 0.5;
    turn.released = true;
    if (turn.ready) await _releaseTurn(turn);
  }

  // --- zoomed-out page strip ---------------------------------------------

  /// Runs WebView moves for the strip one after another.
  Future<void> _stripTask(Future<void> Function() task) {
    _stripQueue = _stripQueue.then((_) => task()).catchError((Object e) {
      debugPrint('SakuraReader: page strip: $e');
    });
    return _stripQueue;
  }

  void _setStrip(int slot, ui.Image? image) {
    final old = _strip[slot];
    if (mounted) {
      setState(() => _strip[slot] = image);
    } else {
      _strip[slot] = image;
    }
    if (old != null && old != image) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// Photographs the page `dir` away (1 next, -1 previous) by moving the
  /// hidden WebView there and back. Null when there is no such page.
  Future<ui.Image?> _shootNeighbour(int dir, int session) async {
    if (session != _zoomSession) return null;
    _stripBusy = true;
    try {
      final origin = await SakuraReadingBehavior.mark(_epubController);
      final moved = await SakuraReadingBehavior.step(_epubController, dir);
      if (!moved) return null;
      final shot = session == _zoomSession
          ? await _capturePage(width: _pageWidth * _stripScale)
          : null;
      // Back to exactly where we were (a step back can land a page off at a
      // chapter boundary).
      if (origin != null) {
        await SakuraReadingBehavior.restore(_epubController, origin);
      } else {
        await SakuraReadingBehavior.step(_epubController, -dir);
      }
      return shot;
    } finally {
      _stripBusy = false;
      _stripQuietUntil = DateTime.now().add(const Duration(milliseconds: 300));
      _syncAfterStrip();
    }
  }

  /// Once the strip has stopped moving the page, report the real position
  /// (progress, scrubber, pages left) - its own moves were ignored.
  void _syncAfterStrip() {
    _stripSyncTimer?.cancel();
    _stripSyncTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && !_stripBusy) SakuraReadingBehavior.reportLocation(_epubController);
    });
  }

  Future<void> _enterZoom() async {
    if (!_epubReady || _zoomed || _turn != null || _selectionMenu != null) return;
    final session = ++_zoomSession;
    final current = await _capturePage();
    if (!mounted || session != _zoomSession || current == null || !_controlsVisible) {
      current?.dispose();
      return;
    }
    _stripController?.dispose();
    _stripController = PageController(initialPage: 1, viewportFraction: _stripViewportFraction);
    _setStrip(1, current);
    setState(() {
      _zoomed = true;
      _zoomShrunk = false;
    });
    // Next frame: shrink from full size, so the page visibly zooms out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && session == _zoomSession) setState(() => _zoomShrunk = true);
    });
    _refreshChapterInfo();
    await _stripTask(() async {
      await _fillSlot(2, 1, session);
      await _fillSlot(0, -1, session);
    });
  }

  Future<void> _refreshChapterInfo() async {
    final info = await SakuraReadingBehavior.chapterInfo(_epubController);
    if (mounted) setState(() => _chapterInfo = info);
  }

  String? _chapterTitle(String key) {
    final entry = _chapterInfo?[key];
    if (entry is! Map) return null;
    final title = (entry['title'] as String?)?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  /// Zoomed view: open the next (1) or previous (-1) chapter and photograph
  /// the new place.
  void _goChapterInZoom(int dir) {
    final entry = _chapterInfo?[dir > 0 ? 'next' : 'prev'];
    final href = entry is Map ? entry['href'] as String? : null;
    if (href == null || !_zoomed) return;
    _onUserActivity();
    AppHaptics.tick();
    final session = _zoomSession;
    _stripTask(() async {
      if (session != _zoomSession) return;
      await SakuraReadingBehavior.openHref(_epubController, href);
      _syncAfterStrip();
      // Right away, so a quick second swipe goes on from the new chapter.
      await _refreshChapterInfo();
    });
    _refreshStrip(session).then((_) {
      if (mounted && session == _zoomSession) _refreshChapterInfo();
    });
  }

  Future<void> _refreshStrip(int session) async {
    if (!mounted || !_zoomed || session != _zoomSession) return;
    await _stripTask(() async {
      if (session != _zoomSession) return;
      final current = await _capturePage();
      if (current == null || !mounted || session != _zoomSession) {
        current?.dispose();
        return;
      }
      _setStrip(1, current);
      _setStrip(0, null);
      _setStrip(2, null);
      await _fillSlot(2, 1, session);
      await _fillSlot(0, -1, session);
    });
  }

  Future<void> _exitZoom() async {
    if (!_zoomed) return;
    final session = ++_zoomSession;
    setState(() => _zoomShrunk = false);
    // Let pending WebView moves finish so it's back on the right page.
    await _stripTask(() async {});
    await Future<void>.delayed(_zoomDuration);
    if (!mounted || session != _zoomSession) return;
    setState(() => _zoomed = false);
    for (var i = 0; i < 3; i++) {
      _setStrip(i, null);
    }
    // Position reports were ignored while neighbours were photographed.
    SakuraReadingBehavior.reportLocation(_epubController);
  }

  /// The strip settled on another card: turn the real page and shift the
  /// snapshots along, then photograph the new neighbour.
  void _onStripPageChanged(int index) {
    if (index == 1 || !_zoomed) return;
    final dir = index == 2 ? 1 : -1;
    _onUserActivity();
    final session = _zoomSession;
    // Queued: if that card is still being photographed, this waits for it
    // and then moves (a quick second swipe used to just bounce back).
    _stripTask(() async {
      if (session != _zoomSession) return;
      final moved = await SakuraReadingBehavior.step(_epubController, dir);
      if (!mounted || session != _zoomSession) return;
      if (!moved) {
        // No page there (start/end of the book): back to the centre.
        _stripController?.animateToPage(1, duration: _zoomDuration, curve: Curves.easeOut);
        return;
      }
      _syncAfterStrip();
      final images = List<ui.Image?>.of(_strip);
      setState(() {
        if (dir > 0) {
          _strip[0] = images[1];
          _strip[1] = images[2];
          _strip[2] = null;
        } else {
          _strip[2] = images[1];
          _strip[1] = images[0];
          _strip[0] = null;
        }
      });
      final dropped = dir > 0 ? images[0] : images[2];
      _stripController?.jumpToPage(1);
      _refreshChapterInfo();
      WidgetsBinding.instance.addPostFrameCallback((_) => dropped?.dispose());
      if (_strip[1] == null) _setStrip(1, await _capturePage());
      final slot = dir > 0 ? 2 : 0;
      await _fillSlot(slot, dir, session);
    });
  }

  // Strip slots whose neighbour is being photographed right now (they show
  // a placeholder card; an empty slot with no page shows nothing).
  final Set<int> _stripPending = {};

  Future<void> _fillSlot(int slot, int dir, int session) async {
    if (mounted) setState(() => _stripPending.add(slot));
    try {
      _setStrip(slot, await _shootNeighbour(dir, session));
    } finally {
      if (mounted) setState(() => _stripPending.remove(slot));
    }
  }

  static const double _stripScale = 0.62;
  double get _stripViewportFraction => _stripScale + 0.08;

  Future<void> _applyFont(ReaderPreferences prefs) async {
    final font = SakuraFonts.byFamily(prefs.fontFamily);
    final base64 = await SakuraFonts.base64For(font);
    await _epubController.setFontFamily(
      fontFamily: font.flutterFontFamily,
      fontBase64: base64,
      fontMimeType: font.mimeType,
    );
  }

  void _onPreferencesChanged(ReaderPreferences newPrefs) {
    setState(() => _preferences = newPrefs);
    _session.dispatchCommand(UpdatePreferencesCommand(newPrefs));
    _applyPreferencesLive(newPrefs);
  }

  /// Expanded: toolbar above the panes (back | title + % | actions).
  Widget _buildToolbar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.figmaReaderBackground,
        border: Border(bottom: BorderSide(color: AppColors.dividerSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const FigmaIcon(AssetConstants.iconBack, width: 9, height: 14),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          Expanded(
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
                  style: GoogleFonts.dmSans(fontSize: 13, height: 20 / 13, color: AppColors.figmaTextFaint),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.searchInBook,
            icon: Icon(Icons.search_rounded, color: AppColors.fg, size: 22),
            onPressed: _showSearchSheet,
          ),
          IconButton(
            tooltip: l10n.bookmarkThisPage,
            icon: Icon(Icons.bookmark_add_outlined, color: AppColors.fg, size: 22),
            onPressed: _addBookmark,
          ),
          ReaderPaneToggles(color: AppColors.fg),
          IconButton(icon: const _ReaderMenuGlyph(), onPressed: _showReaderMenu),
        ],
      ),
    );
  }

  void _showCustomizationSheet() {
    // Changes show live on the page, so not on a zoomed-out snapshot.
    _exitZoom();
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SakuraCustomizationSheet(
        preferences: _preferences,
        onChanged: _onPreferencesChanged,
        brightness: _brightness,
        onBrightnessChanged: (value) => setState(() => _brightness = value),
      ),
    );
  }

  void _showTocSheet() {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SakuraTocSheet(
        chapters: _toc,
        notes: _session.state.annotations,
        onNavigateToHref: (href) => _epubController.display(cfi: href),
      ),
    );
  }

  void _showSearchSheet() {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SakuraSearchSheet(
        controller: _epubController,
        onNavigateToCfi: (cfi) => _epubController.display(cfi: cfi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panes = readerUsesPanes(context);
    if (panes != _panes) {
      _panes = panes;
      // Into expanded: drop the floating bars (and their zoom-out).
      if (panes && _controlsVisible) WidgetsBinding.instance.addPostFrameCallback((_) => _setControls(false));
    }
    final prefs = AppPreferences.instance;
    final pageColor = SakuraEpubMapper.pageColorFor(_preferences.theme);
    final bookView = FutureBuilder<File>(
        future: _bookFileFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildLoadFailure(context, l10n.couldNotOpenBookFile('${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppColors.accentLime));
          }

          if (!_epubReady && !_loadTimedOut) {
            // First frame with a resolved file: (re)start the watchdog. Cheap
            // to call repeatedly - it just cancels and restarts the timer.
            _startLoadTimeoutWatchdog();
          }

          final media = MediaQuery.of(context);
          _syncSpread(media.size.width);
          // The page keeps one fixed size; the controls float over it.
          // Resizing it with the controls (as before) made epub.js re-lay
          // out the book on every animation frame - the show/hide flicker,
          // and in scrolled mode the reading position drifted each time.
          final insetTop = media.padding.top;
          final insetBottom = media.padding.bottom;
          // Bottom strip under the page: pages left / percentage.
          final pageBottom = insetBottom + _footerHeight;
          _pageWidth = media.size.width;
          if (_lastScreenSize != null && _lastScreenSize != media.size) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _onScreenResized());
          }
          _lastScreenSize = media.size;
          final pageColor = SakuraEpubMapper.pageColorFor(_preferences.theme);
          final turn = _turn;

          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: insetTop,
                bottom: pageBottom,
                child: _viewer ??= EpubViewer(
                  key: ValueKey('viewer-$_viewerGeneration'),
                  epubController: _epubController,
                  epubSource: EpubSource.fromFile(snapshot.data!),
                  servedBook: _servedBook,
                  initialCfi: _startCfi,
                  displaySettings: SakuraEpubMapper.displaySettingsFor(
                    _preferences,
                    spread: _spread = useSpread(media.size.width) && _preferences.scrollMode != ScrollMode.continuous,
                  ),
                  onEpubLoaded: _onEpubLoaded,
                  onLocationLoaded: _onLocationLoaded,
                  onChaptersLoaded: _onChaptersLoaded,
                  onRelocated: _onRelocated,
                  onSelection: _onSelection,
                  // Hide our menu while the handles are being dragged, and
                  // suppress Android's native Copy/Select-all pill, which
                  // otherwise appears on top of it.
                  onSelectionChanging: _onDeselection,
                  suppressNativeContextMenu: true,
                  onDeselection: _onDeselection,
                  onAnnotationClicked: _onAnnotationClicked,
                  onTouchDown: _onTouchDown,
                  onTouchUp: _onTouchUp,
                  // Deny every WebView permission request (camera/mic/geolocation/...):
                  // a locally-rendered book has no legitimate reason to need any of
                  // them - mirrors WebviewSecurityPolicy.strict's all-deny stance.
                  onPermissionRequest: (request) async => PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.DENY,
                  ),
                ),
              ),

              if (turn != null && !turn.plain && (turn.front != null || turn.back != null))
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
                  ignoring: _laidOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _laidOut ? 0 : 1,
                    child: _openingShot != null && !_appliedModeChangedSinceOpen
                        ? RawImage(image: _openingShot, fit: BoxFit.fill)
                        : ReaderPageSkeleton(
                            pageColor: pageColor,
                            inkColor: SakuraEpubMapper.textColorFor(_preferences.theme),
                            padding: AppPreferences.instance.readerPadding.clamp(12.0, 48.0),
                          ),
                  ),
                ),
              ),
              if (_zoomed) _buildPageStrip(context, insetTop, pageBottom, pageColor),
              // Above the strip: when lifted it sits over the strip's area.
              _buildFooter(insetBottom),
              if (_brightness < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: (1 - _brightness) * 0.8),
                    ),
                  ),
                ),
              if (_preferences.scrollMode == ScrollMode.continuous)
                _buildScrollLine(context, insetTop, insetBottom),
              _animatedChrome(visible: _topVisible, fromTop: true, child: _buildTopBar(context)),
              _animatedChrome(
                visible: _bottomVisible,
                fromTop: false,
                child: _buildBottomBar(context),
              ),
              _buildChapterSwipeIndicator(context),
              if (_selectionMenu != null)
                _buildSelectionOverlay(context, _selectionMenu!, insetTop, pageBottom),
              if (_loadTimedOut && !_epubReady) _buildLoadTimeoutBanner(context),
            ],
          );
        },
    );

    final scaffold = Scaffold(
      backgroundColor: pageColor,
      body: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) => ReaderPaneLayout(
          background: pageColor,
          focusMode: _focusMode,
          contentsOpen: prefs.readerContentsPaneOpen,
          settingsOpen: prefs.readerSettingsPaneOpen,
          topBar: SafeArea(bottom: false, child: _buildToolbar(context)),
          contents: ReaderFocusReturn(
            focusNode: _readerFocus,
            child: SakuraTocSheet(
              embedded: true,
              chapters: _toc,
              notes: _session.state.annotations,
              onNavigateToHref: (href) => _epubController.display(cfi: href),
            ),
          ),
          settings: ReaderFocusReturn(
            focusNode: _readerFocus,
            child: SakuraCustomizationSheet(
              embedded: true,
              preferences: _preferences,
              onChanged: _onPreferencesChanged,
              brightness: _brightness,
              onBrightnessChanged: (value) => setState(() => _brightness = value),
            ),
          ),
          book: bookView,
        ),
      ),
    );

    return Focus(
      focusNode: _readerFocus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        final chapterScroll = _preferences.scrollMode == ScrollMode.continuous;
        if (chapterScroll &&
            (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowLeft)) {
          // Scrolled mode: ←/→ change chapter; the other keys scroll it.
          SakuraReadingBehavior.goChapter(
            _epubController,
            key == LogicalKeyboardKey.arrowRight ? 1 : -1,
          );
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.pageDown ||
            key == LogicalKeyboardKey.space) {
          _turnPage(1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.pageUp) {
          _turnPage(-1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape) {
          _toggleControls();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyB) {
          _addBookmark();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyM) {
          _toggleControls();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            if (_preferences.scrollMode != ScrollMode.continuous) {
              _accumulatedScrollDelta += pointerSignal.scrollDelta.dy;
              _scrollDebounceTimer?.cancel();
              _scrollDebounceTimer = Timer(const Duration(milliseconds: 80), () {
                if (_accumulatedScrollDelta.abs() >= 40.0) {
                  _turnPage(_accumulatedScrollDelta > 0 ? 1 : -1);
                }
                _accumulatedScrollDelta = 0;
              });
            }
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
    final color = SakuraEpubMapper.textColorFor(_preferences.theme).withValues(alpha: 0.6);
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
          color: SakuraEpubMapper.pageColorFor(_preferences.theme),
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
    Widget card(int slot) {
      final image = _strip[slot];
      // No page there (start/end), or not photographed yet: show nothing
      // rather than an empty dummy card.
      final pending = image == null && slot != 1 && _stripPending.contains(slot);
      if (image == null && slot != 1 && !pending) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () {
          if (slot == 1) {
            _setControls(false);
          } else {
            _stripController?.animateToPage(slot, duration: _zoomDuration, curve: Curves.easeOut);
          }
        },
        child: Center(
          child: AnimatedOpacity(
            duration: _zoomDuration,
            opacity: slot == 1 || _zoomShrunk ? 1 : 0,
            child: AnimatedScale(
              duration: _zoomDuration,
              curve: Curves.easeOutCubic,
              scale: slot == 1 ? scale : _stripScale,
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
                      slot != 1 || _zoomShrunk ? 8 / _stripScale : 0,
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
                          inkColor: SakuraEpubMapper.textColorFor(_preferences.theme),
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
            itemCount: 3,
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
                      builder: (_) => SakuraReaderScreen(
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
          if (defaultTargetPlatform == TargetPlatform.android) ('fast', l10n.fastLayout),
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
      case 'fast':
        // Back to the native reader for this book, at the same place.
        await RendererChoice.set(widget.book.publication.id, RendererChoice.native);
        final loc = _lastLocation;
        if (loc != null) {
          _positionSaveDebounce?.cancel();
          await _session.dispatchCommand(NavigateToLocatorCommand(SakuraEpubMapper.locatorFromLocation(loc)));
        }
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => NativeReaderScreen(book: widget.book, initialLocator: widget.initialLocator)),
        );
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
                SakuraReadingBehavior.scrollTo(_epubController, ratio);
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
