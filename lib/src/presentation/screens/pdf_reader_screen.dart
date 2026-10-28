import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Quad;
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../../data/pdf/pdf_document.dart';
import '../state/library_controller.dart';
import '../state/reader_usage_mixin.dart';
import '../theme/app_colors.dart';
import '../layout/pdf_page_layout.dart';
import '../layout/spread.dart';
import '../layout/window_class.dart';
import '../widgets/app_chrome.dart';

/// PDF reader: pages rendered by the platform (Android PdfRenderer), shown as
/// a vertical strip you can pinch to zoom (1x-5x), drag in any direction,
/// and double-tap to zoom. Reopens at the last page read.
class PdfReaderScreen extends StatefulWidget {
  final BookItem book;
  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen>
    with ReaderUsageMixin, SingleTickerProviderStateMixin {
  @override
  BookItem get usageBook => widget.book;

  static const _pageGap = 12.0;
  static const _minScale = 1.0;
  static const _maxScale = 5.0;
  static const _doubleTapScale = 2.5;

  PdfDocumentHandle? _doc;
  Object? _error;
  bool _controlsVisible = true;
  int _currentPage = 0;
  Timer? _saveDebounce;

  // One zoom/pan surface for the whole document: pinch to zoom, drag in
  // any direction (with fling). The old ListView-inside-InteractiveViewer
  // fought over drags and only ever zoomed the visible window.
  final _transform = TransformationController();
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<Matrix4>? _zoomTween;
  Offset? _doubleTapAt;

  // Layout, in document coordinates (scale 1 = page fits the width).
  double _viewportWidth = 0;
  double _viewportHeight = 0;
  double _topPad = 0;
  List<double> _pageTops = const [];
  List<Rect> _pageRects = const [];
  bool _spread = false; // two pages per row (wide window, portrait PDF)
  double _contentHeight = 0;

  // Rendered pages: a screen-resolution image for every nearby page, plus a
  // sharper one for visible pages while zoomed in.
  final _cache = <int, Future<Uint8List>>{};
  final _hiCache = <(int, int), Future<Uint8List>>{};
  int _hiTier = 1;
  double _devicePixelRatio = 2;

  double get _scale => _transform.value.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.pdfPage;
    _transform.addListener(_onTransform);
    _zoomAnim.addListener(() {
      final t = _zoomTween;
      if (t != null) _transform.value = t.value;
    });
    _open();
  }

