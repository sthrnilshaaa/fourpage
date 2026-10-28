import 'package:aread/src/presentation/layout/reader_pane_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _book = ValueKey('book');
const _contents = ValueKey('contents');
const _settings = ValueKey('settings');

Future<void> _pump(WidgetTester tester, {double width = 1400, bool focus = false, bool contentsOpen = true, bool settingsOpen = true}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ReaderPaneLayout(
      book: const SizedBox.expand(key: _book),
      contents: const SizedBox.expand(key: _contents),
      settings: const SizedBox.expand(key: _settings),
      topBar: const SizedBox(height: 56, child: Text('top')),
      bottomBar: const SizedBox(height: 48, child: Text('bottom')),
      focusMode: focus,
      contentsOpen: contentsOpen,
      settingsOpen: settingsOpen,
      background: Colors.black,
    ),
  ));
}

void main() {
  testWidgets('expanded shows both panes at 300 and 320', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byKey(_contents)).width, 300);
    expect(tester.getSize(find.byKey(_settings)).width, 320);
    expect(find.text('top'), findsOneWidget);
    expect(find.text('bottom'), findsOneWidget);
  });

  testWidgets('closing the contents pane widens the book', (tester) async {
    await _pump(tester);
    final before = tester.getSize(find.byKey(_book)).width;
    await _pump(tester, contentsOpen: false);
    expect(find.byKey(_contents), findsNothing);
    expect(tester.getSize(find.byKey(_book)).width, greaterThan(before));
  });

  testWidgets('focus mode shows only the book', (tester) async {
    await _pump(tester, focus: true);
    expect(find.byKey(_contents), findsNothing);
    expect(find.byKey(_settings), findsNothing);
    expect(find.text('top'), findsNothing);
    expect(tester.getSize(find.byKey(_book)).width, 1400);
  });

  testWidgets('medium width shows only the book', (tester) async {
    await _pump(tester, width: 900);
    expect(find.byKey(_contents), findsNothing);
    expect(find.text('top'), findsNothing);
  });

  testWidgets('book keeps its state across focus mode toggles', (tester) async {
    await _pump(tester);
    final element = tester.element(find.byKey(_book));
    await _pump(tester, focus: true);
    expect(tester.element(find.byKey(_book)), same(element));
  });

  testWidgets('book sees its own pane as the screen size, with no system padding', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 30);
    addTearDown(tester.view.reset);
    late MediaQueryData seen;
    await tester.pumpWidget(MaterialApp(
      home: ReaderPaneLayout(
        book: Builder(builder: (c) {
          seen = MediaQuery.of(c);
          return const SizedBox.expand();
        }),
        contents: const SizedBox.expand(),
        settings: const SizedBox.expand(),
        topBar: const SizedBox(height: 56),
        bottomBar: const SizedBox(height: 44),
        focusMode: false,
        contentsOpen: true,
        settingsOpen: true,
        background: Colors.black,
      ),
    ));
    expect(seen.size, const Size(1400 - 300 - 320, 900 - 56 - 44));
    expect(seen.padding, EdgeInsets.zero);
  });

  testWidgets('list tiles in a pane get their ink on the pane surface', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderPaneLayout(
          book: const SizedBox.expand(),
          contents: ListView(children: [ListTile(title: const Text('Chapter'), onTap: () {})]),
          focusMode: false,
          contentsOpen: true,
          settingsOpen: true,
          background: Colors.black,
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
