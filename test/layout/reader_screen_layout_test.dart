import 'package:aread/src/presentation/layout/reader_pane_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the book view that remembers state (like the EPUB list's
/// scroll position) so we can see whether a resize rebuilt it from scratch.
class _Book extends StatefulWidget {
  const _Book();
  @override
  State<_Book> createState() => _BookState();
}

class _BookState extends State<_Book> {
  int position = 0;
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _layout() => MaterialApp(
      home: ReaderPaneLayout(
        book: const _Book(),
        contents: const SizedBox.expand(key: ValueKey('contents')),
        settings: const SizedBox.expand(),
        focusMode: false,
        contentsOpen: true,
        settingsOpen: true,
        background: Colors.black,
      ),
    );

void main() {
  testWidgets('resizing across breakpoints keeps the book state', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpWidget(_layout());
    expect(find.byKey(const ValueKey('contents')), findsOneWidget);
    tester.state<_BookState>(find.byType(_Book)).position = 42;

    for (final w in [900.0, 500.0, 1500.0]) {
      tester.view.physicalSize = Size(w, 900);
      await tester.pump();
      expect(tester.state<_BookState>(find.byType(_Book)).position, 42, reason: 'width $w');
    }
  });

  testWidgets('ReaderFocusReturn gives keyboard focus back to the book after a pane tap', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final keys = <LogicalKeyboardKey>[];
    await tester.pumpWidget(MaterialApp(
      home: Focus(
        focusNode: node,
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent) keys.add(e.logicalKey);
          return KeyEventResult.handled;
        },
        child: Material(child: Row(children: [
          SizedBox(
            width: 300,
            child: ReaderFocusReturn(
              focusNode: node,
              child: ListView(children: [ListTile(title: const Text('Chapter'), onTap: () {}), const TextField()]),
            ),
          ),
        ])),
      ),
    ));
    await tester.tap(find.byType(TextField)); // steals focus, like any focusable control
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(keys, [LogicalKeyboardKey.arrowRight]);
  });
}
