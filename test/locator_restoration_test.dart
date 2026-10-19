import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Locator Restoration & Position Manager Tests', () {
    late Publication publication;
    late IResourceResolver resolver;

    setUp(() {
      publication = Publication(
        id: 'pub1',
        fingerprint: 'fp123',
        metadata: const PublicationMetadata(title: 'Restoration Test', identifier: 'id1'),
        packagePath: 'OEBPS/package.opf',
        spine: const [
          SpineItem(idref: 's1', href: 'OEBPS/ch1.xhtml', mediaType: 'application/xhtml+xml', index: 0),
          SpineItem(idref: 's2', href: 'OEBPS/ch2.xhtml', mediaType: 'application/xhtml+xml', index: 1),
        ],
      );

      final archive = Archive();
      archive.addFile(ArchiveFile.string('OEBPS/ch1.xhtml', '<html><body><h1 id="sec-1">Header</h1><p>Some paragraph text here.</p></body></html>'));
      archive.addFile(ArchiveFile.string('OEBPS/ch2.xhtml', '<html><body><h1 id="sec-2">Chapter 2</h1></body></html>'));

      final container = OcfContainer.fromBytes(ZipEncoder().encode(archive)!);
      resolver = PublicationResourceResolver(container: container);
    });

    test('Step 0b: native reader locator (char offset) is kept exactly', () async {
      final strategy = PositionRestorationStrategy();
      const target = Locator(
        href: 'OEBPS/Text/not-in-this-spine.xhtml',
        locations: LocationParameters(progression: 0.4, totalProgression: 0.2, position: 80, charOffset: 4210),
      );
      final result = await strategy.restorePosition(
        publication: publication,
        targetLocator: target,
        resolver: resolver,
      );
      expect(result.isExact, isTrue);
      expect(result.locator.locations.charOffset, 4210);
      expect(result.locator.href, target.href);
      expect(result.locator.locations.totalProgression, 0.2);
    });

    test('Step 1/2: restores exact fragment ID', () async {
      final strategy = PositionRestorationStrategy();
      final target = const Locator(
        href: 'OEBPS/ch1.xhtml#sec-1',
        locations: LocationParameters(fragment: 'sec-1', position: 0),
      );

      final result = await strategy.restorePosition(
        publication: publication,
        targetLocator: target,
        resolver: resolver,
      );

      expect(result.isExact, isTrue);
      expect(result.restorationStepName, contains('Step 1/2'));
    });

    test('Step 3: restores by text quote context match', () async {
      final strategy = PositionRestorationStrategy();
      final target = const Locator(
        href: 'OEBPS/ch1.xhtml',
        locations: LocationParameters(position: 0),
        text: TextContext(highlight: 'Some paragraph text'),
      );

      final result = await strategy.restorePosition(
        publication: publication,
        targetLocator: target,
        resolver: resolver,
      );

      expect(result.isExact, isTrue);
      expect(result.restorationStepName, contains('Step 3'));
    });

    test('Step 4: fallback to resource progression when fragment fails', () async {
      final strategy = PositionRestorationStrategy();
      final target = const Locator(
        href: 'OEBPS/ch1.xhtml#non-existent',
        locations: LocationParameters(fragment: 'non-existent', progression: 0.5, position: 0),
      );

      final result = await strategy.restorePosition(
        publication: publication,
        targetLocator: target,
        resolver: resolver,
      );

      expect(result.isExact, isFalse);
      expect(result.restorationStepName, contains('Step 4'));
      expect(result.locator.locations.progression, equals(0.5));
    });

    test('PositionManager calculates next/previous locators and completion percentage', () {
      final pm = LocatorPositionManager();
      final current = const Locator(
        href: 'OEBPS/ch1.xhtml',
        locations: LocationParameters(position: 0, totalProgression: 0.0),
      );

      final next = pm.getNextSpineLocator(publication, current);
      expect(next, isNotNull);
      expect(next!.href, equals('OEBPS/ch2.xhtml'));

      final prev = pm.getPreviousSpineLocator(publication, current);
      expect(prev, isNull);

      final pct = pm.computePercentage(publication, next);
      expect(pct, equals(50.0));
    });
  });
}
