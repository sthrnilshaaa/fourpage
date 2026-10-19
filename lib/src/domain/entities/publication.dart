/// Master Publication domain entity representing an parsed EPUB 2/3 publication.
library;

import 'derived_statistics.dart';
import 'manifest_resource.dart';
import 'publication_metadata.dart';
import 'rendition_information.dart';
import 'spine_item.dart';
import 'table_of_contents.dart';

class Publication {
  final String id;
  final String fingerprint;
  final PublicationMetadata metadata;
  final List<ManifestResource> resources;
  final List<SpineItem> spine;
  final TableOfContents tableOfContents;
  final String packagePath;
  final String? contentProtectionScheme;
  final RenditionInformation rendition;
  final DerivedStatistics derivedStatistics;

  const Publication({
    required this.id,
    required this.fingerprint,
    required this.metadata,
    this.resources = const [],
    this.spine = const [],
    this.tableOfContents = const TableOfContents(),
    required this.packagePath,
    this.contentProtectionScheme,
    this.rendition = const RenditionInformation(),
    this.derivedStatistics = const DerivedStatistics(),
  });

  bool get isProtected => contentProtectionScheme != null && contentProtectionScheme!.isNotEmpty;

  /// Looks up a manifest resource by its href string (normalized).
  ManifestResource? getResource(String href) {
    final cleanHref = href.split('#')[0];
    for (final r in resources) {
      if (r.href == cleanHref) return r;
    }
    return null;
  }

  /// Gets the cover resource if available in the manifest.
  ManifestResource? get coverResource {
    if (metadata.coverHref != null) {
      final res = getResource(metadata.coverHref!);
      if (res != null) return res;
    }
    for (final r in resources) {
      if (r.properties.contains('cover-image')) {
        return r;
      }
    }
    return null;
  }

  /// Locates the spine item by spine index.
  SpineItem? getSpineItemAt(int index) {
    if (index >= 0 && index < spine.length) {
      return spine[index];
    }
    return null;
  }

  /// Finds spine item index by href.
  int findSpineIndex(String href) {
    final cleanHref = href.split('#')[0];
    for (var i = 0; i < spine.length; i++) {
      if (spine[i].href == cleanHref) {
        return i;
      }
    }
    return -1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fingerprint': fingerprint,
        'metadata': metadata.toJson(),
        'resources': resources.map((r) => r.toJson()).toList(),
        'spine': spine.map((s) => s.toJson()).toList(),
        'tableOfContents': tableOfContents.toJson(),
        'packagePath': packagePath,
        'contentProtectionScheme': contentProtectionScheme,
        'rendition': rendition.toJson(),
        'derivedStatistics': derivedStatistics.toJson(),
      };

  factory Publication.fromJson(Map<String, dynamic> json) => Publication(
        id: json['id'] as String,
        fingerprint: json['fingerprint'] as String,
        metadata: PublicationMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
        resources: (json['resources'] as List<dynamic>?)
                ?.map((r) => ManifestResource.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
        spine: (json['spine'] as List<dynamic>?)
                ?.map((s) => SpineItem.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        tableOfContents: json['tableOfContents'] != null
            ? TableOfContents.fromJson(json['tableOfContents'] as Map<String, dynamic>)
            : const TableOfContents(),
        packagePath: json['packagePath'] as String,
        contentProtectionScheme: json['contentProtectionScheme'] as String?,
        rendition: json['rendition'] != null
            ? RenditionInformation.fromJson(json['rendition'] as Map<String, dynamic>)
            : const RenditionInformation(),
        derivedStatistics: json['derivedStatistics'] != null
            ? DerivedStatistics.fromJson(json['derivedStatistics'] as Map<String, dynamic>)
            : const DerivedStatistics(),
      );
}
