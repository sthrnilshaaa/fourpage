/// Multi-Engine EPUB Compatibility Harness evaluating and scoring publications across engines.
library;

import '../../domain/engine/compatibility_report.dart';
import '../parsers/epub_parser.dart';

class EpubCompatibilityHarness {
  final EpubPublicationParser _parser;

  EpubCompatibilityHarness({EpubPublicationParser? parser})
      : _parser = parser ?? EpubPublicationParser();

  /// Evaluates an EPUB ZIP archive and generates a compatibility diagnostic report.
  Future<CompatibilityReport> evaluatePublication(List<int> archiveBytes) async {
    final pub = await _parser.parsePublication(archiveBytes);
    final warnings = <String>[];

    // 1. Detect EPUB Version & Navigation
    final isEpub3 = pub.tableOfContents.items.any((i) => i.href.endsWith('.xhtml') || i.href.endsWith('.html'));
    final version = isEpub3 ? EPUBVersion.epub3 : EPUBVersion.epub2;

    if (!isEpub3) {
      warnings.add('Legacy EPUB 2 NCX navigation detected. Recommended fallback to NavigationParser.');
    }

    // 2. Detect Layout Type (Reflow vs Fixed Layout)
    final isFixedLayout = pub.resources.any((r) => r.properties.contains('fixed-layout'));
    final layout = isFixedLayout ? LayoutType.fixedLayout : LayoutType.reflowable;

    // 3. Detect Embedded Fonts & RTL Text
    final hasEmbeddedFonts = pub.resources.any(
      (r) => r.mediaType.contains('font') || r.href.endsWith('.ttf') || r.href.endsWith('.otf') || r.href.endsWith('.woff'),
    );

    final hasRtlText = pub.metadata.language != null &&
        (pub.metadata.language!.startsWith('ar') || pub.metadata.language!.startsWith('he') || pub.metadata.language!.startsWith('fa'));

    // 4. Protection & DRM Status
    final ProtectionType protection;
    if (pub.contentProtectionScheme == null) {
      protection = ProtectionType.unprotected;
    } else if (pub.contentProtectionScheme == 'http://readium.org/2014/lcp') {
      protection = ProtectionType.readiumLcp;
    } else {
      protection = ProtectionType.unsupportedDrm;
      warnings.add('Unsupported DRM scheme "${pub.contentProtectionScheme}" detected.');
    }

    // 5. Compute Multi-Engine Compatibility Scores
    final flutterEngineScore = EngineScore(
      engineName: 'PureFlutterEngine',
      parsingScore: 98.0,
      renderingScore: isFixedLayout ? 75.0 : 95.0,
      navigationScore: 92.0,
      typographyScore: hasEmbeddedFonts ? 88.0 : 96.0,
      performanceScore: 95.0,
    );

    final webViewEngineScore = EngineScore(
      engineName: 'WebViewEpubJsEngine',
      parsingScore: 95.0,
      renderingScore: isFixedLayout ? 92.0 : 96.0,
      navigationScore: 95.0,
      typographyScore: 94.0,
      performanceScore: 88.0,
    );

    final readiumEngineScore = EngineScore(
      engineName: 'NativeReadiumEngine',
      parsingScore: 99.0,
      renderingScore: 98.0,
      navigationScore: 98.0,
      typographyScore: 96.0,
      performanceScore: 98.0,
    );

    final scores = [flutterEngineScore, webViewEngineScore, readiumEngineScore];

    // Select highest scoring recommended engine
    scores.sort((a, b) => b.overallScore.compareTo(a.overallScore));
    final recommended = scores.first.engineName;

    return CompatibilityReport(
      publicationId: pub.id,
      title: pub.metadata.title,
      version: version,
      layout: layout,
      protection: protection,
      hasEmbeddedFonts: hasEmbeddedFonts,
      hasRtlText: hasRtlText,
      engineScores: scores,
      recommendedEngine: recommended,
      warnings: warnings,
    );
  }
}
