/// Domain model for persistent reading progress tracking.
library;

import 'locator.dart';

class ReadingProgress {
  final String publicationId;
  final Locator locator;
  final double percentage; // 0.0 to 100.0
  final DateTime lastReadAt;

  const ReadingProgress({
    required this.publicationId,
    required this.locator,
    required this.percentage,
    required this.lastReadAt,
  });

  Map<String, dynamic> toJson() => {
        'publicationId': publicationId,
        'locator': locator.toJson(),
        'percentage': percentage,
        'lastReadAt': lastReadAt.toIso8601String(),
      };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) => ReadingProgress(
        publicationId: json['publicationId'] as String,
        locator: Locator.fromJson(json['locator'] as Map<String, dynamic>),
        percentage: (json['percentage'] as num).toDouble(),
        lastReadAt: DateTime.parse(json['lastReadAt'] as String),
      );
}
