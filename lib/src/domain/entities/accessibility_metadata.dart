/// Accessibility Information for EPUB publications.
library;

class AccessibilityMetadata {
  final List<String> features;
  final List<String> hazards;
  final String? summary;
  final List<String> accessModes;
  final List<String> sufficientAccessModes;
  final String? conformance;

  const AccessibilityMetadata({
    this.features = const [],
    this.hazards = const [],
    this.summary,
    this.accessModes = const [],
    this.sufficientAccessModes = const [],
    this.conformance,
  });

  bool get hasAlternativeText => features.contains('alternativeText');
  bool get hasStructuralNavigation => features.contains('structuralNavigation');

  Map<String, dynamic> toJson() => {
        'features': features,
        'hazards': hazards,
        'summary': summary,
        'accessModes': accessModes,
        'sufficientAccessModes': sufficientAccessModes,
        'conformance': conformance,
      };

  factory AccessibilityMetadata.fromJson(Map<String, dynamic> json) => AccessibilityMetadata(
        features: List<String>.from(json['features'] ?? const []),
        hazards: List<String>.from(json['hazards'] ?? const []),
        summary: json['summary'] as String?,
        accessModes: List<String>.from(json['accessModes'] ?? const []),
        sufficientAccessModes: List<String>.from(json['sufficientAccessModes'] ?? const []),
        conformance: json['conformance'] as String?,
      );
}
