import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Full-Text Search Service Tests', () {
    test('finds query occurrences across spine items with exact snippets', () async {
      final publication = const Publication(
        id: 'pub1',
        fingerprint: 'fp',
        metadata: PublicationMetadata(title: 'Search Book', identifier: 'id'),
        packagePath: 'package.opf',
        spine: [
          SpineItem(idref: 'ch1', href: 'text/ch1.xhtml', mediaType: 'application/xhtml+xml', index: 0),
          SpineItem(idref: 'ch2', href: 'text/ch2.xhtml', mediaType: 'application/xhtml+xml', index: 1),
        ],
      );

      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'text/ch1.xhtml',
          '<html><body><h1>Chapter 1</h1><p>The clean architecture model is fundamental for modern software engineering.</p></body></html>',
        ),
      );
      archive.addFile(
        ArchiveFile.string(
          'text/ch2.xhtml',
          '<html><body><h1>Chapter 2</h1><p>Another mention of architecture in this section.</p></body></html>',
        ),
      );

      final container = OcfContainer.fromBytes(ZipEncoder().encode(archive)!);
      final resolver = PublicationResourceResolver(container: container);
      final searchService = EpubSearchService();

      final matches = await searchService.search(
        publication: publication,
        resolver: resolver,
        query: 'architecture',
      );

      expect(matches.length, equals(2));
      expect(matches.first.spineIndex, equals(0));
      expect(matches.first.matchedText, equals('architecture'));
      expect(matches.first.snippetBefore, contains('clean'));
      expect(matches.last.spineIndex, equals(1));
    });
  });
}
