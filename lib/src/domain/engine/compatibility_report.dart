/// Domain model for EPUB multi-engine compatibility scoring and diagnostic reports.
library;

enum EPUBVersion { epub2, epub3, unknown }
enum LayoutType { reflowable, fixedLayout }
enum ProtectionType { unprotected, readiumLcp, unsupportedDrm }

class EngineScore {
  final String engineName;
  final double parsingScore;      // 0-100
  final double renderingScore;    // 0-100
  final double navigationScore;   // 0-100
  final double typographyScore;   // 0-100
  final double performanceScore;  // 0-100

  const EngineScore({
    required this.engineName,
    required this.parsingScore,
    required this.renderingScore,
    required this.navigationScore,
    required this.typographyScore,
    required this.performanceScore,
  });

  /// Weighted overall compatibility score out of 100.0.
  double get overallScore =>
      (parsingScore * 0.15) +
      (renderingScore * 0.30) +
      (navigationScore * 0.20) +
      (typographyScore * 0.15) +
      (performanceScore * 0.20);
}

class CompatibilityReport {
  final String publicationId;
  final String title;
  final EPUBVersion version;
  final LayoutType layout;
  final ProtectionType protection;
  final bool hasEmbeddedFonts;
  final bool hasRtlText;
  final List<EngineScore> engineScores;
  final String recommendedEngine;
  final List<String> warnings;

  const CompatibilityReport({
    required this.publicationId,
    required this.title,
    required this.version,
    required this.layout,
    required this.protection,
    required this.hasEmbeddedFonts,
    required this.hasRtlText,
    required this.engineScores,
    required this.recommendedEngine,
    required this.warnings,
  });

  Map<String, dynamic> toJson() => {
        'publicationId': publicationId,
        'title': title,
        'version': version.name,
        'layout': layout.name,
        'protection': protection.name,
        'hasEmbeddedFonts': hasEmbeddedFonts,
        'hasRtlText': hasRtlText,
        'recommendedEngine': recommendedEngine,
        'warnings': warnings,
        'overallScore': engineScores.isNotEmpty
            ? engineScores.firstWhere((e) => e.engineName == recommendedEngine, orElse: () => engineScores.first).overallScore
            : 0.0,
      };
}
