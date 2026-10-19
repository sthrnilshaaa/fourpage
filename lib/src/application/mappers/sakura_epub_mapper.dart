/// Bridges sakura_epub's own well-typed models (EpubLocation, EpubChapter, ...)
/// onto this app's domain entities (Locator, NavItem, ...), so the rest of the
/// app - persistence, annotations, bookmarks, progress - stays engine-agnostic
/// and never has to know sakura_epub exists.
library;

import 'package:flutter/material.dart';
import 'package:sakura_epub/sakura_epub.dart';

import '../../domain/entities/locator.dart';
import '../../domain/entities/nav_item.dart';
import '../../domain/entities/reader_preferences.dart';

class SakuraEpubMapper {
  SakuraEpubMapper._();

  /// EpubLocation only carries CFIs + progress (no href/spine index like the
  /// pure-Flutter engine's locators), so the CFI is stored in
  /// LocationParameters.cfi - the field the app's own Locator model already
  /// reserves for exactly this.
  /// [progress] overrides the location's own (0 until epub.js has counted
  /// the book's locations).
  static Locator locatorFromLocation(EpubLocation location, {String? title, double? progress}) {
    final p = progress ?? location.progress;
    return Locator(
      href: location.startCfi,
      title: title,
      locations: LocationParameters(
        progression: p,
        totalProgression: p,
        cfi: location.startCfi,
      ),
    );
  }

  static NavItem navItemFromChapter(EpubChapter chapter) => NavItem(
        title: chapter.title.replaceAll('\n', '').trim(),
        href: chapter.href,
        children: chapter.subitems.map(navItemFromChapter).toList(),
      );

  static List<NavItem> navItemsFromChapters(List<EpubChapter> chapters) =>
      chapters.map(navItemFromChapter).toList();

  /// Maps the app's cross-engine ReaderTheme onto sakura_epub's own theme
  /// model, so a single ReaderPreferences drives both rendering engines.
  ///
  /// Colours match the Figma "Screen mode" swatches (cream, black, the
  /// reader's own #121211, beige) so the swatch you tap is the page you get.
  /// [textAlignment]/[lineHeight] ride along as custom CSS on paragraphs -
  /// epub.js has no dedicated API for them, but its theme rules apply them.
  static EpubTheme themeFor(ReaderTheme theme, {String? textAlignment, double? lineHeight}) {
    final css = <String, dynamic>{
      if (textAlignment != null || lineHeight != null)
        'body': {
          if (textAlignment != null) 'text-align': textAlignment,
          if (lineHeight != null) 'line-height': '$lineHeight',
        },
      if (lineHeight != null)
        'p': {
          'line-height': '$lineHeight',
        },
    };
    EpubTheme custom(Color background, Color foreground) => EpubTheme.custom(
          backgroundDecoration: BoxDecoration(color: background),
          foregroundColor: foreground,
          customCss: css.isEmpty ? null : css,
        );
    return custom(pageColorFor(theme), textColorFor(theme));
  }

  /// Page background per theme - also used by the reader screen so the area
  /// around the WebView (while the controls inset it) matches the page.
  static Color pageColorFor(ReaderTheme theme) => switch (theme) {
        ReaderTheme.light => const Color(0xFFFFFCEF),
        ReaderTheme.sepia => const Color(0xFFC2BAA5),
        ReaderTheme.highContrast => Colors.black,
        ReaderTheme.publisher => const Color(0xFF121A15),
        ReaderTheme.dark => const Color(0xFF121211),
      };

  static String hexPageColorFor(ReaderTheme theme) {
    final color = pageColorFor(theme);
    final r = (color.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  static Color textColorFor(ReaderTheme theme) => switch (theme) {
        ReaderTheme.light => const Color(0xFF1A1A1A),
        ReaderTheme.sepia => const Color(0xFF2B2620),
        _ => Colors.white,
      };

  static EpubTheme themeForPreferences(ReaderPreferences prefs) =>
      themeFor(prefs.theme, textAlignment: prefs.textAlignment, lineHeight: prefs.lineHeight);

  /// [spread]: two pages side by side (wide book area, paginated only).
  static EpubDisplaySettings displaySettingsFor(ReaderPreferences prefs, {bool spread = false}) {
    return EpubDisplaySettings(
      spread: spread ? EpubSpread.always : EpubSpread.none,
      fontSize: prefs.fontSize.round(),
      flow: prefs.scrollMode == ScrollMode.continuous ? EpubFlow.scrolled : EpubFlow.paginated,
      theme: themeForPreferences(prefs),
      // No epub.js snapper: SakuraReadingBehavior turns pages itself. With
      // both active one swipe moved the page twice and could leave a
      // half-rendered chapter that froze the render queue. The native
      // WebView's vertical scroll is synced by the reader screen instead.
      snap: false,
      useSnapAnimationAndroid: true,
    );
  }
}
