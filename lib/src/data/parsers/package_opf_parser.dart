/// Parser for EPUB Package document (package.opf).
library;

import 'package:xml/xml.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/path_utils.dart';
import '../../core/utils/xml_utils.dart';
import '../../domain/entities/accessibility_metadata.dart';
import '../../domain/entities/collection_info.dart';
import '../../domain/entities/contributor.dart';
import '../../domain/entities/manifest_resource.dart';
import '../../domain/entities/publication_metadata.dart';
import '../../domain/entities/rendition_information.dart';
import '../../domain/entities/spine_item.dart';

class ParsedPackage {
  final PublicationMetadata metadata;
  final List<ManifestResource> manifest;
  final List<SpineItem> spine;
  final String? tocHref; // Nav.xhtml or toc.ncx href relative to container root
  final String? coverHref;
  final RenditionInformation rendition;

  const ParsedPackage({
    required this.metadata,
    required this.manifest,
    required this.spine,
    this.tocHref,
    this.coverHref,
    this.rendition = const RenditionInformation(),
  });
}

class PackageOpfParser {
  PackageOpfParser();

  ParsedPackage parse({
    required String opfXmlContent,
    required String packagePath,
    List<String> encryptedHrefs = const [],
  }) {
    try {
      final document = XmlDocument.parse(opfXmlContent);
      final packageElement = document.rootElement;

      // 1. Metadata
      final metadataElement = XmlUtils.findDirectChild(packageElement, 'metadata') ??
          XmlUtils.findDescendants(packageElement, 'metadata').firstOrNull;
      if (metadataElement == null) {
        throw const PublicationParseException('Missing <metadata> section in OPF package document');
      }

      final metadata = _parseMetadata(metadataElement);

      // 2. Manifest
      final manifestElement = XmlUtils.findDirectChild(packageElement, 'manifest') ??
          XmlUtils.findDescendants(packageElement, 'manifest').firstOrNull;
      if (manifestElement == null) {
        throw const PublicationParseException('Missing <manifest> section in OPF package document');
      }

      final manifestMap = <String, ManifestResource>{}; // id -> resource
      String? ncxId;
      String? navHref;
      String? coverMetaId;
      String? coverResourceHref;

      for (final meta in XmlUtils.findDescendants(metadataElement, 'meta')) {
        final name = XmlUtils.getAttribute(meta, 'name');
        final content = XmlUtils.getAttribute(meta, 'content');
        if (name == 'cover' && content != null) {
          coverMetaId = content;
        }
      }

      for (final item in XmlUtils.findDescendants(manifestElement, 'item')) {
        final id = XmlUtils.getAttribute(item, 'id');
        final rawHref = XmlUtils.getAttribute(item, 'href');
        final mediaType = XmlUtils.getAttribute(item, 'media-type') ??
            (rawHref != null ? PathUtils.inferMediaType(rawHref) : 'application/octet-stream');
        final propertiesStr = XmlUtils.getAttribute(item, 'properties') ?? '';
        final fallbackId = XmlUtils.getAttribute(item, 'fallback');

        if (id != null && rawHref != null) {
          final resolvedHref = PathUtils.resolveHref(packagePath, rawHref);
          final props = propertiesStr.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
          final isEncrypted = encryptedHrefs.contains(resolvedHref);

          final resource = ManifestResource(
            href: resolvedHref,
            mediaType: mediaType,
            properties: props,
            fallbackHref: fallbackId,
            isEncrypted: isEncrypted,
          );

          manifestMap[id] = resource;

          if (props.contains('nav')) {
            navHref = resolvedHref;
          }
          if (props.contains('cover-image') || id == coverMetaId) {
            coverResourceHref = resolvedHref;
          }
        }
      }

      // 3. Spine & Rendition Page Progression
      final spineElement = XmlUtils.findDirectChild(packageElement, 'spine') ??
          XmlUtils.findDescendants(packageElement, 'spine').firstOrNull;
      if (spineElement == null) {
        throw const PublicationParseException('Missing <spine> section in OPF package document');
      }

      ncxId = XmlUtils.getAttribute(spineElement, 'toc');
      final pageProgressionStr = XmlUtils.getAttribute(spineElement, 'page-progression-direction');
      final pageProgressionDirection = pageProgressionStr == 'rtl'
          ? PageProgressionDirection.rtl
          : (pageProgressionStr == 'ltr'
              ? PageProgressionDirection.ltr
              : PageProgressionDirection.defaultDirection);

      final spineItems = <SpineItem>[];
      var index = 0;

      for (final itemref in XmlUtils.findDescendants(spineElement, 'itemref')) {
        final idref = XmlUtils.getAttribute(itemref, 'idref');
        final linearStr = XmlUtils.getAttribute(itemref, 'linear');
        final linear = linearStr == null || linearStr.toLowerCase() != 'no';
        final propertiesStr = XmlUtils.getAttribute(itemref, 'properties') ?? '';
        final props = propertiesStr.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

        if (idref != null && manifestMap.containsKey(idref)) {
          final res = manifestMap[idref]!;
          spineItems.add(
            SpineItem(
              idref: idref,
              href: res.href,
              mediaType: res.mediaType,
              linear: linear,
              properties: props,
              index: index++,
            ),
          );
        }
      }

      // Determine TOC href (EPUB 3 nav.xhtml preferred over EPUB 2 ncx)
      String? tocHref = navHref;
      if (tocHref == null && ncxId != null && manifestMap.containsKey(ncxId)) {
        tocHref = manifestMap[ncxId]!.href;
      }

      // Parse Rendition information
      final rendition = _parseRendition(metadataElement, pageProgressionDirection);

      final finalMetadata = PublicationMetadata(
        title: metadata.title,
        authors: metadata.authors,
        contributors: metadata.contributors,
        publisher: metadata.publisher,
        language: metadata.language,
        identifier: metadata.identifier,
        identifiers: metadata.identifiers,
        publicationDate: metadata.publicationDate,
        description: metadata.description,
        coverHref: coverResourceHref ?? metadata.coverHref,
        rights: metadata.rights,
        subjects: metadata.subjects,
        collections: metadata.collections,
        accessibility: metadata.accessibility,
      );

      return ParsedPackage(
        metadata: finalMetadata,
        manifest: manifestMap.values.toList(),
        spine: spineItems,
        tocHref: tocHref,
        coverHref: coverResourceHref,
        rendition: rendition,
      );
    } catch (e) {
      if (e is PublicationParseException) rethrow;
      throw PublicationParseException('Failed to parse package OPF document', e);
    }
  }

