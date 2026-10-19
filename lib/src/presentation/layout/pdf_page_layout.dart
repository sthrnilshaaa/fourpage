import 'dart:math' as math;
import 'dart:ui';

/// Page rectangles (document coordinates, scale 1) for a PDF [viewportWidth]
/// wide. [aspectRatios] are width/height per page.
///
/// Single: one page per row, full width. Spread: the first page (cover)
/// alone and centered, then pages two per row; a last odd page sits on the
/// left. Tops never decrease.
List<Rect> layoutPdfPages(
  List<double> aspectRatios,
  double viewportWidth, {
  required double gap,
  required bool spread,
  double top = 0,
}) {
  double ratio(int i) => aspectRatios[i] <= 0 ? 0.707 : aspectRatios[i];
  final rects = <Rect>[];
  var y = top;
  if (!spread) {
    final w = viewportWidth - 2 * gap;
    for (var i = 0; i < aspectRatios.length; i++) {
      final h = w / ratio(i);
      rects.add(Rect.fromLTWH(gap, y, w, h));
      y += h + gap;
    }
    return rects;
  }
  final pw = (viewportWidth - 3 * gap) / 2;
  var i = 0;
  if (aspectRatios.isNotEmpty) {
    final h = pw / ratio(0);
    rects.add(Rect.fromLTWH((viewportWidth - pw) / 2, y, pw, h));
    y += h + gap;
    i = 1;
  }
  for (; i < aspectRatios.length; i += 2) {
    final hl = pw / ratio(i);
    rects.add(Rect.fromLTWH(gap, y, pw, hl));
    var row = hl;
    if (i + 1 < aspectRatios.length) {
      final hr = pw / ratio(i + 1);
      rects.add(Rect.fromLTWH(2 * gap + pw, y, pw, hr));
      row = math.max(row, hr);
    }
    y += row + gap;
  }
  return rects;
}

/// Two pages per row only suits portrait documents (most pages taller than wide).
bool pdfWantsSpread(List<double> aspectRatios) {
  if (aspectRatios.isEmpty) return false;
  final portrait = aspectRatios.where((r) => r > 0 && r < 1).length;
  return portrait * 2 > aspectRatios.length;
}