  Future<void> _open() async {
    try {
      final file = await LibraryController.instance.getBookFile(
        widget.book.publication.id,
        kind: BookFormat.pdf,
      );
      final doc = await PdfDocumentHandle.open(file.path);
      if (!mounted) {
        doc.close();
        return;
      }
      setState(() => _doc = doc);
      // Resume where the reader left off once the surface has a size.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpTo(_currentPage, animate: false),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _save();
    _transform.dispose();
    _zoomAnim.dispose();
    _doc?.close();
    super.dispose();
  }

  void _layout(double width, double height, double topPad, double bottomPad, {required bool allowSpread}) {
    final doc = _doc!;
    final spread = allowSpread && useSpread(width) && pdfWantsSpread(doc.aspectRatios);
    if (width == _viewportWidth &&
        height == _viewportHeight &&
        topPad == _topPad &&
        spread == _spread &&
        _pageTops.isNotEmpty)
      return;
    _viewportWidth = width;
    _viewportHeight = height;
    _topPad = topPad;
    if (spread != _spread) {
      _spread = spread;
      _cache.clear(); // page bitmaps change width
      _hiCache.clear();
    }
    _pageRects = layoutPdfPages(doc.aspectRatios, width, gap: _pageGap, spread: spread, top: topPad);
    _pageTops = [for (final r in _pageRects) r.top];
    final end = _pageRects.isEmpty ? topPad : _pageRects.map((r) => r.bottom).reduce(math.max) + _pageGap;
    _contentHeight = math.max(end + bottomPad, height);
  }

  /// Index of the page at document y [y].
  int _pageAt(double y) {
    var lo = 0, hi = _pageTops.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_pageTops[mid] <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The visible document rectangle for the current transform.
  Rect get _visibleRect {
    final s = _scale;
    final t = _transform.value.getTranslation();
    return Rect.fromLTWH(
      -t.x / s,
      -t.y / s,
      _viewportWidth / s,
      _viewportHeight / s,
    );
  }

  void _onTransform() {
    if (_doc == null || _pageTops.isEmpty) return;
    final view = _visibleRect;
    // The page under the top third of the screen is "current".
    final page = _pageAt(view.top + view.height / 3);
    if (page != _currentPage) {
      _cache.removeWhere((k, _) => (k - page).abs() > 6);
      _hiCache.removeWhere((k, _) => (k.$1 - page).abs() > 2);
      setState(() => _currentPage = page);
      _saveDebounce?.cancel();
      _saveDebounce = Timer(const Duration(milliseconds: 800), _save);
    }
  }

  /// After a pinch settles, render visible pages sharper for the new zoom.
  void _onInteractionEnd(ScaleEndDetails _) {
    final s = _scale;
    final tier = s < 1.5 ? 1 : (s < 2.8 ? 2 : 3);
    if (tier != _hiTier) {
      setState(() => _hiTier = tier);
      if (tier == 1) _hiCache.clear();
    }
  }

  void _save() {
    final doc = _doc;
    if (doc != null)
      LibraryController.instance.savePdfPage(
        widget.book,
        _currentPage,
        doc.pageCount,
      );
  }

  /// A transform showing document point [docTopLeft] at the viewport's
  /// top-left at [scale], kept inside the document.
  Matrix4 _matrixFor(Offset docTopLeft, double scale) {
    final maxX = math.max(0.0, _viewportWidth * scale - _viewportWidth);
    final maxY = math.max(0.0, _contentHeight * scale - _viewportHeight);
    final tx = (-docTopLeft.dx * scale).clamp(-maxX, 0.0);
    final ty = (-docTopLeft.dy * scale).clamp(-maxY, 0.0);
    return Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  void _animateTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic));
    _zoomAnim.forward(from: 0);
  }

  void _jumpTo(int page, {bool animate = true}) {
    if (_doc == null || _pageTops.isEmpty) return;
    final view = _visibleRect;
    final target = _matrixFor(
      Offset(
        view.left,
        _pageTops[page.clamp(0, _doc!.pageCount - 1)] - _topPad / _scale,
      ),
      _scale,
    );
    if (animate) {
      _animateTo(target);
    } else {
      _transform.value = target;
    }
  }

  /// Double tap: zoom in on the tapped spot, or back out to fit the width.
  void _onDoubleTap() {
    final at = _doubleTapAt;
    if (at == null || _pageTops.isEmpty) return;
    final view = _visibleRect;
    final s = _scale;
    if (s > 1.05) {
      _animateTo(_matrixFor(Offset(0, view.top + at.dy / s - at.dy), 1));
    } else {
      final docPoint = Offset(view.left + at.dx / s, view.top + at.dy / s);
      const z = _doubleTapScale;
      _animateTo(
        _matrixFor(Offset(docPoint.dx - at.dx / z, docPoint.dy - at.dy / z), z),
      );
    }
    _onInteractionEnd(ScaleEndDetails());
  }