  PublicationMetadata _parseMetadata(XmlElement metadataElement) {
    String title = 'Untitled Publication';
    final authors = <String>[];
    final contributors = <Contributor>[];
    final identifiers = <String>[];
    final subjects = <String>[];
    final collections = <CollectionInfo>[];
    final accessFeatures = <String>[];
    final accessHazards = <String>[];
    final accessModes = <String>[];
    String? accessSummary;
    String? accessConformance;
    String? publisher;
    String? language;
    String identifier = 'uuid-${DateTime.now().millisecondsSinceEpoch}';
    String? publicationDate;
    String? description;
    String? rights;

    for (final child in metadataElement.childElements) {
      final name = child.name.local.toLowerCase();
      final text = XmlUtils.getTextContent(child);

      switch (name) {
        case 'title':
          if (text.isNotEmpty) title = text;
          break;
        case 'creator':
          if (text.isNotEmpty) {
            authors.add(text);
            final role = XmlUtils.getAttribute(child, 'opf:role') ?? 'aut';
            final fileAs = XmlUtils.getAttribute(child, 'opf:file-as');
            contributors.add(Contributor(name: text, role: role, fileAs: fileAs));
          }
          break;
        case 'contributor':
          if (text.isNotEmpty) {
            final role = XmlUtils.getAttribute(child, 'opf:role') ?? 'ctb';
            final fileAs = XmlUtils.getAttribute(child, 'opf:file-as');
            contributors.add(Contributor(name: text, role: role, fileAs: fileAs));
          }
          break;
        case 'publisher':
          if (text.isNotEmpty) publisher = text;
          break;
        case 'language':
          if (text.isNotEmpty) language = text;
          break;
        case 'identifier':
          if (text.isNotEmpty) {
            identifier = text;
            identifiers.add(text);
          }
          break;
        case 'subject':
          if (text.isNotEmpty) subjects.add(text);
          break;
        case 'date':
          if (text.isNotEmpty) publicationDate = text;
          break;
        case 'description':
          if (text.isNotEmpty) description = text;
          break;
        case 'rights':
          if (text.isNotEmpty) rights = text;
          break;
        case 'meta':
          final property = XmlUtils.getAttribute(child, 'property') ?? XmlUtils.getAttribute(child, 'name');
          final value = text.isNotEmpty ? text : XmlUtils.getAttribute(child, 'content');
          if (property != null && value != null && value.isNotEmpty) {
            if (property == 'belongs-to-collection') {
              collections.add(CollectionInfo(name: value));
            } else if (property.contains('accessibilityFeature')) {
              accessFeatures.add(value);
            } else if (property.contains('accessibilityHazard')) {
              accessHazards.add(value);
            } else if (property.contains('accessMode')) {
              accessModes.add(value);
            } else if (property.contains('accessibilitySummary')) {
              accessSummary = value;
            } else if (property.contains('conformsTo')) {
              accessConformance = value;
            }
          }
          break;
      }
    }

    final accessibility = AccessibilityMetadata(
      features: accessFeatures,
      hazards: accessHazards,
      summary: accessSummary,
      accessModes: accessModes,
      conformance: accessConformance,
    );

    return PublicationMetadata(
      title: title,
      authors: authors,
      contributors: contributors,
      publisher: publisher,
      language: language,
      identifier: identifier,
      identifiers: identifiers,
      publicationDate: publicationDate,
      description: description,
      coverHref: null,
      rights: rights,
      subjects: subjects,
      collections: collections,
      accessibility: accessibility,
    );
  }

