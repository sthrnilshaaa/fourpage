/// Immutable domain model for a spine item in the publication reading order.
library;

class SpineItem {
  final String idref;
  final String href;
  final String mediaType;
  final bool linear;
  final List<String> properties;
  final int index;

  const SpineItem({
    required this.idref,
    required this.href,
    required this.mediaType,
    this.linear = true,
    this.properties = const [],
    required this.index,
  });

  Map<String, dynamic> toJson() => {
        'idref': idref,
        'href': href,
        'mediaType': mediaType,
        'linear': linear,
        'properties': properties,
        'index': index,
      };

  factory SpineItem.fromJson(Map<String, dynamic> json) => SpineItem(
        idref: json['idref'] as String,
        href: json['href'] as String,
        mediaType: json['mediaType'] as String,
        linear: json['linear'] as bool? ?? true,
        properties: List<String>.from(json['properties'] ?? const []),
        index: json['index'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpineItem &&
          runtimeType == other.runtimeType &&
          idref == other.idref &&
          href == other.href &&
          index == other.index;

  @override
  int get hashCode => idref.hashCode ^ href.hashCode ^ index.hashCode;
}
