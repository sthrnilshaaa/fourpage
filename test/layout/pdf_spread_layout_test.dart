import 'package:aread/src/presentation/layout/pdf_page_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gap = 12.0;

  test('single column matches the original layout', () {
    final rects = layoutPdfPages([0.707, 0.707, 1.4], 1000, gap: gap, spread: false, top: 50);
    var y = 50.0;
    for (var i = 0; i < 3; i++) {
      final ratio = [0.707, 0.707, 1.4][i];
      final h = (1000 - 2 * gap) / ratio;
      expect(rects[i].left, gap);
      expect(rects[i].width, 1000 - 2 * gap);
      expect(rects[i].top, closeTo(y, 1e-9));
      expect(rects[i].height, closeTo(h, 1e-9));
      y += h + gap;
    }
  });

  test('spread: cover alone and centered, then pairs side by side', () {
    final rects = layoutPdfPages([0.707, 0.707, 0.707], 1000, gap: gap, spread: true);
    final pw = (1000 - 3 * gap) / 2;
    expect(rects[0].width, closeTo(pw, 1e-9));
    expect(rects[0].center.dx, closeTo(500, 1e-9));
    expect(rects[1].top, rects[2].top);
    expect(rects[1].right, lessThan(rects[2].left));
    expect(rects[1].top, greaterThan(rects[0].bottom));
    expect(rects[1].width, closeTo(pw, 1e-9));
  });

  test('spread: odd last page sits on the left of its own row', () {
    final rects = layoutPdfPages([0.707, 0.707, 0.707, 0.707], 1000, gap: gap, spread: true);
    expect(rects[3].left, gap);
    expect(rects[3].top, greaterThan(rects[2].bottom));
  });

  test('tops never decrease (page lookup by y relies on it)', () {
    final rects = layoutPdfPages(List.filled(9, 0.707), 1200, gap: gap, spread: true);
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].top));
    }
  });

  test('spread only for mostly portrait documents', () {
    expect(pdfWantsSpread([0.707, 0.75, 0.7]), isTrue);
    expect(pdfWantsSpread([1.4, 1.4, 0.7]), isFalse);
    expect(pdfWantsSpread(const []), isFalse);
  });
}