  RenditionInformation _parseRendition(
    XmlElement metadataElement,
    PageProgressionDirection pageProgressionDirection,
  ) {
    RenditionLayout layout = RenditionLayout.reflowable;
    RenditionOrientation orientation = RenditionOrientation.auto;
    RenditionSpread spread = RenditionSpread.auto;
    String? width;
    String? height;

    for (final meta in XmlUtils.findDescendants(metadataElement, 'meta')) {
      final prop = XmlUtils.getAttribute(meta, 'property') ?? XmlUtils.getAttribute(meta, 'name');
      final val = XmlUtils.getTextContent(meta).isNotEmpty
          ? XmlUtils.getTextContent(meta)
          : XmlUtils.getAttribute(meta, 'content');

      if (prop != null && val != null) {
        if (prop == 'rendition:layout' && val == 'pre-paginated') {
          layout = RenditionLayout.fixedLayout;
        } else if (prop == 'rendition:orientation') {
          if (val == 'landscape') orientation = RenditionOrientation.landscape;
          if (val == 'portrait') orientation = RenditionOrientation.portrait;
        } else if (prop == 'rendition:spread') {
          if (val == 'none') spread = RenditionSpread.none;
          if (val == 'landscape') spread = RenditionSpread.landscape;
          if (val == 'both') spread = RenditionSpread.both;
        } else if (prop == 'rendition:viewport') {
          final parts = val.split(RegExp(r'[\s,=]+'));
          final wIndex = parts.indexOf('width');
          if (wIndex != -1 && wIndex + 1 < parts.length) width = parts[wIndex + 1];
          final hIndex = parts.indexOf('height');
          if (hIndex != -1 && hIndex + 1 < parts.length) height = parts[hIndex + 1];
        }
      }
    }

    return RenditionInformation(
      layout: layout,
      viewportWidth: width,
      viewportHeight: height,
      orientation: orientation,
      spread: spread,
      pageProgressionDirection: pageProgressionDirection,
    );
  }
}
