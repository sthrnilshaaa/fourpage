import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hides the status bar and navigation bar while a book is being read, and
/// brings them back together with the reader's own controls.
class ReaderSystemBars {
  ReaderSystemBars._();

  /// Full screen: both system bars hidden. A swipe in from the edge brings
  /// them back and [listen] reports it (sticky mode would not notify us).
  static Future<void> hide() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  /// Both bars drawn over the app, the same window size as [hide], so the
  /// page never changes size when they come and go.
  static Future<void> show() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  /// Calls [onShown] when the system bars appear on their own (edge swipe).
  static Future<void> listen(VoidCallback onShown) =>
      SystemChrome.setSystemUIChangeCallback((visible) async {
        if (visible) onShown();
      });

  static Future<void> stopListening() => SystemChrome.setSystemUIChangeCallback(null);

  /// The space kept clear above and below the page. It doesn't depend on
  /// whether the system bars are showing, so toggling them never re-lays out
  /// the book: the page uses the screen up to the camera cutout, and the bars
  /// draw over it when shown.
  static EdgeInsets pageInsets(MediaQueryData media, {TargetPlatform? platform}) {
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android) {
      // iOS keeps its notch and home-indicator insets with the bars hidden;
      // desktop has none.
      return EdgeInsets.only(top: media.viewPadding.top, bottom: media.viewPadding.bottom);
    }
    var top = 0.0;
    var bottom = 0.0;
    final height = media.size.height;
    for (final feature in media.displayFeatures) {
      if (feature.type != DisplayFeatureType.cutout) continue;
      final b = feature.bounds;
      if (b.top <= 0.5 && b.bottom < height / 2) top = math.max(top, b.bottom);
      if (b.bottom >= height - 0.5 && b.top > height / 2) bottom = math.max(bottom, height - b.top);
    }
    return EdgeInsets.only(top: top, bottom: bottom);
  }
}
