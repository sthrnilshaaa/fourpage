/// Full-text search service executing background text extraction across spine resources.
library;

import 'dart:async';
import '../../domain/entities/locator.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/search_match.dart';
import '../../domain/services/i_resource_resolver.dart';
import '../../domain/services/i_search_service.dart';

class EpubSearchService implements ISearchService {
  EpubSearchService();

  @override
  Future<List<SearchMatch>> search({
    required Publication publication,
    required IResourceResolver resolver,
    required String query,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];

    final matches = <SearchMatch>[];
    final totalSpineCount = publication.spine.length;

    for (var i = 0; i < totalSpineCount; i++) {
      final item = publication.spine[i];
      if (!resolver.hasResource(item.href)) continue;

      try {
        final htmlContent = await resolver.fetchResourceText(item.href);
        final plainText = _stripHtmlTags(htmlContent);
        if (plainText.isEmpty) continue;

        final lowerText = plainText.toLowerCase();
        var startIndex = 0;

        while (true) {
          final foundIndex = lowerText.indexOf(cleanQuery, startIndex);
          if (foundIndex == -1) break;

          final matchEndIndex = foundIndex + cleanQuery.length;
          final matchedText = plainText.substring(foundIndex, matchEndIndex);

          // Extract snippets
          final snippetStart = (foundIndex - 40).clamp(0, plainText.length);
          final snippetBefore = plainText.substring(snippetStart, foundIndex).replaceAll('\n', ' ');

          final snippetEnd = (matchEndIndex + 40).clamp(0, plainText.length);
          final snippetAfter = plainText.substring(matchEndIndex, snippetEnd).replaceAll('\n', ' ');

          // Progression calculation
          final itemProgression = plainText.isNotEmpty ? foundIndex / plainText.length : 0.0;
          final totalProgression = totalSpineCount > 0 ? (i + itemProgression) / totalSpineCount : 0.0;

          final locator = Locator(
            href: item.href,
            type: item.mediaType,
            title: publication.metadata.title,
            locations: LocationParameters(
              progression: itemProgression,
              position: i,
              totalProgression: totalProgression,
            ),
            text: TextContext(
              before: snippetBefore,
              highlight: matchedText,
              after: snippetAfter,
            ),
          );

          matches.add(SearchMatch(
            locator: locator,
            matchedText: matchedText,
            snippetBefore: snippetBefore,
            snippetAfter: snippetAfter,
            spineIndex: i,
          ));

          startIndex = matchEndIndex;
        }
      } catch (_) {
        // Continue searching remaining items on individual resource read failure
        continue;
      }
    }

    return matches;
  }

  /// Strips HTML tags and collapses whitespace cleanly.
  String _stripHtmlTags(String html) {
    // Replace script/style tags with spaces first
    final noScripts = html.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), ' ');
    // Strip XML/HTML tags
    final noTags = noScripts.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Unescape common HTML entities
    final unescaped = noTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // Collapse excess whitespace
    return unescaped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
