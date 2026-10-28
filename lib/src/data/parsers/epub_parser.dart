/// Master EPUB publication parser orchestrating OCF Container, OPF, and Nav parsers.
library;

import 'package:flutter/foundation.dart' show compute;
import 'package:xml/xml.dart';
import '../../core/utils/hash_utils.dart';
import '../../core/utils/path_utils.dart';
import '../../core/utils/xml_utils.dart';
import '../../domain/entities/derived_statistics.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/table_of_contents.dart';
import '../../domain/services/i_publication_parser.dart';
import '../container/ocf_container.dart';
import 'container_xml_parser.dart';
import 'navigation_parser.dart';
import 'package:aread/src/data/parsers/package_opf_parser.dart';

class EpubPublicationParser implements IPublicationParser {
  final ContainerXmlParser _containerXmlParser;
  final PackageOpfParser _packageOpfParser;
  final NavigationParser _navigationParser;

  EpubPublicationParser({
    ContainerXmlParser? containerXmlParser,
    PackageOpfParser? packageOpfParser,
    NavigationParser? navigationParser,
  })  : _containerXmlParser = containerXmlParser ?? ContainerXmlParser(),
        _packageOpfParser = packageOpfParser ?? PackageOpfParser(),
        _navigationParser = navigationParser ?? NavigationParser();

  /// Parses on a background isolate: it unzips and reads every chapter
  /// (for the word count), which froze the UI when done on the main thread.
  @override
  Future<Publication> parsePublication(List<int> archiveBytes, {String? filePath}) {
    return compute((_) => _parse(archiveBytes), null);
  }

  Publication _parse(List<int> archiveBytes) {
    final container = OcfContainer.fromBytes(archiveBytes);
    container.validateMimetype();

    // 1. Container.xml -> OPF rootfile path
    final containerXmlContent = container.readText('META-INF/container.xml');
    final opfPath = _containerXmlParser.parseRootfilePath(containerXmlContent);

    // 2. Encryption.xml -> encrypted hrefs & DRM scheme
    final (encryptedHrefs, drmScheme) = _parseEncryptionXml(container);

    // 3. Package OPF document -> Manifest, Spine, Metadata
    final opfXmlContent = container.readText(opfPath);
    final parsedPackage = _packageOpfParser.parse(
      opfXmlContent: opfXmlContent,
      packagePath: opfPath,
      encryptedHrefs: encryptedHrefs,
    );

    // 4. Navigation document -> Table of Contents
    var toc = const TableOfContents();
    if (parsedPackage.tocHref != null && container.hasEntry(parsedPackage.tocHref!)) {
      final navContent = container.readText(parsedPackage.tocHref!);
      toc = _navigationParser.parse(
        navContent: navContent,
        navDocumentPath: parsedPackage.tocHref!,
      );
    }

    // 5. Calculate derived statistics (word count, reading time, resource counts)
    final derivedStats = _calculateDerivedStatistics(container, parsedPackage);

    // 6. Compute content fingerprint (SHA-256 over ID, title, and spine hrefs)
    final spineSignature = parsedPackage.spine.map((s) => s.href).join('|');
    final fingerprintRaw = '${parsedPackage.metadata.identifier}::${parsedPackage.metadata.title}::$spineSignature';
    final fingerprint = HashUtils.sha256Text(fingerprintRaw);

    final id = parsedPackage.metadata.identifier.isNotEmpty
        ? HashUtils.sha256Text(parsedPackage.metadata.identifier).substring(0, 16)
        : fingerprint.substring(0, 16);

    return Publication(
      id: id,
      fingerprint: fingerprint,
      metadata: parsedPackage.metadata,
      resources: parsedPackage.manifest,
      spine: parsedPackage.spine,
      tableOfContents: toc,
      packagePath: opfPath,
      contentProtectionScheme: drmScheme,
      rendition: parsedPackage.rendition,
      derivedStatistics: derivedStats,
    );
  }

  DerivedStatistics _calculateDerivedStatistics(OcfContainer container, ParsedPackage parsedPackage) {
    int totalWords = 0;
    int totalChars = 0;
    int totalParagraphs = 0;

    for (final item in parsedPackage.spine) {
      if (container.hasEntry(item.href)) {
        try {
          final htmlText = container.readText(item.href);
          final plainText = _stripHtml(htmlText);

          totalChars += plainText.length;
          final words = plainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
          totalWords += words.length;

          final paragraphMatches = RegExp(r'<p[^>]*>', caseSensitive: false).allMatches(htmlText);
          totalParagraphs += paragraphMatches.length;
        } catch (_) {}
      }
    }

    final imageCount = parsedPackage.manifest.where((r) => r.isImage).length;
    final audioCount = parsedPackage.manifest.where((r) => r.isAudio).length;
    final videoCount = parsedPackage.manifest.where((r) => r.isVideo).length;
    final fontCount = parsedPackage.manifest.where((r) => r.isFont).length;
    final scriptCount = parsedPackage.manifest.where((r) => r.isScript).length;
    final stylesheetCount = parsedPackage.manifest.where((r) => r.isStylesheet).length;

    final readingTimeMinutes = (totalWords / 200).ceil();

    return DerivedStatistics(
      wordCount: totalWords,
      characterCount: totalChars,
      paragraphCount: totalParagraphs,
      chapterCount: parsedPackage.spine.length,
      imageCount: imageCount,
      audioCount: audioCount,
      videoCount: videoCount,
      fontCount: fontCount,
      scriptCount: scriptCount,
      stylesheetCount: stylesheetCount,
      estimatedReadingTimeMinutes: readingTimeMinutes,
    );
  }

  String _stripHtml(String html) {
    final noScripts = html.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ');
    final noTags = noScripts.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return noTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  (List<String>, String?) _parseEncryptionXml(OcfContainer container) {
    if (!container.hasEntry('META-INF/encryption.xml')) {
      return (const [], null);
    }

    try {
      final xmlContent = container.readText('META-INF/encryption.xml');
      final document = XmlDocument.parse(xmlContent);

      final encryptedHrefs = <String>[];
      String? scheme;

      for (final encryptedData in XmlUtils.findDescendants(document.rootElement, 'EncryptedData')) {
        final cipherData = XmlUtils.findDescendants(encryptedData, 'CipherData').firstOrNull;
        final cipherReference = cipherData != null
            ? XmlUtils.findDescendants(cipherData, 'CipherReference').firstOrNull
            : null;
        final uri = cipherReference != null ? XmlUtils.getAttribute(cipherReference, 'URI') : null;

        final encryptionMethod = XmlUtils.findDescendants(encryptedData, 'EncryptionMethod').firstOrNull;
        final algorithm = encryptionMethod != null ? XmlUtils.getAttribute(encryptionMethod, 'Algorithm') : null;

        if (uri != null) {
          encryptedHrefs.add(PathUtils.normalizePath(uri));
        }
        if (algorithm != null && scheme == null) {
          scheme = algorithm;
        }
      }

      return (encryptedHrefs, scheme);
    } catch (_) {
      return (const [], null);
    }
  }
}