  Future<void> _goToPageDialog() async {
    final doc = _doc;
    if (doc == null) return;
    final controller = TextEditingController(text: '${_currentPage + 1}');
    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheetSurface,
        title: Text(
          l10n.goToPage,
          style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.sora(color: AppColors.fg),
          decoration: InputDecoration(
            hintText: l10n.pageRangeHint(doc.pageCount),
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(int.tryParse(controller.text)),
            child: Text(l10n.go),
          ),
        ],
      ),
    );
    controller.dispose();
    if (page != null) _jumpTo(page - 1);
  }

  int get _baseWidthPx => ((_spread ? (_viewportWidth - 3 * _pageGap) / 2 : _viewportWidth - 2 * _pageGap) * _devicePixelRatio)
      .clamp(400, 2000)
      .round();

  Future<Uint8List> _render(int index) =>
      _cache.putIfAbsent(index, () => _doc!.renderPage(index, _baseWidthPx));

  /// Sharper render for zoomed-in reading (capped: a page bitmap this size
  /// is already ~20MB in memory).
  Future<Uint8List>? _renderHi(int index) {
    if (_hiTier <= 1) return null;
    final width = math.min(_baseWidthPx * _hiTier, 2600);
    return _hiCache.putIfAbsent((
      index,
      width,
    ), () => _doc!.renderPage(index, width));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppColors.figmaReaderBackground,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody(media)),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            top: _controlsVisible ? 0 : -(media.padding.top + 90),
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.figmaReaderBackground,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 15, 10),
                  child: SegmentedTopBar(
                    leading: const FigmaIcon(
                      AssetConstants.iconBack,
                      width: 9,
                      height: 14,
                    ),
                    onLeadingTap: () => Navigator.of(context).pop(),
                    middle: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.publication.metadata.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: AppColors.fg,
                            ),
                          ),
                          Text(
                            _doc == null
                                ? 'PDF'
                                : l10n.pageOf(
                                    _currentPage + 1,
                                    _doc!.pageCount,
                                  ),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.figmaTextFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onMiddleTap: _goToPageDialog,
                    trailing: Icon(
                      Icons.tag_rounded,
                      size: 18,
                      color: AppColors.fgMuted,
                    ),
                    onTrailingTap: _goToPageDialog,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MediaQueryData media) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.fgFaint,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.couldNotOpenPdf('$_error'),
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.goBack),
              ),
            ],
          ),
        ),
      );
    }
    final doc = _doc;
    if (doc == null)
      return Center(
        child: CircularProgressIndicator(color: AppColors.accentLime),
      );

    return LayoutBuilder(
      builder: (context, constraints) {
        _devicePixelRatio = media.devicePixelRatio;
        _layout(
          constraints.maxWidth,
          constraints.maxHeight,
          media.padding.top + 77,
          media.padding.bottom + 24,
          allowSpread: !context.windowClass.isCompact,
        );
        return GestureDetector(
          onTap: () => setState(() => _controlsVisible = !_controlsVisible),
          onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
          onDoubleTap: _onDoubleTap,
          child: InteractiveViewer.builder(
            transformationController: _transform,
            minScale: _minScale,
            maxScale: _maxScale,
            boundaryMargin: EdgeInsets.zero,
            onInteractionStart: (_) => _zoomAnim.stop(),
            onInteractionEnd: _onInteractionEnd,
            builder: (context, viewport) {
              // Build only the pages inside (or just around) the viewport.
              final bounds = axisAlignedBoundingBox(viewport);
              final first = _pageAt(bounds.top - _viewportHeight * 0.5);
              final last = _pageAt(bounds.bottom + _viewportHeight * 0.5);
              return SizedBox(
                width: _viewportWidth,
                height: _contentHeight,
                child: Stack(
                  children: [
                    for (var i = first; i <= last; i++)
                      Positioned.fromRect(
                        rect: _pageRects[i],
                        child: _PdfPage(
                          key: ValueKey(i),
                          base: _render(i),
                          sharp: _renderHi(i),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The smallest rectangle containing the (possibly rotated) [quad].
  static Rect axisAlignedBoundingBox(Quad quad) {
    final xs = [quad.point0.x, quad.point1.x, quad.point2.x, quad.point3.x];
    final ys = [quad.point0.y, quad.point1.y, quad.point2.y, quad.point3.y];
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }
}

/// One PDF page: the screen-resolution render, replaced by the sharper
/// zoomed render once it's ready (no flash in between).
class _PdfPage extends StatelessWidget {
  final Future<Uint8List> base;
  final Future<Uint8List>? sharp;

  const _PdfPage({super.key, required this.base, required this.sharp});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: FutureBuilder<Uint8List>(
        future: base,
        builder: (context, b) {
          if (!b.hasData) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final baseImage = Image.memory(
            b.data!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
          if (sharp == null) return baseImage;
          return FutureBuilder<Uint8List>(
            future: sharp,
            builder: (context, h) => h.hasData
                ? Image.memory(
                    h.data!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  )
                : baseImage,
          );
        },
      ),
    );
  }
}
