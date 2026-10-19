/// Immutable domain model for a publication manifest resource.
library;

class ManifestResource {
  final String href;
  final String mediaType;
  final List<String> properties;
  final int? length;
  final String? title;
  final String? fallbackHref;
  final bool isEncrypted;

  const ManifestResource({
    required this.href,
    required this.mediaType,
    this.properties = const [],
    this.length,
    this.title,
    this.fallbackHref,
    this.isEncrypted = false,
  });

  bool get isContentDocument =>
      mediaType == 'application/xhtml+xml' || mediaType == 'text/html';
  bool get isStylesheet => mediaType == 'text/css';
  bool get isImage => mediaType.startsWith('image/');
  bool get isFont =>
      mediaType.startsWith('font/') ||
      mediaType.contains('opentype') ||
      mediaType.contains('truetype') ||
      mediaType.contains('woff');
  bool get isAudio => mediaType.startsWith('audio/');
  bool get isVideo => mediaType.startsWith('video/');
  bool get isScript =>
      mediaType.contains('javascript') ||
      mediaType.contains('ecmascript') ||
      properties.contains('scripted');
  bool get isNavigation =>
      properties.contains('nav') || mediaType == 'application/x-dtbncx+xml';
  bool get isMediaOverlay => mediaType == 'application/smil+xml';
  bool get isMathML =>
      properties.contains('mathml') || mediaType == 'application/mathml+xml';
  bool get isSVG => mediaType == 'image/svg+xml' || properties.contains('svg');

  ManifestResource copyWith({
    String? href,
    String? mediaType,
    List<String>? properties,
    int? length,
    String? title,
    String? fallbackHref,
    bool? isEncrypted,
  }) {
    return ManifestResource(
      href: href ?? this.href,
      mediaType: mediaType ?? this.mediaType,
      properties: properties ?? this.properties,
      length: length ?? this.length,
      title: title ?? this.title,
      fallbackHref: fallbackHref ?? this.fallbackHref,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }

  Map<String, dynamic> toJson() => {
        'href': href,
        'mediaType': mediaType,
        'properties': properties,
        'length': length,
        'title': title,
        'fallbackHref': fallbackHref,
        'isEncrypted': isEncrypted,
      };

  factory ManifestResource.fromJson(Map<String, dynamic> json) => ManifestResource(
        href: json['href'] as String,
        mediaType: json['mediaType'] as String,
        properties: List<String>.from(json['properties'] ?? const []),
        length: json['length'] as int?,
        title: json['title'] as String?,
        fallbackHref: json['fallbackHref'] as String?,
        isEncrypted: json['isEncrypted'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManifestResource &&
          runtimeType == other.runtimeType &&
          href == other.href &&
          mediaType == other.mediaType;

  @override
  int get hashCode => href.hashCode ^ mediaType.hashCode;
}
