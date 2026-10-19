import 'package:aread/src/presentation/layout/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showAdaptiveSheet<void>(
            context: context,
            builder: (_) => const SizedBox(key: ValueKey('content'), width: double.infinity, height: 100),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone width opens a bottom sheet', (tester) async {
    await _open(tester, const Size(400, 800));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('wide window opens a centered dialog at most 560 wide', (tester) async {
    await _open(tester, const Size(1300, 800));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, lessThanOrEqualTo(560));
  });
}
