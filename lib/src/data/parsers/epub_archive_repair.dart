/// Pre-flight fix-up so epubx can open slightly broken real-world EPUBs.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class EpubArchiveRepair {
  EpubArchiveRepair._();

  /// Returns [bytes] with an empty stub added for every manifest item the
  /// ZIP doesn't contain, or [bytes] unchanged if nothing is missing (or the
  /// archive can't be inspected - epubx then reports the real error).
  ///
  /// epubx's `readBook` eagerly reads every manifest file and aborts the
  /// whole book on the first absent one ("file … not found in archive").
  /// Project Gutenberg's Alice, for example, lists a `pgepub.css` it never
  /// shipped. epub.js (the sakura engine) tolerates this, so without the
  /// repair the same book opened on Android but not on Linux.
  static List<int> fillMissingManifestEntries(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return bytes;
    }

    final missing = missingManifestItems(archive);
    if (missing.isEmpty) return bytes;

    for (final (path, mediaType) in missing) {
      // Images must stay decodable: epubx decodes the cover image while
      // opening the book, and an empty "cover.jpg" crashes that decoder.
      final stub = mediaType.startsWith('image/') ? _transparentGif : const <int>[];
      archive.addFile(ArchiveFile(path, stub.length, stub));
    }
    return ZipEncoder().encode(archive) ?? bytes;
  }

  /// 1x1 transparent GIF. Image decoders sniff the content, not the file
  /// extension, so it works as a stand-in for any missing raster image.
  static const List<int> _transparentGif = [
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, //
    0xFF, 0xFF, 0xFF, 0x21, 0xF9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00, //
    0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3B,
  ];

  /// `(archive path, media type)` of manifest items absent from [archive].
  /// Paths are built exactly as epubx will look them up.
  static List<(String, String)> missingManifestItems(Archive archive) {
    try {
      final container = archive.findFile('META-INF/container.xml');
      if (container == null) return const [];
      final rootfile = XmlDocument.parse(utf8.decode(container.content as List<int>))
          .findAllElements('rootfile')
          .firstOrNull
          ?.getAttribute('full-path');
      if (rootfile == null) return const [];
      final opf = archive.findFile(rootfile);
      if (opf == null) return const [];

      // epubx: ZipPathUtils.combine(ContentDirectoryPath, Uri.decodeFull(href)).
      final slash = rootfile.lastIndexOf('/');
      final contentDir = slash == -1 ? '' : rootfile.substring(0, slash);
      final names = {for (final f in archive.files) f.name};

      final missing = <(String, String)>[];
      final document = XmlDocument.parse(utf8.decode(opf.content as List<int>, allowMalformed: true));
      for (final item in document.findAllElements('item', namespace: '*')) {
        final href = item.getAttribute('href');
        if (href == null || href.isEmpty || href.contains('://')) continue;
        final decoded = Uri.decodeFull(href);
        final path = contentDir.isEmpty ? decoded : '$contentDir/$decoded';
        if (names.contains(path) || missing.any((m) => m.$1 == path)) continue;
        missing.add((path, item.getAttribute('media-type') ?? ''));
      }
      return missing;
    } catch (_) {
      return const [];
    }
  }
}
