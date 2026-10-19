import 'package:aread/src/presentation/layout/master_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping a title selects it and the detail sits right of the list', (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MasterDetail(
          titles: const ['Appearance', 'Reading', 'About'],
          selected: 0,
          onSelected: (i) => picked = i,
          detail: const Text('detail body'),
        ),
      ),
    ));
    await tester.tap(find.text('Reading'));
    expect(picked, 1);
    expect(tester.getTopLeft(find.text('detail body')).dx, greaterThan(260));
  });
}
