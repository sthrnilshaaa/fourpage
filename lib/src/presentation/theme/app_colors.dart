import 'package:flutter/material.dart';

import 'app_theme_controller.dart';

/// App colour tokens. Each token has a dark value (the original design) and a
/// light counterpart; the active one follows [AppThemeController]. Tokens are
/// getters, so they can't be used inside `const` expressions.
///
/// Book page colours (`reader*`) are the *book* themes chosen in the reader,
/// independent of the app theme, so they stay constant.
class AppColors {
  AppColors._();

  static bool get _light => AppThemeController.instance.isLight;
  static Color _pick(Color dark, Color light) => _light ? light : dark;

  // Foreground: text/icons/hairlines drawn on app surfaces. Use these instead
  // of Colors.white/whiteNN in chrome so light mode inverts correctly.
  static Color get fg => _pick(Colors.white, const Color(0xFF15171C));
  static Color get fgMuted => fg.withValues(alpha: 0.70);
  static Color get fgSubtle => fg.withValues(alpha: 0.54);
  static Color get fgFaint => fg.withValues(alpha: 0.38);
  static Color get fgHairline => fg.withValues(alpha: 0.12);

  // Primary Backgrounds
  static Color get darkBackground => _pick(const Color(0xFF0A0B0E), const Color(0xFFF6F6F3));
  static Color get surfaceDark => _pick(const Color(0xFF14171F), const Color(0xFFFFFFFF));
  static Color get cardDark => _pick(const Color(0xFF1B1E28), const Color(0xFFEEEEEA));
  static Color get borderDark => _pick(const Color(0xFF282C3A), const Color(0xFFDADAD5));

  // Reader Chrome Surfaces (bottom sheets, floating popups/pills, dividers)
  static Color get sheetSurface => _pick(const Color(0xFF141413), const Color(0xFFFFFFFF));
  static Color get popoverSurface => _pick(const Color(0xFF191C24), const Color(0xFFFFFFFF));
  static Color get pillSurface => _pick(const Color(0xFF17191E), const Color(0xFFF1F1EE));
  static Color get dividerSubtle => _pick(const Color(0xFF22252E), const Color(0xFFE3E3DF));
  static Color get textFaint => _pick(const Color(0xFF8E95A5), const Color(0xFF6B7180));

  // Accent Colors. Lime reads on both; in light mode a deeper lime keeps
  // text/progress on white legible.
  static Color get accentLime => _pick(const Color(0xFFA3E635), const Color(0xFF5E9A0B));
  static Color get figmaLime => _pick(const Color(0xFFC6EF6F), const Color(0xFF6FA81A));

  // Figma screen tokens
  static Color get figmaBackground => _pick(const Color(0xFF0D0C0B), const Color(0xFFF6F6F3)); // Home/Library/Saved
  static Color get figmaReaderBackground => _pick(const Color(0xFF121211), const Color(0xFFFAFAF8)); // opened_book chrome
  static Color get figmaSurface => _pick(const Color(0xFF161616), const Color(0xFFFFFFFF)); // bars, pills, sheets
  static Color get figmaHeaderTop => _pick(const Color(0xFF151515), const Color(0xFFFFFFFF)); // header gradient start
  static Color get figmaDivider => fg.withValues(alpha: 0.05);
  static Color get figmaTrack => fg.withValues(alpha: 0.30);
  static Color get figmaTextMuted => fg.withValues(alpha: 0.50);
  static Color get figmaTextFaint => fg.withValues(alpha: 0.40);
  static Color get figmaTextGhost => fg.withValues(alpha: 0.20);
  static Color get accentLavender => _pick(const Color(0xFFB8C0FE), const Color(0xFF4F5BD5));
  static Color get accentBlue => _pick(const Color(0xFF38BDF8), const Color(0xFF0284C7));

  // Text Colors
  static Color get textPrimary => _pick(const Color(0xFFF8FAFC), const Color(0xFF15171C));
  static Color get textSecondary => _pick(const Color(0xFF94A3B8), const Color(0xFF4B5563));
  static Color get textMuted => _pick(const Color(0xFF64748B), const Color(0xFF6B7280));

  // Book page themes (reader content) - fixed, chosen per book.
  static const Color readerDark = Color(0xFF0A0B0E);
  static const Color readerLight = Color(0xFFFFFFFF);
  static const Color readerSepia = Color(0xFFF7F1E5);
  static const Color readerSepiaText = Color(0xFF3A2E2B);
  static const Color readerHighContrast = Color(0xFF000000);
}
