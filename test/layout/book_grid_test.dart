import 'package:aread/src/presentation/layout/book_details_pane.dart';
import 'package:aread/src/presentation/layout/book_grid.dart';
import 'package:aread/src/presentation/state/library_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'book_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 1300}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  test('gridColumnsFor', () {
    expect(gridColumnsFor(400), 2);
    expect(gridColumnsFor(1000), 6);
    expect(gridColumnsFor(100), 2);
  });

  group('BookGrid taps', () {
    late List<BookItem> books;
    late List<String> opened;
    late List<String> selected;

    setUp(() {
      books = [fakeBook('a'), fakeBook('b'), fakeBook('c')];
      opened = [];
      selected = [];
    });

    Widget grid() => BookGrid(
          books: books,
          onOpen: (b) => opened.add(b.publication.id),
          onSelect: (b) => selected.add(b.publication.id),
        );

    testWidgets('mouse click selects without opening', (tester) async {
      await _pump(tester, grid());
      await tester.tap(find.text('Book b').last, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(selected, ['b']);
      expect(opened, isEmpty);
    });

    testWidgets('touch tap opens', (tester) async {
      await _pump(tester, grid());
      await tester.tap(find.text('Book b').last, kind: PointerDeviceKind.touch);
      await tester.pumpAndSettle();
      expect(opened, ['b']);
      expect(selected, isEmpty);
    });

    testWidgets('mouse double click opens', (tester) async {
      await _pump(tester, grid());
      final at = tester.getCenter(find.text('Book c').last);
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(opened, ['c']);
    });

    testWidgets('without onSelect a mouse click opens', (tester) async {
      await _pump(tester, BookGrid(books: books, onOpen: (b) => opened.add(b.publication.id)), width: 900);
      await tester.tap(find.text('Book a').last, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(opened, ['a']);
    });
  });

  for (final width in [1200.0, 1920.0]) {
    testWidgets('very long title does not overflow at $width', (tester) async {
      await _pump(
        tester,
        BookGrid(books: [fakeBook('x', title: 'T' * 200, author: 'A' * 120)], onOpen: (_) {}),
        width: width,
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('BookDetailsPane', () {
    testWidgets('empty state', (tester) async {
      await _pump(tester, const Row(children: [BookDetailsPane(book: null, onOpen: null)]));
      expect(find.text('Select a book to see its details'), findsOneWidget);
    });

    testWidgets('shows the book and continue reading opens it', (tester) async {
      var opened = 0;
      await _pump(tester, Row(children: [BookDetailsPane(book: fakeBook('a'), onOpen: () => opened++)]));
      expect(find.text('Book a'), findsWidgets);
      await tester.tap(find.text('Continue reading'));
      expect(opened, 1);
    });
  });

  group('resolveDetailsBook', () {
    final a = fakeBook('a'), b = fakeBook('b'), c = fakeBook('c');

    test('empty library gives null', () {
      expect(resolveDetailsBook(null, const []), isNull);
      expect(resolveDetailsBook(a, const []), isNull);
    });

    test('keeps the selection while it is in the library', () {
      expect(resolveDetailsBook(b, [a, b, c], recent: [c]), same(b));
    });

    test('removed selection falls back to the most recent book', () {
      expect(resolveDetailsBook(fakeBook('gone'), [a, b, c], recent: [c, a]), same(c));
    });

    test('nothing selected and nothing read gives null', () {
      expect(resolveDetailsBook(null, [a, b]), isNull);
    });
  });
}
