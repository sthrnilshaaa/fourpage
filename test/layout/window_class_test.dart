import 'package:aread/src/presentation/layout/window_class.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WindowClass of(double w, double h, TargetPlatform p) => windowClassFor(Size(w, h), platform: p);

  test('desktop is classified by width', () {
    expect(of(599, 800, TargetPlatform.linux), WindowClass.compact);
    expect(of(600, 800, TargetPlatform.linux), WindowClass.medium);
    expect(of(1199, 800, TargetPlatform.linux), WindowClass.medium);
    expect(of(1200, 800, TargetPlatform.linux), WindowClass.expanded);
  });

  test('short but wide desktop window is not treated as a phone', () {
    expect(of(1300, 500, TargetPlatform.linux), WindowClass.expanded);
    expect(of(1300, 500, TargetPlatform.windows), WindowClass.expanded);
  });

  test('phones stay compact in landscape', () {
    expect(of(850, 400, TargetPlatform.android), WindowClass.compact);
    expect(of(900, 420, TargetPlatform.iOS), WindowClass.compact);
  });

  test('tablets are classified by width', () {
    expect(of(1280, 800, TargetPlatform.android), WindowClass.expanded);
    expect(of(800, 1280, TargetPlatform.android), WindowClass.medium);
    expect(of(1000, 700, TargetPlatform.iOS), WindowClass.medium);
  });

  test('enum getters', () {
    expect(WindowClass.compact.isCompact, isTrue);
    expect(WindowClass.medium.isMedium, isTrue);
    expect(WindowClass.expanded.isExpanded, isTrue);
    expect(WindowClass.expanded.isCompact, isFalse);
  });
}
