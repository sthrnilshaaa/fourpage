import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Local Book Pipeline & Rendering Fix Tests', () {
    late Uint8List sampleEpubWithImages;

    setUp(() {
      final archive = Archive();

      archive.addFile(ArchiveFile.string('mimetype', 'application/epub+zip'));

      const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      archive.addFile(ArchiveFile.string('META-INF/container.xml', containerXml));

      const opfXml = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Local Book With Images</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:language>en</dc:language>
    <dc:identifier id="pub-id">urn:uuid:1111-2222-3333</dc:identifier>
  </metadata>
  <manifest>
    <item id="ch1" href="chapters/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="images/illustration.png" media-type="image/png"/>
    <item id="cover" href="images/cover_art.jpg" media-type="image/jpeg" properties="cover-image"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
  </spine>
</package>''';
      archive.addFile(ArchiveFile.string('OEBPS/package.opf', opfXml));

      const ch1Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter One</title></head>
  <body>
    <h1>Heading One</h1>
    <p>Paragraph with text.</p>
    <img src="../images/illustration.png" alt="Test Illustration"/>
  </body>
</html>''';
      archive.addFile(ArchiveFile.string('OEBPS/chapters/ch1.xhtml', ch1Xml));

      archive.addFile(ArchiveFile('OEBPS/images/illustration.png', 4, [137, 80, 78, 71]));
      archive.addFile(ArchiveFile('OEBPS/images/cover_art.jpg', 3, [255, 216, 255]));

      final encoder = ZipEncoder();
      sampleEpubWithImages = Uint8List.fromList(encoder.encode(archive)!);
    });

    test('PublicationResourceResolver resolves relative asset paths correctly', () async {
      final container = OcfContainer.fromBytes(sampleEpubWithImages);
      final resolver = PublicationResourceResolver(container: container);

      expect(resolver.hasResource('OEBPS/images/illustration.png'), isTrue);
      expect(resolver.hasResource('../images/illustration.png'), isTrue);
      expect(resolver.hasResource('images/illustration.png'), isTrue);
      expect(resolver.hasResource('illustration.png'), isTrue);

      final bytes = await resolver.fetchResourceBytes('../images/illustration.png');
      expect(bytes, equals([137, 80, 78, 71]));
    });

    test('EpubPublicationParser identifies coverResource correctly', () async {
      final parser = EpubPublicationParser();
      final publication = await parser.parsePublication(sampleEpubWithImages);

      final cover = publication.coverResource;
      expect(cover, isNotNull);
      expect(cover!.href, equals('OEBPS/images/cover_art.jpg'));
    });

    test('PublicationResourceResolver fetches chapter XHTML text intact with tags', () async {
      final container = OcfContainer.fromBytes(sampleEpubWithImages);
      final resolver = PublicationResourceResolver(container: container);

      final text = await resolver.fetchResourceText('OEBPS/chapters/ch1.xhtml');
      expect(text, contains('Heading One'));
      expect(text, contains('<img src="../images/illustration.png"'));
    });
  });
}
