/// Domain entity for user highlights, notes, and annotations.
library;

import 'locator.dart';

enum AnnotationType { highlight, note, bookmark }

class Annotation {
  final String id;
  final String publicationId;
  final Locator locator;
  final String? textQuote;
  final String? textPrefix;
  final String? textSuffix;
  final String? note;
  final String colorHex;
  final AnnotationType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Annotation({
    required this.id,
    required this.publicationId,
    required this.locator,
    this.textQuote,
    this.textPrefix,
    this.textSuffix,
    this.note,
    this.colorHex = '#FFD54F',
    this.type = AnnotationType.highlight,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'publicationId': publicationId,
        'locator': locator.toJson(),
        'textQuote': textQuote,
        'textPrefix': textPrefix,
        'textSuffix': textSuffix,
        'note': note,
        'colorHex': colorHex,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: json['id'] as String,
        publicationId: json['publicationId'] as String,
        locator: Locator.fromJson(json['locator'] as Map<String, dynamic>),
        textQuote: json['textQuote'] as String?,
        textPrefix: json['textPrefix'] as String?,
        textSuffix: json['textSuffix'] as String?,
        note: json['note'] as String?,
        colorHex: json['colorHex'] as String? ?? '#FFD54F',
        type: AnnotationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => AnnotationType.highlight,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
