/// Immutable metadata structure for an EPUB publication.
library;

import 'accessibility_metadata.dart';
import 'collection_info.dart';
import 'contributor.dart';

class PublicationMetadata {
  final String title;
  final List<String> authors;
  final List<Contributor> contributors;
  final String? publisher;
  final String? language;
  final String identifier;
  final List<String> identifiers;
  final String? publicationDate;
  final String? description;
  final String? coverHref;
  final String? rights;
  final List<String> subjects;
  final List<CollectionInfo> collections;
  final AccessibilityMetadata accessibility;

  const PublicationMetadata({
    required this.title,
    this.authors = const [],
    this.contributors = const [],
    this.publisher,
    this.language,
    required this.identifier,
    this.identifiers = const [],
    this.publicationDate,
    this.description,
    this.coverHref,
    this.rights,
    this.subjects = const [],
    this.collections = const [],
    this.accessibility = const AccessibilityMetadata(),
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'authors': authors,
        'contributors': contributors.map((c) => c.toJson()).toList(),
        'publisher': publisher,
        'language': language,
        'identifier': identifier,
        'identifiers': identifiers,
        'publicationDate': publicationDate,
        'description': description,
        'coverHref': coverHref,
        'rights': rights,
        'subjects': subjects,
        'collections': collections.map((c) => c.toJson()).toList(),
        'accessibility': accessibility.toJson(),
      };

  factory PublicationMetadata.fromJson(Map<String, dynamic> json) => PublicationMetadata(
        title: json['title'] as String,
        authors: List<String>.from(json['authors'] ?? const []),
        contributors: (json['contributors'] as List<dynamic>?)
                ?.map((c) => Contributor.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
        publisher: json['publisher'] as String?,
        language: json['language'] as String?,
        identifier: json['identifier'] as String,
        identifiers: List<String>.from(json['identifiers'] ?? const []),
        publicationDate: json['publicationDate'] as String?,
        description: json['description'] as String?,
        coverHref: json['coverHref'] as String?,
        rights: json['rights'] as String?,
        subjects: List<String>.from(json['subjects'] ?? const []),
        collections: (json['collections'] as List<dynamic>?)
                ?.map((c) => CollectionInfo.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
        accessibility: json['accessibility'] != null
            ? AccessibilityMetadata.fromJson(json['accessibility'] as Map<String, dynamic>)
            : const AccessibilityMetadata(),
      );
}
