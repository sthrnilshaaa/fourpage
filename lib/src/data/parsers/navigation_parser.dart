/// Parser for EPUB 3 nav.xhtml and EPUB 2 toc.ncx navigation documents.
library;

import 'package:xml/xml.dart';
import '../../core/utils/path_utils.dart';
import '../../core/utils/xml_utils.dart';
import '../../domain/entities/nav_item.dart';
import '../../domain/entities/table_of_contents.dart';

class NavigationParser {
  NavigationParser();

  /// Parses navigation document (nav.xhtml or toc.ncx).
  TableOfContents parse({
    required String navContent,
    required String navDocumentPath,
  }) {
    if (navContent.contains('<ncx') || navDocumentPath.endsWith('.ncx')) {
      return _parseNcx(navContent, navDocumentPath);
    }
    return _parseEpub3Nav(navContent, navDocumentPath);
  }

  /// Parses EPUB 3 nav.xhtml
  TableOfContents _parseEpub3Nav(String htmlContent, String navDocumentPath) {
    try {
      final document = XmlDocument.parse(htmlContent);
      final navElements = XmlUtils.findDescendants(document.rootElement, 'nav');

      final tocItems = <NavItem>[];
      final landmarks = <NavItem>[];
      final pageList = <NavItem>[];

      for (final nav in navElements) {
        final type = XmlUtils.getAttribute(nav, 'epub:type') ?? XmlUtils.getAttribute(nav, 'type');
        final ol = XmlUtils.findDescendants(nav, 'ol').firstOrNull;
        if (ol == null) continue;

        final items = _parseOlItems(ol, navDocumentPath);

        if (type == 'toc' || type == null) {
          tocItems.addAll(items);
        } else if (type == 'landmarks') {
          landmarks.addAll(items);
        } else if (type == 'page-list') {
          pageList.addAll(items);
        }
      }

      return TableOfContents(
        items: tocItems,
        landmarks: landmarks,
        pageList: pageList,
      );
    } catch (_) {
      return const TableOfContents();
    }
  }

  List<NavItem> _parseOlItems(XmlElement olElement, String navDocumentPath) {
    final result = <NavItem>[];
    for (final child in olElement.childElements) {
      if (child.name.local.toLowerCase() == 'li') {
        final a = XmlUtils.findDescendants(child, 'a').firstOrNull;
        final span = XmlUtils.findDescendants(child, 'span').firstOrNull;
        final title = a != null
            ? XmlUtils.getTextContent(a)
            : (span != null ? XmlUtils.getTextContent(span) : 'Untitled');
        final rawHref = a != null ? XmlUtils.getAttribute(a, 'href') : null;
        final resolvedHref =
            rawHref != null ? PathUtils.resolveHref(navDocumentPath, rawHref) : '';

        final nestedOl = XmlUtils.findDescendants(child, 'ol').firstOrNull;
        final children = nestedOl != null ? _parseOlItems(nestedOl, navDocumentPath) : <NavItem>[];

        result.add(NavItem(
          title: title,
          href: resolvedHref,
          children: children,
        ));
      }
    }
    return result;
  }

  /// Parses EPUB 2 toc.ncx
  TableOfContents _parseNcx(String ncxContent, String ncxDocumentPath) {
    try {
      final document = XmlDocument.parse(ncxContent);
      final navMap = XmlUtils.findDescendants(document.rootElement, 'navMap').firstOrNull;
      if (navMap == null) return const TableOfContents();

      final items = <NavItem>[];
      for (final child in navMap.childElements) {
        if (child.name.local.toLowerCase() == 'navpoint') {
          items.add(_parseNavPoint(child, ncxDocumentPath));
        }
      }

      return TableOfContents(items: items);
    } catch (_) {
      return const TableOfContents();
    }
  }

  NavItem _parseNavPoint(XmlElement navPoint, String ncxDocumentPath) {
    final navLabel = XmlUtils.findDescendants(navPoint, 'navLabel').firstOrNull;
    final textEl = navLabel != null ? XmlUtils.findDescendants(navLabel, 'text').firstOrNull : null;
    final title = textEl != null ? XmlUtils.getTextContent(textEl) : 'Untitled';

    final content = XmlUtils.findDescendants(navPoint, 'content').firstOrNull;
    final rawSrc = content != null ? XmlUtils.getAttribute(content, 'src') : null;
    final resolvedHref = rawSrc != null ? PathUtils.resolveHref(ncxDocumentPath, rawSrc) : '';

    final children = <NavItem>[];
    for (final child in navPoint.childElements) {
      if (child.name.local.toLowerCase() == 'navpoint') {
        children.add(_parseNavPoint(child, ncxDocumentPath));
      }
    }

    return NavItem(
      title: title,
      href: resolvedHref,
      children: children,
    );
  }
}
