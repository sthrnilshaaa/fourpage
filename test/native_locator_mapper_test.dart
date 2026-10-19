import 'package:aread/src/application/mappers/native_locator_mapper.dart';
import 'package:aread/src/domain/entities/annotation.dart';
import 'package:aread/src/domain/entities/locator.dart';
import 'package:aread/src/presentation/native_reader/native_reader_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const native = NativeLocator(
    href: 'OEBPS/ch5.html',
    resourceIndex: 5,
    charOffset: 4210,
    progression: 0.31,
    totalProgression: 0.12,
    globalPage: 80,
    pagesLeft: 600,
    textBefore: 'before',
    textAfter: 'after',
  );

  test('toLocator_keepsCharOffsetAndNoCfi', () {
    final l = NativeLocatorMapper.toLocator(native);
    expect(l.href, 'OEBPS/ch5.html');
    expect(l.locations.charOffset, 4210);
    expect(l.locations.totalProgression, 0.12);
    expect(l.locations.position, 80);
    expect(l.locations.cfi, isNull);
  });

  test('startFor_nativeLocator_usesHrefAndCharOffset', () {
    final start = NativeLocatorMapper.startFor(NativeLocatorMapper.toLocator(native));
    expect(start, const NativeStart.hrefChars('OEBPS/ch5.html', 4210));
  });

  test('startFor_cfiLocator_usesLegacyPath', () {
    const old = Locator(
      href: 'epubcfi(/6/14!/4/2/1:0)',
      locations: LocationParameters(progression: 0.4, totalProgression: 0.4, cfi: 'epubcfi(/6/14!/4/2/1:0)'),
    );
    expect(NativeLocatorMapper.startFor(old), const NativeStart.legacy('epubcfi(/6/14!/4/2/1:0)'));
    expect(NativeLocatorMapper.startFor(null), const NativeStart.beginning());
  });

  test('locationParameters_jsonRoundTrip_charOffset', () {
    const p = LocationParameters(charOffset: 12, charEnd: 40, progression: 0.5);
    final back = LocationParameters.fromJson(p.toJson());
    expect(back.charOffset, 12);
    expect(back.charEnd, 40);
    expect(LocationParameters.fromJson(const LocationParameters(progression: 0.1).toJson()).charOffset, isNull);
  });

  test('rangeOf_nativeAnnotation_andNullForCfi', () {
    final now = DateTime(2026);
    Annotation ann(Locator l) => Annotation(
          id: 'a',
          publicationId: 'p',
          locator: l,
          colorHex: '#FFEB3B',
          type: AnnotationType.highlight,
          createdAt: now,
          updatedAt: now,
        );
    final range = NativeLocatorMapper.rangeLocator('OEBPS/ch5.html', 10, 20, 'quote');
    expect(range.href, 'OEBPS/ch5.html#aread:10');
    final r = NativeLocatorMapper.rangeOf(ann(range));
    expect(r, (href: 'OEBPS/ch5.html', start: 10, end: 20));
    expect(NativeLocatorMapper.rangeOf(ann(const Locator(href: 'epubcfi(/6/4!/4,/1:0,/1:5)'))), isNull);
    expect(NativeLocatorMapper.colorOf('#FFEB3B'), 0xFFFFEB3B);
  });
}
