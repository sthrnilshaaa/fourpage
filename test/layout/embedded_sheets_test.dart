import 'package:aread/src/core/constants/asset_constants.dart';
import 'package:aread/src/domain/entities/locator.dart';
import 'package:aread/src/domain/entities/nav_item.dart';
import 'package:aread/src/domain/entities/publication.dart';
import 'package:aread/src/domain/entities/publication_metadata.dart';
import 'package:aread/src/domain/entities/reader_preferences.dart';
import 'package:aread/src/domain/entities/table_of_contents.dart';
import 'package:aread/src/presentation/widgets/app_chrome.dart';
import 'package:aread/src/presentation/widgets/reader_customization_sheet.dart';
import 'package:aread/src/presentation/widgets/reader_toc_sheet.dart';
import 'package:aread/src/presentation/widgets/sakura_customization_sheet.dart';
import 'package:aread/src/presentation/widgets/sakura_toc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _chapters = [NavItem(title: 'One', href: 'one.xhtml'), NavItem(title: 'Two', href: 'two.xhtml')];

/// Pumps [pane] as a 300/320 wide side pane on a pushed route, so a stray
/// Navigator.pop would remove it.
Future<void> _pumpPane(WidgetTester tester, Widget pane, {double width = 320}) async {
  tester.view.physicalSize = const Size(1400, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: const Scaffold(body: Text('root'))));
  final nav = tester.state<NavigatorState>(find.byType(Navigator));
  nav.push(MaterialPageRoute(
    builder: (_) => Scaffold(body: Row(children: [SizedBox(width: width, child: pane), const Expanded(child: SizedBox())])),
  ));
  await tester.pumpAndSettle();
}

bool _hasCloseButton() =>
    find.byIcon(Icons.close_rounded).evaluate().isNotEmpty ||
    find.byWidgetPredicate((w) => w is FigmaIcon && w.asset == AssetConstants.iconCloseCircle).evaluate().isNotEmpty;

void main() {
  testWidgets('SakuraTocSheet embedded: fills the pane, no close, navigating keeps it open', (tester) async {
    String? went;
    await _pumpPane(
      tester,
      SakuraTocSheet(chapters: _chapters, onNavigateToHref: (h) => went = h, embedded: true),
      width: 300,
    );
    expect(tester.takeException(), isNull);
    expect(_hasCloseButton(), isFalse);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(went, 'two.xhtml');
    expect(find.byType(SakuraTocSheet), findsOneWidget);
  });

  testWidgets('ReaderTocSheet embedded: no close, navigating keeps it open', (tester) async {
    Locator? went;
    final publication = Publication(
      id: 'p',
      fingerprint: 'p',
      metadata: const PublicationMetadata(title: 'P', identifier: 'p'),
      packagePath: '',
      tableOfContents: const TableOfContents(items: _chapters),
    );
    await _pumpPane(
      tester,
      ReaderTocSheet(publication: publication, annotations: const [], bookmarks: const [], onNavigate: (l) => went = l, embedded: true),
      width: 300,
    );
    expect(tester.takeException(), isNull);
    expect(_hasCloseButton(), isFalse);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(went?.href, 'two.xhtml');
    expect(find.byType(ReaderTocSheet), findsOneWidget);
  });

  testWidgets('SakuraCustomizationSheet embedded fits a 320 pane', (tester) async {
    await _pumpPane(
      tester,
      SakuraCustomizationSheet(
        preferences: const ReaderPreferences(),
        onChanged: (_) {},
        brightness: 1,
        onBrightnessChanged: (_) {},
        embedded: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_hasCloseButton(), isFalse);
  });

  testWidgets('ReaderCustomizationSheet embedded fits a 320 pane', (tester) async {
    await _pumpPane(tester, ReaderCustomizationSheet(preferences: const ReaderPreferences(), onChanged: (_) {}, embedded: true));
    expect(tester.takeException(), isNull);
    expect(_hasCloseButton(), isFalse);
  });
}
