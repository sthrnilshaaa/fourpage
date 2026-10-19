import 'package:aread/src/core/constants/asset_constants.dart';
import 'package:aread/src/presentation/layout/app_nav_rail.dart';
import 'package:aread/src/presentation/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = ['Home', 'Library', 'Saved', 'Settings'];

List<NavDestination> _destinations([List<String> labels = _labels]) => [
      for (final l in labels)
        NavDestination(
          label: l,
          icon: AssetConstants.navHome,
          activeIcon: AssetConstants.navHomeActive,
          size: const Size(24, 24),
        ),
    ];

Future<void> _pump(WidgetTester tester, {required bool extended, int selected = 0, ValueChanged<int>? onSelected, List<String> labels = _labels}) async {
  tester.view.physicalSize = Size(extended ? 1300 : 800, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Row(children: [
        AppNavRail(
          destinations: _destinations(labels),
          selectedIndex: selected,
          onSelected: onSelected ?? (_) {},
          extended: extended,
        ),
        const Expanded(child: SizedBox()),
      ]),
    ),
  ));
}

void main() {
  testWidgets('extended sidebar shows labels', (tester) async {
    await _pump(tester, extended: true);
    for (final l in _labels) {
      expect(find.text(l), findsOneWidget);
    }
    expect(tester.getSize(find.byType(AppNavRail)).width, 220);
  });

  testWidgets('rail is icon-only and 76 wide', (tester) async {
    await _pump(tester, extended: false);
    for (final l in _labels) {
      expect(find.text(l), findsNothing);
    }
    expect(tester.getSize(find.byType(AppNavRail)).width, 76);
  });

  testWidgets('tapping a destination selects it', (tester) async {
    int? picked;
    await _pump(tester, extended: true, onSelected: (i) => picked = i);
    await tester.tap(find.text('Saved'));
    expect(picked, 2);
  });

  testWidgets('selected item is solid lime', (tester) async {
    await _pump(tester, extended: true, selected: 1);
    final box = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('nav-item-1')));
    expect((box.decoration as BoxDecoration).color, AppColors.figmaLime);
    final other = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('nav-item-0')));
    expect((other.decoration as BoxDecoration).color, isNot(AppColors.figmaLime));
  });

  testWidgets('long labels do not overflow', (tester) async {
    await _pump(tester, extended: true, labels: ['A' * 60, 'B', 'C', 'D']);
    expect(tester.takeException(), isNull);
  });
}
