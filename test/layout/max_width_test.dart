import 'package:aread/src/presentation/layout/max_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _childWidth(WidgetTester tester, double available) async {
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: available,
        height: 300,
        child: const MaxWidth(maxWidth: 760, child: SizedBox(key: ValueKey('c'), width: double.infinity, height: 10)),
      ),
    ),
  ));
  return tester.getSize(find.byKey(const ValueKey('c'))).width;
}

void main() {
  testWidgets('caps at maxWidth when wider', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    expect(await _childWidth(tester, 1300), 760);
  });

  testWidgets('fills when narrower', (tester) async {
    expect(await _childWidth(tester, 500), 500);
  });
}
