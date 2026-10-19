import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OCF Container Tests', () {
    test('validates mimetype and reads container.xml entries', () {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));
      archive.addFile(
        ArchiveFile.string(
          'META-INF/container.xml',
          '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
              '<rootfiles><rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
        ),
      );
      archive.addFile(
        ArchiveFile.string(
          'OEBPS/package.opf',
          '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">'
              '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Test Book</dc:title><dc:identifier id="pub-id">12345</dc:identifier></metadata>'
              '<manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>'
              '<spine><itemref idref="ch1"/></spine></package>',
        ),
      );

      final zipBytes = ZipEncoder().encode(archive)!;
      final container = OcfContainer.fromBytes(zipBytes);

      expect(() => container.validateMimetype(), returnsNormally);
      expect(container.hasEntry('META-INF/container.xml'), isTrue);
      expect(container.hasEntry('OEBPS/package.opf'), isTrue);

      final parser = ContainerXmlParser();
      final rootPath = parser.parseRootfilePath(container.readText('META-INF/container.xml'));
      expect(rootPath, equals('OEBPS/package.opf'));
    });

    test('throws ContainerException for invalid mimetype', () {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('mimetype', 'text/plain'));
      final zipBytes = ZipEncoder().encode(archive)!;
      final container = OcfContainer.fromBytes(zipBytes);

      expect(() => container.validateMimetype(), throwsA(isA<ContainerException>()));
    });
  });
}
