/// Domain entity for user bookmarks.
library;

import 'locator.dart';

class Bookmark {
  final String id;
  final String publicationId;
  final Locator locator;
  final String title;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.publicationId,
    required this.locator,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'publicationId': publicationId,
        'locator': locator.toJson(),
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        publicationId: json['publicationId'] as String,
        locator: Locator.fromJson(json['locator'] as Map<String, dynamic>),
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
