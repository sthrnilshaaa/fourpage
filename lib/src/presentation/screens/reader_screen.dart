import 'dart:async';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../aread.dart';
import '../state/library_controller.dart';
import '../state/reader_usage_mixin.dart';
import '../theme/app_colors.dart';
import '../widgets/epub_content_view.dart';
import '../widgets/epub_controller.dart';
import '../widgets/epub_view_builders.dart';
import '../widgets/reader_customization_sheet.dart';
import '../widgets/reader_search_sheet.dart';
import '../widgets/reader_toc_sheet.dart';

class ReaderScreen extends StatefulWidget {
  final BookItem book;
  final Locator? initialLocator;

  const ReaderScreen({
    super.key,
    required this.book,
    this.initialLocator,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with ReaderUsageMixin {
  @override
  BookItem get usageBook => widget.book;

  late ReadingSession _session;
  late EpubController _epubController;
  late ReaderPreferences _preferences;

  bool _controlsVisible = true;

  Timer? _positionSaveDebounce;
  Timer? _scrollDebounceTimer;
  double _accumulatedScrollDelta = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.book.session;
    _preferences = _session.state.preferences;

    _epubController = EpubController(
      document: EpubDocument.openData(Uint8List.fromList(widget.book.archiveBytes)),
      // An explicit target (Saved screen), else where the reader left off.
      epubCfi: widget.initialLocator?.href ?? _session.state.currentLocator?.locations.cfi,
    );

    _epubController.currentValueListenable.addListener(_onPositionChanged);
  }

  @override
  void dispose() {
    _positionSaveDebounce?.cancel();
    _scrollDebounceTimer?.cancel();
    _epubController.currentValueListenable.removeListener(_onPositionChanged);
    _epubController.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    _positionSaveDebounce?.cancel();
    _positionSaveDebounce = Timer(const Duration(milliseconds: 1500), () async {
      final value = _epubController.currentValue;
      if (value == null) return;

      final progressPercent = value.progress.clamp(0.0, 100.0);
      final cfi = await _epubController.generateEpubCfi();
      final total = _epubController.paragraphCount;
      final bookProgress = total > 0 ? (value.position.index / total).clamp(0.0, 1.0) : null;

      _session.dispatchCommand(
        NavigateToLocatorCommand(
          Locator(
            href: cfi ?? 'chapter_${value.chapterNumber}',
            locations: LocationParameters(
              position: value.paragraphNumber,
              progression: progressPercent / 100.0,
              totalProgression: bookProgress,
              cfi: cfi,
            ),
          ),
        ),
      );
    });
  }

  (Color bg, Color textCol) _getThemeColors(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.light:
        return (AppColors.readerLight, const Color(0xFF0F172A));
      case ReaderTheme.sepia:
        return (AppColors.readerSepia, AppColors.readerSepiaText);
      case ReaderTheme.highContrast:
        return (AppColors.readerHighContrast, Colors.yellow);
      case ReaderTheme.dark:
      case ReaderTheme.publisher:
        return (AppColors.readerDark, AppColors.textPrimary);
    }
  }

  TextAlign _getTextAlign(String alignment) {
    switch (alignment.toLowerCase()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  /// The only font families actually offered anywhere in the reader UI
  /// (ReaderCustomizationSheet's chips and the quick "Aa" popup both cycle
  /// through exactly this list) - kept as one source of truth so a font a
  /// user can select is always one this can render, and vice versa.
  static const List<String> selectableFontFamilies = ['Merriweather', 'Sora', 'JetBrains Mono', 'Inter'];

  TextStyle _getReaderTextStyle(ReaderPreferences prefs, Color textColor) {
    final familyName = selectableFontFamilies.contains(prefs.fontFamily) ? prefs.fontFamily : 'Merriweather';

    return GoogleFonts.getFont(
      familyName,
      fontSize: prefs.fontSize,
      height: prefs.lineHeight,
      color: textColor,
    );
  }

  void _showCustomizationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderCustomizationSheet(
        preferences: _preferences,
        onChanged: (newPrefs) {
          _session.dispatchCommand(UpdatePreferencesCommand(newPrefs));
          setState(() {
            _preferences = newPrefs;
          });
        },
      ),
    );
  }

  void _showTocSheet() {
    final pub = _session.state.publication;
    if (pub == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderTocSheet(
        publication: pub,
        annotations: _session.state.annotations,
        bookmarks: _session.state.bookmarks,
        epubController: _epubController,
        onNavigate: (locator) {
          _epubController.gotoEpubCfi(locator.href);
        },
      ),
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderSearchSheet(
        session: _session,
        onNavigate: (locator) {
          _session.dispatchCommand(NavigateToLocatorCommand(locator));
          _epubController.gotoEpubCfi(locator.href);
        },
      ),
    );
  }

  Future<void> _addBookmark() async {
    final chapterValue = _epubController.currentValue;
    // The CFI is what the reader can jump back to (a chapter title isn't).
    final cfi = await _epubController.generateEpubCfi();
    if (!mounted) return;
    final currentCfi = cfi ?? 'chapter_${chapterValue?.chapterNumber ?? 1}';

    final title = chapterValue?.chapter?.Title?.replaceAll('\n', '').trim() ??
        l10n.chapterBookmark(chapterValue?.chapterNumber ?? 1);

    _session.dispatchCommand(
      CreateBookmarkCommand(
        locator: Locator(
          href: currentCfi,
          locations: LocationParameters(
            position: chapterValue?.paragraphNumber ?? 0,
            progression: (chapterValue?.progress ?? 0.0) / 100.0,
            cfi: cfi,
          ),
        ),
        title: title,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.bookmarkedCurrentLocation),
        backgroundColor: AppColors.accentLime,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onHighlightSaved(SelectedTextModel highlight) async {
    final cfi = await _epubController.generateEpubCfi();
    final colorMap = {
      'tgYellow': '#FFFF00',
      'tgCyan': '#00FFFF',
      'tgPink': '#FF69B4',
      'tgGreen': '#90EE90',
      'tgOrange': '#FFA07A',
      'tgLilac': '#DDA0DD',
    };
    _session.dispatchCommand(
      CreateAnnotationCommand(
        locator: Locator(href: cfi ?? 'para_${highlight.paragraphIndex}'),
        textQuote: highlight.selectedText,
        colorHex: colorMap[highlight.tag] ?? '#FFFF00',
        type: AnnotationType.highlight,
      ),
    );
  }

  /// Header menu - the one entry point for reader actions (replaces three
  /// popups that were never reachable).
  Future<void> _showReaderMenu() async {
    final media = MediaQuery.of(context);
    final vertical = _preferences.scrollMode == ScrollMode.continuous;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(media.size.width - 240, media.padding.top + 64, 12, 0),
      color: AppColors.popoverSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        for (final (value, label) in [
          ('customize', l10n.customization),
          ('mode', vertical ? l10n.horizontal : l10n.vertical),
          ('bookmark', l10n.bookmarkThisPage),
          ('search', l10n.searchInBook),
          ('chapters', l10n.chapters),
        ])
          PopupMenuItem<String>(
            value: value,
            child: Text(label, style: GoogleFonts.sora(fontSize: 15, color: AppColors.fg)),
          ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'customize':
        _showCustomizationSheet();
      case 'mode':
        final next = _preferences.copyWith(scrollMode: vertical ? ScrollMode.paginated : ScrollMode.continuous);
        _session.dispatchCommand(UpdatePreferencesCommand(next));
        setState(() => _preferences = next);
      case 'bookmark':
        _addBookmark();
      case 'search':
        _showSearchSheet();
      case 'chapters':
        _showTocSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = _getThemeColors(_preferences.theme);
    final textStyle = _getReaderTextStyle(_preferences, textColor);
    final textAlign = _getTextAlign(_preferences.textAlignment);

    final scaffold = Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // EPUB Viewport with Tap Controls Toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _controlsVisible = !_controlsVisible;
              });
            },
            child: SafeArea(
              child: Container(
                color: bgColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stable Rich EPUB Reader Viewport (Zero Flickering, Clean Header Flow)
                    Expanded(
                      child: EpubView(
                        controller: _epubController,
                        scrollDirection: _preferences.scrollMode == ScrollMode.continuous
                            ? Axis.vertical
                            : Axis.horizontal,
                        builders: EpubViewBuilders<DefaultBuilderOptions>(
                          options: DefaultBuilderOptions(
                            paragraphPadding: EdgeInsets.symmetric(
                              horizontal: UIConstants.readerTextPadding,
                              vertical: 6,
                            ),
                            textStyle: textStyle,
                            textAlign: textAlign,
                          ),
                          // Spine documents with no TOC entry have no title;
                          // don't draw an empty heading above them.
                          chapterDividerBuilder: (chapter) => (chapter.Title?.trim().isEmpty ?? true)
                              ? SizedBox.shrink()
                              : Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: UIConstants.readerTextPadding,
                              vertical: 16,
                            ),
                            child: Text(
                              chapter.Title?.replaceAll('\n', '').trim() ?? '',
                              style: GoogleFonts.ptSerif(
                                fontSize: _preferences.fontSize + 6,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                        onHighlightTap: _onHighlightSaved,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Controls Bar (opened_book.png in Figma)
          if (_controlsVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  color: bgColor.withValues(alpha: 0.96),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Back Button Box (<)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: UIConstants.readerIconBoxSize,
                          height: UIConstants.readerIconBoxSize,
                          decoration: BoxDecoration(
                            color: AppColors.fg.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.chevron_left_rounded, color: textColor, size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Book Title & Chapter / Page Subtitle (Tapping opens TOC)
                      Expanded(
                        child: GestureDetector(
                          onTap: _showTocSheet,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.book.publication.metadata.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ValueListenableBuilder(
                                valueListenable: _epubController.currentValueListenable,
                                builder: (context, value, _) {
                                  final chNum = value?.chapterNumber ?? 1;
                                  final prog = (value?.progress ?? 0).round();
                                  final chTitle = value?.chapter?.Title?.replaceAll('\n', '').trim() ?? l10n.chapterLabel(chNum.toString().padLeft(2, '0'));
                                  return Text(
                                    '$chTitle • $prog%',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sora(
                                      fontSize: 12,
                                      color: textColor.withValues(alpha: 0.65),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Chapter TOC Icon Button
                      IconButton(
                        icon: Icon(Icons.format_list_bulleted_rounded, color: textColor, size: 22),
                        onPressed: _showTocSheet,
                      ),

                      // Customization Sheet Controls Button Box (opened_theme.png)
                      GestureDetector(
                        onTap: _showReaderMenu,
                        child: Container(
                          width: UIConstants.readerIconBoxSize,
                          height: UIConstants.readerIconBoxSize,
                          decoration: BoxDecoration(
                            color: AppColors.fg.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.more_horiz_rounded, color: textColor, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Bottom Reading Pill & Menu
          if (_controlsVisible)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: ValueListenableBuilder<EpubChapterViewValue?>(
                valueListenable: _epubController.currentValueListenable,
                builder: (context, value, child) {
                  final title = value?.chapter?.Title?.replaceAll('\n', '').trim() ??
                      l10n.chapterN(value?.chapterNumber ?? 1);
                  final progress = (value?.progress ?? 0).round();

                  return GestureDetector(
                    onTap: _showTocSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.pillSurface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.fg.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.book.publication.metadata.title} / $title',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                color: AppColors.textFaint,
                              ),
                            ),
                          ),
                          Text(
                            '$progress%',
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              color: AppColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

        ],
      ),
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.pageDown ||
            key == LogicalKeyboardKey.space) {
          _epubController.next();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.pageUp) {
          _epubController.prev();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape) {
          setState(() {
            _controlsVisible = !_controlsVisible;
          });
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyB) {
          _addBookmark();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyM) {
          setState(() {
            _controlsVisible = !_controlsVisible;
          });
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
                  if (_accumulatedScrollDelta > 0) {
                    _epubController.next();
                  } else {
                    _epubController.prev();
                  }
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
}
