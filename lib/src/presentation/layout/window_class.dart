/// Window size classes shared by every screen.
///
/// compact < 600 (today's phone layout), medium 600-1199 (nav rail, two
/// parts), expanded >= 1200 (sidebar, three parts). Phones (Android/iOS with
/// a shortest side under 600) stay compact in landscape too.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum WindowClass {
  compact,
  medium,
  expanded;

  bool get isCompact => this == compact;
  bool get isMedium => this == medium;
  bool get isExpanded => this == expanded;
}

const double mediumBreakpoint = 600;
const double expandedBreakpoint = 1200;

WindowClass windowClassFor(Size size, {required TargetPlatform platform}) {
  final mobile = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  if (mobile && size.shortestSide < mediumBreakpoint) return WindowClass.compact;
  if (size.width >= expandedBreakpoint) return WindowClass.expanded;
  if (size.width >= mediumBreakpoint) return WindowClass.medium;
  return WindowClass.compact;
}

extension WindowClassX on BuildContext {
  WindowClass get windowClass => windowClassFor(MediaQuery.sizeOf(this), platform: defaultTargetPlatform);
}
