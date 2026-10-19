import '../../domain/entities/annotation.dart';
import '../../domain/entities/locator.dart';
import '../../presentation/native_reader/native_reader_engine.dart';

/// Native PageEngine positions <-> the app's [Locator]s.
///
/// New saves carry `href` + `charOffset` (exact). Positions saved by the old epub.js reader carry a
/// CFI; they open through the engine's CFI resolution, and keep working until the next save.
class NativeLocatorMapper {
  static Locator toLocator(NativeLocator l, {String? title}) => Locator(
        href: l.href,
        title: title,
        locations: LocationParameters(
          progression: l.progression,
          totalProgression: l.totalProgression,
          position: l.globalPage,
          charOffset: l.charOffset,
          cfi: l.cfi,
        ),
        text: TextContext(before: l.textBefore, after: l.textAfter),
      );

  /// A highlight/note range as a locator ([quote] is the selected text). The href carries the exact
  /// offset (`chapter.html#aread:<start>`) so lists that navigate by href land on the text.
  static Locator rangeLocator(String href, int start, int end, String quote, {String? cfi}) => Locator(
        href: '${href.split('#').first}#aread:$start',
        locations: LocationParameters(charOffset: start, charEnd: end, cfi: cfi),
        text: TextContext(highlight: quote),
      );

  static NativeStart startFor(Locator? locator) {
    if (locator == null) return const NativeStart.beginning();
    final loc = locator.locations;
    if (loc.charOffset != null && locator.href.isNotEmpty && !locator.href.startsWith('epubcfi(')) {
      return NativeStart.hrefChars(locator.href, loc.charOffset!);
    }
    final cfi = loc.cfi ?? (locator.href.startsWith('epubcfi(') ? locator.href : null);
    if (cfi != null) return NativeStart.legacy(cfi);
    if (locator.href.isNotEmpty) return NativeStart.href(locator.href);
    final total = loc.totalProgression ?? loc.progression;
    if (total != null) return NativeStart.progression(total);
    return const NativeStart.beginning();
  }

  /// The saved range of a native highlight/note; null for old CFI ones (resolve those via the engine).
  static ({String href, int start, int end})? rangeOf(Annotation a) {
    final loc = a.locator.locations;
    if (loc.charOffset == null || loc.charEnd == null || a.locator.href.startsWith('epubcfi(')) return null;
    return (href: a.locator.href.split('#').first, start: loc.charOffset!, end: loc.charEnd!);
  }

  /// '#FFEB3B' → 0xFFFFEB3B.
  static int colorOf(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xFFEB3B;
    return 0xFF000000 | (v & 0xFFFFFF);
  }
}
