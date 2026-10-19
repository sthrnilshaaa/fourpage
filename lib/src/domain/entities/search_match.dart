/// Domain representation of a full-text search match in the publication.
library;

import 'locator.dart';

class SearchMatch {
  final Locator locator;
  final String matchedText;
  final String snippetBefore;
  final String snippetAfter;
  final int spineIndex;

  const SearchMatch({
    required this.locator,
    required this.matchedText,
    required this.snippetBefore,
    required this.snippetAfter,
    required this.spineIndex,
  });

  Map<String, dynamic> toJson() => {
        'locator': locator.toJson(),
        'matchedText': matchedText,
        'snippetBefore': snippetBefore,
        'snippetAfter': snippetAfter,
        'spineIndex': spineIndex,
      };

  factory SearchMatch.fromJson(Map<String, dynamic> json) => SearchMatch(
        locator: Locator.fromJson(json['locator'] as Map<String, dynamic>),
        matchedText: json['matchedText'] as String,
        snippetBefore: json['snippetBefore'] as String,
        snippetAfter: json['snippetAfter'] as String,
        spineIndex: json['spineIndex'] as int,
      );
}
