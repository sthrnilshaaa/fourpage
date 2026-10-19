/// Page-curl drawing for the paginated reader.
///
/// The book page is a native WebView, which Flutter can't bend, so a turn is
/// drawn from snapshots of it: the turning page curls over a cylinder (GPU
/// shader, shaders/page_curl.frag) while the page underneath is either a
/// second snapshot or the live WebView showing through.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PageCurl {
  PageCurl._();

  static Future<ui.FragmentProgram?>? _program;

  /// The compiled curl shader, or null where shaders aren't available (the
  /// turn then falls back to a slide).
  static Future<ui.FragmentProgram?> program() => _program ??= ui.FragmentProgram.fromAsset(
        'shaders/page_curl.frag',
      ).then<ui.FragmentProgram?>((p) => p).catchError((Object e) {
        debugPrint('PageCurl: shader unavailable ($e), using slide');
        return null;
      });

  /// Largest roll radius for a page [width] wide.
  static double radius(double width) => width * 0.10;

  /// Edge position (the page's right-most visible point) when flat.
  static double flatEdge(double width) => width;

  /// Edge position once the page has fully slid away.
  static double goneEdge(double width) => -8;

  /// 0 = flat, 1 = turned away.
  static double progress(double edge, double width) =>
      ((flatEdge(width) - edge) / (flatEdge(width) - goneEdge(width))).clamp(0.0, 1.0);
}

/// Paints one moment of a turn.
///
/// [edge] is where the page's free (right) edge is on screen, between
/// [PageCurl.goneEdge] and [PageCurl.flatEdge]. A forward turn moves it
/// right to left; a backward turn brings the previous page back by moving
/// it left to right. [front] is the turning page, [back] the page under it
/// (null = transparent, the live WebView shows through).
class PageCurlPainter extends CustomPainter {
  final ui.FragmentProgram? program;
  final ui.Image? front;
  final ui.Image? back;

  /// Repaints on its own as this changes - no widget rebuild per frame.
  final ValueListenable<double> edge;

  /// Fold tilt, from where the page was grabbed (-0.25..0.25; 0 = upright).
  final double tilt;
  final Color paper;

  PageCurlPainter({
    required this.program,
    required this.front,
    required this.back,
    required this.edge,
    required this.tilt,
    required this.paper,
  }) : super(repaint: edge);

  @override
  void paint(Canvas canvas, Size size) {
    final edge = this.edge.value;
    final rect = Offset.zero & size;
    final front = this.front;
    if (front == null) {
      if (back != null) _drawImage(canvas, back!, rect);
      return;
    }
    final program = this.program;
    if (program == null) {
      _paintSlide(canvas, size, front);
      return;
    }

    final w = size.width;
    final p = PageCurl.progress(edge, w);
    // The roll grows in quickly as the turn starts and stays while it moves.
    final r = PageCurl.radius(w) * (p * 5).clamp(0.0, 1.0);
    // Tilt only mid-turn, so the roll never pokes in at the start or end.
    final t = tilt * math.sin(math.pi * p);
    final len = math.sqrt(1 + t * t);
    final dir = Offset(1 / len, t / len);
    // The page's visible right-most point is `edge`: the flat part slides
    // by `shift`, then a quarter roll (pi/2 * r of page) shows r wide.
    final shift = math.max(0.0, w - edge - r * (math.pi / 2 - 1));
    final foldX = w - shift - r * math.pi / 2;
    final origin = Offset(foldX, size.height / 2);

    final shader = program.fragmentShader()
      ..setFloat(0, w)
      ..setFloat(1, size.height)
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, dir.dx)
      ..setFloat(5, dir.dy)
      ..setFloat(6, r)
      ..setFloat(7, shift)
      ..setFloat(8, back != null ? 1 : 0)
      ..setImageSampler(0, front)
      ..setImageSampler(1, back ?? front);
    canvas.drawRect(rect, Paint()..shader = shader);
    shader.dispose();
  }

  /// No shader: the page slides off (or back on) with a shadow at its edge.
  void _paintSlide(Canvas canvas, Size size, ui.Image front) {
    final edge = this.edge.value;
    final rect = Offset.zero & size;
    if (back != null) _drawImage(canvas, back!, rect);
    final dx = -PageCurl.progress(edge, size.width) * size.width;
    final moved = rect.shift(Offset(dx, 0));
    canvas.drawRect(
      Rect.fromLTWH(moved.right, 0, 24, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent],
        ).createShader(Rect.fromLTWH(moved.right, 0, 24, size.height)),
    );
    _drawImage(canvas, front, moved);
  }

  void _drawImage(Canvas canvas, ui.Image image, Rect dst) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(PageCurlPainter old) =>
      old.edge != edge ||
      old.edge.value != edge.value ||
      old.front != front ||
      old.back != back ||
      old.tilt != tilt ||
      old.paper != paper ||
      old.program != program;
}
