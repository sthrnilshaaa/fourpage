/// Collection & Series Information for EPUB publications.
library;

class CollectionInfo {
  final String name;
  final String? type; // series, set, etc.
  final double? position;

  const CollectionInfo({
    required this.name,
    this.type,
    this.position,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'position': position,
      };

  factory CollectionInfo.fromJson(Map<String, dynamic> json) => CollectionInfo(
        name: json['name'] as String,
        type: json['type'] as String?,
        position: (json['position'] as num?)?.toDouble(),
      );
}
