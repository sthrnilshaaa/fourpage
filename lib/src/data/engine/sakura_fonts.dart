/// Bridges sakura_epub's bundled reader fonts (packaged as native Flutter
/// fonts) into the WebView-rendered book content, which can't see Flutter's
/// font registry and needs the raw font bytes injected as base64.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class SakuraFontOption {
  final String displayName;
  final String flutterFontFamily;
  final String _assetPath;

  const SakuraFontOption(this.displayName, this.flutterFontFamily, this._assetPath);

  /// MIME type for the injected @font-face.
  String get mimeType => _assetPath.endsWith('.otf') ? 'font/opentype' : 'font/truetype';
}

/// A curated subset of sakura_epub's bundled fonts, spanning serif/sans,
/// covering the same kind of choice the pure-Flutter reader offers. Only
/// freely licensed fonts are published in this repository.
class SakuraFonts {
  SakuraFonts._();

  /// The fonts are declared in sakura_epub's own pubspec, so Flutter-side
  /// previews must pass this as TextStyle.package to resolve them.
  static const String package = 'sakura_epub';

  static const literata = SakuraFontOption('Literata', 'Literata', 'lib/assets/fonts/Literata-Var.ttf');
  static const lora = SakuraFontOption('Lora', 'Lora', 'lib/assets/fonts/Lora-Var.ttf');
  static const sourceSerif = SakuraFontOption(
    'Source Serif',
    'Source Serif 4',
    'lib/assets/fonts/SourceSerif4-Var.ttf',
  );
  static const atkinsonHyperlegible = SakuraFontOption(
    'Atkinson Hyperlegible',
    'Atkinson Hyperlegible',
    'lib/assets/fonts/AtkinsonHyperlegible-Regular.ttf',
  );
  static const ibmPlexSans = SakuraFontOption(
    'IBM Plex Sans',
    'IBM Plex Sans',
    'lib/assets/fonts/IBMPlexSans-Regular.ttf',
  );

  static const List<SakuraFontOption> options = [literata, lora, sourceSerif, atkinsonHyperlegible, ibmPlexSans];

  static SakuraFontOption byFamily(String flutterFontFamily) =>
      options.firstWhere((f) => f.flutterFontFamily == flutterFontFamily, orElse: () => literata);

  static final Map<String, String> _base64Cache = {};

  /// Loads and base64-encodes a bundled font's bytes, so it can be injected
  /// into the WebView via EpubController.setFontFamily. Cached after first load.
  static Future<String> base64For(SakuraFontOption font) async {
    final cached = _base64Cache[font.flutterFontFamily];
    if (cached != null) return cached;

    final bytes = await rootBundle.load('packages/sakura_epub/${font._assetPath}');
    final encoded = base64Encode(bytes.buffer.asUint8List());
    _base64Cache[font.flutterFontFamily] = encoded;
    return encoded;
  }
}
