/// Parser for META-INF/container.xml.
library;

import 'package:xml/xml.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/path_utils.dart';
import '../../core/utils/xml_utils.dart';

class ContainerXmlParser {
  ContainerXmlParser();

  /// Parses META-INF/container.xml and returns the normalized path to the root OPF file.
  String parseRootfilePath(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final rootfilesNode = XmlUtils.findDescendants(document.rootElement, 'rootfiles');
      if (rootfilesNode.isEmpty) {
        throw const PublicationParseException('Missing <rootfiles> tag in META-INF/container.xml');
      }

      for (final rootfile in XmlUtils.findDescendants(rootfilesNode.first, 'rootfile')) {
        final mediaType = XmlUtils.getAttribute(rootfile, 'media-type');
        final fullPath = XmlUtils.getAttribute(rootfile, 'full-path');

        if (fullPath != null &&
            (mediaType == 'application/oebps-package+xml' || mediaType == null || fullPath.endsWith('.opf'))) {
          return PathUtils.normalizePath(fullPath);
        }
      }

      throw const PublicationParseException('No valid OPF rootfile found in META-INF/container.xml');
    } catch (e) {
      if (e is PublicationParseException) rethrow;
      throw PublicationParseException('Failed to parse META-INF/container.xml', e);
    }
  }
}
