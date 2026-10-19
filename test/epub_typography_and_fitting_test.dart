import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aread/src/presentation/utils/html_stylist.dart';
import 'package:aread/src/application/mappers/sakura_epub_mapper.dart';
import 'package:aread/src/domain/entities/reader_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EPUB Typography & Styling Fidelity Tests', () {
    test('StyleGenUtils.addFontSize scales proportionally to base font size', () {
      const baseStyle16 = TextStyle(fontSize: 16.0);
      const baseStyle20 = TextStyle(fontSize: 20.0);

      // Relative units (em, rem, %)
      expect(StyleGenUtils.addFontSize(baseStyle16, '1.5em').fontSize, closeTo(24.0, 0.01));
      expect(StyleGenUtils.addFontSize(baseStyle20, '1.5em').fontSize, closeTo(30.0, 0.01));

      expect(StyleGenUtils.addFontSize(baseStyle16, '2rem').fontSize, closeTo(32.0, 0.01));
      expect(StyleGenUtils.addFontSize(baseStyle16, '120%').fontSize, closeTo(19.2, 0.01));
      expect(StyleGenUtils.addFontSize(baseStyle16, '80%').fontSize, closeTo(12.8, 0.01));

      // Absolute units (px, pt)
      expect(StyleGenUtils.addFontSize(baseStyle16, '22px').fontSize, 22.0);
      expect(StyleGenUtils.addFontSize(baseStyle16, '12pt').fontSize, closeTo(12 * 1.333, 0.01));

      // Standard CSS size keywords
      expect(StyleGenUtils.addFontSize(baseStyle20, 'smaller').fontSize, closeTo(17.0, 0.01));
      expect(StyleGenUtils.addFontSize(baseStyle20, 'larger').fontSize, closeTo(24.0, 0.01));
      expect(StyleGenUtils.addFontSize(baseStyle20, 'medium').fontSize, closeTo(20.0, 0.01));
      expect(StyleGenUtils.addFontSize(baseStyle20, 'xx-large').fontSize, closeTo(40.0, 0.01));
    });

    test('StyleGenUtils.addFontWeight handles numeric and named weights', () {
      const base = TextStyle();
      expect(StyleGenUtils.addFontWeight(base, 'bold').fontWeight, FontWeight.bold);
      expect(StyleGenUtils.addFontWeight(base, 'bolder').fontWeight, FontWeight.bold);
      expect(StyleGenUtils.addFontWeight(base, 'lighter').fontWeight, FontWeight.w300);
      expect(StyleGenUtils.addFontWeight(base, 'normal').fontWeight, FontWeight.normal);
      expect(StyleGenUtils.addFontWeight(base, '700').fontWeight, FontWeight.w700);
      expect(StyleGenUtils.addFontWeight(base, '300').fontWeight, FontWeight.w300);
    });

    test('StyleGenUtils.addFontStyle handles italic and oblique', () {
      const base = TextStyle();
      expect(StyleGenUtils.addFontStyle(base, 'italic').fontStyle, FontStyle.italic);
      expect(StyleGenUtils.addFontStyle(base, 'oblique').fontStyle, FontStyle.italic);
      expect(StyleGenUtils.addFontStyle(base, 'normal').fontStyle, FontStyle.normal);
    });

    testWidgets('HTML.toTextSpan parses heading hierarchy proportionally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              const defaultStyle = TextStyle(fontSize: 16.0);
              const html = '<h1>Heading 1</h1><h2>Heading 2</h2><p>Normal text</p>';
              final span = HTML.toTextSpan(context, html, defaultStyle: defaultStyle);

              expect(span.children, isNotNull);
              final spans = span.children!;
              expect(spans.length, greaterThanOrEqualTo(2));

              // Heading 1 should be larger than Heading 2, and Heading 2 larger than base
              final h1Span = spans.firstWhere(
                (s) => (s as TextSpan).text?.contains('Heading 1') == true,
              ) as TextSpan;
              final h2Span = spans.firstWhere(
                (s) => (s as TextSpan).text?.contains('Heading 2') == true,
              ) as TextSpan;

              expect(h1Span.style?.fontSize, greaterThan(h2Span.style?.fontSize ?? 0));
              expect(h2Span.style?.fontSize, greaterThan(defaultStyle.fontSize!));
              expect(h1Span.style?.fontWeight, FontWeight.bold);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('HTML.toTextSpan supports semantic tags (bold, italic, code, sub, sup)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              const defaultStyle = TextStyle(fontSize: 16.0);
              const html =
                  '<strong>Bold</strong><em>Italic</em><code>monospace</code><small>Small</small>';
              final span = HTML.toTextSpan(context, html, defaultStyle: defaultStyle);

              final spans = span.children!;
              final boldSpan = spans.firstWhere(
                (s) => (s as TextSpan).text?.contains('Bold') == true,
              ) as TextSpan;
              final italicSpan = spans.firstWhere(
                (s) => (s as TextSpan).text?.contains('Italic') == true,
              ) as TextSpan;
              final codeSpan = spans.firstWhere(
                (s) => (s as TextSpan).text?.contains('monospace') == true,
              ) as TextSpan;
              final smallSpan = spans.firstWhere(
                (s) => (s as TextSpan).text?.contains('Small') == true,
              ) as TextSpan;

              expect(boldSpan.style?.fontWeight, FontWeight.bold);
              expect(italicSpan.style?.fontStyle, FontStyle.italic);
              expect(codeSpan.style?.fontFamily, 'monospace');
              expect(smallSpan.style?.fontSize, lessThan(defaultStyle.fontSize!));

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    test('SakuraEpubMapper.themeFor configures styles without !important to preserve book layout', () {
      final theme = SakuraEpubMapper.themeFor(
        ReaderTheme.light,
        textAlignment: 'left',
        lineHeight: 1.6,
      );

      final customCss = theme.customCss;
      expect(customCss, isNotNull);

      // Body receives default text-align and line-height without !important
      final bodyCss = customCss!['body'] as Map<String, dynamic>?;
      expect(bodyCss, isNotNull);
      expect(bodyCss!['text-align'], 'left');
      expect(bodyCss['line-height'], '1.6');

      // Paragraph receives line-height without !important
      final pCss = customCss['p'] as Map<String, dynamic>?;
      expect(pCss, isNotNull);
      expect(pCss!['line-height'], '1.6');
      expect(pCss.containsKey('text-align'), isFalse);
    });

    test('SakuraEpubMapper.hexPageColorFor formats valid hex colors for WebView background blending', () {
      expect(SakuraEpubMapper.hexPageColorFor(ReaderTheme.light), '#fffcef');
      expect(SakuraEpubMapper.hexPageColorFor(ReaderTheme.dark), '#121211');
      expect(SakuraEpubMapper.hexPageColorFor(ReaderTheme.sepia), '#c2baa5');
      expect(SakuraEpubMapper.hexPageColorFor(ReaderTheme.highContrast), '#000000');
      expect(SakuraEpubMapper.hexPageColorFor(ReaderTheme.publisher), '#121a15');
    });
  });
}
