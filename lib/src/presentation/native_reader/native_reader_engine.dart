import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/mappers/sakura_epub_mapper.dart';
import '../../data/engine/sakura_fonts.dart';
import '../../domain/entities/nav_item.dart';
import '../../domain/entities/reader_preferences.dart';
import '../state/app_preferences.dart';

/// A page of the book: chapter (spine item) index + page within it.
@immutable
class NativePage {
  final int resourceIndex;
  final int page;
  const NativePage(this.resourceIndex, this.page);

  Map<String, int> toMap() => {'r': resourceIndex, 'p': page};
  static NativePage fromMap(Map m) => NativePage((m['r'] as num).toInt(), (m['p'] as num).toInt());

  @override
  bool operator ==(Object other) => other is NativePage && other.resourceIndex == resourceIndex && other.page == page;
  @override
  int get hashCode => Object.hash(resourceIndex, page);
  @override
  String toString() => 'NativePage($resourceIndex, $page)';
}

/// Where to open: an exact chapter offset, an href, or a whole-book progression.
class NativeStart {
  final int? resourceIndex;
  final int? offset;
  final String? href;
  final double? progression;
  final String? cfi;
  const NativeStart.chars(int this.resourceIndex, int this.offset) : href = null, progression = null, cfi = null;
  const NativeStart.href(String this.href) : resourceIndex = null, offset = null, progression = null, cfi = null;
  const NativeStart.hrefChars(String this.href, int this.offset) : resourceIndex = null, progression = null, cfi = null;
  const NativeStart.progression(double this.progression) : resourceIndex = null, offset = null, href = null, cfi = null;
  /// A position saved by the old epub.js reader.
  const NativeStart.legacy(String this.cfi) : resourceIndex = null, offset = null, href = null, progression = null;
  const NativeStart.beginning() : resourceIndex = null, offset = null, href = null, progression = null, cfi = null;

  Map<String, Object?> toMap() => {
        if (cfi != null) 'cfi': cfi,
        if (resourceIndex != null) 'r': resourceIndex,
        if (offset != null) 'offset': offset,
        if (href != null) 'href': href,
        if (progression != null) 'progression': progression,
      };

  @override
  bool operator ==(Object other) => other is NativeStart && _key == other._key;
  @override
  int get hashCode => _key.hashCode;
  String get _key => toMap().toString();
  @override
  String toString() => 'NativeStart(${toMap()})';
}

class NativeLocator {
  final String href;
  final int resourceIndex;
  final int charOffset;
  final double progression;
  final double totalProgression;
  final int? globalPage;
  final int? pagesLeft;
  final String textBefore;
  final String textAfter;
  /// The same place as an epub.js CFI, for the original-layout reader.
  final String? cfi;
  const NativeLocator({
    required this.href,
    required this.resourceIndex,
    required this.charOffset,
    required this.progression,
    required this.totalProgression,
    this.globalPage,
    this.pagesLeft,
    this.textBefore = '',
    this.textAfter = '',
    this.cfi,
  });

  static NativeLocator fromMap(Map m) => NativeLocator(
        href: m['href'] as String,
        resourceIndex: (m['r'] as num).toInt(),
        charOffset: (m['charOffset'] as num).toInt(),
        progression: (m['progression'] as num).toDouble(),
        totalProgression: (m['totalProgression'] as num).toDouble(),
        globalPage: (m['globalPage'] as num?)?.toInt(),
        pagesLeft: (m['pagesLeft'] as num?)?.toInt(),
        textBefore: m['textBefore'] as String? ?? '',
        textAfter: m['textAfter'] as String? ?? '',
        cfi: m['cfi'] as String?,
      );
}

class NativeSelection {
  final int resourceIndex;
  final int start;
  final int end;
  final String text;
  /// The chapter's href (where a highlight of this selection is saved).
  final String href;
  /// Page-pixel rects, one per line.
  final List<Rect> rects;
  const NativeSelection(this.resourceIndex, this.start, this.end, this.text, this.rects, {this.href = ''});

  Rect get bounds => rects.isEmpty ? Rect.zero : rects.reduce((a, b) => a.expandToInclude(b));

  static NativeSelection fromMap(Map m) {
    final flat = (m['rects'] as List).map((e) => (e as num).toDouble()).toList();
    return NativeSelection(
      (m['r'] as num).toInt(),
      (m['start'] as num).toInt(),
      (m['end'] as num).toInt(),
      m['text'] as String,
      [for (var i = 0; i + 3 < flat.length; i += 4) Rect.fromLTRB(flat[i], flat[i + 1], flat[i + 2], flat[i + 3])],
      href: m['href'] as String? ?? '',
    );
  }
}

class NativeSearchHit {
  final int resourceIndex;
  final int start;
  final int end;
  final String snippet;
  final String href;
  const NativeSearchHit(this.resourceIndex, this.start, this.end, this.snippet, this.href);
}

class NativeChapterInfo {
  final ({String title, String href})? prev;
  final ({String title, String href})? current;
  final ({String title, String href})? next;
  const NativeChapterInfo(this.prev, this.current, this.next);

  /// The shape the reader screen's zoomed view reads ({prev|current|next: {title, href}}).
  Map<String, dynamic> toScreenMap() => {
        if (prev != null) 'prev': {'title': prev!.title, 'href': prev!.href},
        if (current != null) 'current': {'title': current!.title, 'href': current!.href},
        if (next != null) 'next': {'title': next!.title, 'href': next!.href},
      };
}

class NativePageIndex {
  final int total;
  final List<int> counts;
  const NativePageIndex(this.total, this.counts);
}

/// A highlight to draw: chapter given by [resourceIndex] or, for saved ones, by [href].
class NativeHighlight {
  final String id;
  final int? resourceIndex;
  final String? href;
  final int start;
  final int end;
  final int color;
  const NativeHighlight(this.id, {this.resourceIndex, this.href, required this.start, required this.end, required this.color});
  Map<String, Object?> toMap() => {
        'id': id,
        if (resourceIndex != null) 'r': resourceIndex,
        if (href != null) 'href': href,
        'start': start,
        'end': end,
        'color': color,
      };
}

/// Reader settings sent to the engine.
class NativePrefs {
  final String? fontPath;
  final String fontKey;
  final double fontSize;
  final double lineHeight;
  final String textAlign;
  final bool publisherStyles;
  final int pageColor;
  final int textColor;
  final double padding;
  const NativePrefs({
    required this.fontPath,
    required this.fontKey,
    required this.fontSize,
    required this.lineHeight,
    required this.textAlign,
    required this.publisherStyles,
    required this.pageColor,
    required this.textColor,
    required this.padding,
  });

  Map<String, Object?> toMap() => {
        'fontPath': fontPath,
        'fontKey': fontKey,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'textAlign': textAlign,
        'publisherStyles': publisherStyles,
        'pageColor': pageColor,
        'textColor': textColor,
        'padding': padding,
      };

  /// From the book's [ReaderPreferences] and the app's page margin. The font is written to a file
  /// once so the engine can load the same bundled font the WebView reader used.
  static Future<NativePrefs> from(ReaderPreferences prefs, {required double padding}) async {
    // "Dynamic book background" can override the book's own theme.
    prefs = prefs.copyWith(theme: AppPreferences.instance.effectiveReaderTheme(prefs.theme));
    final font = SakuraFonts.byFamily(prefs.fontFamily);
    return NativePrefs(
      fontPath: await NativeFonts.fileFor(font),
      fontKey: font.flutterFontFamily,
      fontSize: prefs.fontSize,
      lineHeight: prefs.lineHeight,
      textAlign: prefs.textAlignment,
      publisherStyles: prefs.theme == ReaderTheme.publisher,
      pageColor: SakuraEpubMapper.pageColorFor(prefs.theme).toARGB32(),
      textColor: SakuraEpubMapper.textColorFor(prefs.theme).toARGB32(),
      padding: padding,
    );
  }
}

/// Bundled reader fonts as files on disk (written once).
class NativeFonts {
  static final _paths = <String, Future<String?>>{};

  static Future<String?> fileFor(SakuraFontOption font) => _paths.putIfAbsent(font.flutterFontFamily, () async {
        try {
          final dir = Directory('${(await getApplicationSupportDirectory()).path}/reader_fonts');
          final file = File('${dir.path}/${font.flutterFontFamily.replaceAll(' ', '_')}.font');
          if (await file.exists() && await file.length() > 0) return file.path;
          await dir.create(recursive: true);
          await file.writeAsBytes(base64Decode(await SakuraFonts.base64For(font)), flush: true);
          return file.path;
        } catch (e) {
          debugPrint('NativeFonts: ${font.flutterFontFamily} unavailable: $e');
          return null;
        }
      });
}

/// Dart side of the native PageEngine (Android). One instance per open book.
class NativeReaderEngine {
  static const _channel = MethodChannel('fourpages/native_reader');
  static final _indexes = <int, StreamController<NativePageIndex>>{};
  static bool _listening = false;

  final int sessionId;
  final int chapterCount;
  final List<NavItem> toc;
  final NativePage firstPage;
  NativePageIndex? lastIndex;
  /// RendererPolicy: 'native' or 'original' (fixed layout, MathML, vertical, RTL), and why.
  final String renderer;
  final String rendererReason;

  NativeReaderEngine._(this.sessionId, this.chapterCount, this.toc, this.firstPage,
      {this.renderer = 'native', this.rendererReason = ''});

  Stream<NativePageIndex> get pageIndex => _indexes[sessionId]!.stream;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'pageIndex') return;
      final m = call.arguments as Map;
      final id = (m['sessionId'] as num).toInt();
      _indexes[id]?.add(NativePageIndex(
        (m['total'] as num).toInt(),
        (m['counts'] as List).map((e) => (e as num).toInt()).toList(),
      ));
    });
  }

  static Future<NativeReaderEngine> open({
    required String path,
    required NativePrefs prefs,
    required Size pagePx,
    required NativeStart start,
  }) async {
    _listen();
    final m = (await _channel.invokeMapMethod<String, dynamic>('open', {
      'path': path,
      'prefs': prefs.toMap(),
      'width': pagePx.width.round(),
      'height': pagePx.height.round(),
      'start': start.toMap(),
    }))!;
    final id = (m['sessionId'] as num).toInt();
    final controller = StreamController<NativePageIndex>.broadcast();
    _indexes[id] = controller;
    final engine = NativeReaderEngine._(
      id,
      (m['chapterCount'] as num).toInt(),
      [for (final e in (m['toc'] as List)) _navItem(e as Map)],
      NativePage.fromMap(m['page'] as Map),
      renderer: m['renderer'] as String? ?? 'native',
      rendererReason: m['rendererReason'] as String? ?? '',
    );
    controller.stream.listen((i) => engine.lastIndex = i);
    engine.lastIndex = _index(m['index']);
    return engine;
  }

  static NativePageIndex? _index(Object? v) => v is Map
      ? NativePageIndex((v['total'] as num).toInt(), (v['counts'] as List).map((e) => (e as num).toInt()).toList())
      : null;

  static NavItem _navItem(Map m) => NavItem(
        title: m['title'] as String,
        href: m['href'] as String,
        children: [for (final c in (m['children'] as List)) _navItem(c as Map)],
      );

  Future<T?> _call<T>(String method, [Map<String, Object?> args = const {}]) =>
      _channel.invokeMethod<T>(method, {'sessionId': sessionId, ...args});

  Future<NativePage?> step(NativePage from, int dir) async {
    final m = await _call<Map>('step', {'ref': from.toMap(), 'dir': dir});
    return m == null ? null : NativePage.fromMap(m);
  }

  Future<NativePage> locate(int globalPage) async => NativePage.fromMap((await _call<Map>('locate', {'globalPage': globalPage}))!);
  Future<NativePage> atProgression(double t) async => NativePage.fromMap((await _call<Map>('atProgression', {'t': t}))!);
  Future<NativePage> atHref(String href) async => NativePage.fromMap((await _call<Map>('atHref', {'href': href}))!);
  Future<NativePage> at(int resourceIndex, int offset) async =>
      NativePage.fromMap((await _call<Map>('at', {'r': resourceIndex, 'offset': offset}))!);

  Future<NativeLocator> locator(NativePage p) async => NativeLocator.fromMap((await _call<Map>('locator', {'ref': p.toMap()}))!);

  Future<NativeChapterInfo> chapterInfo(NativePage p) async {
    final m = (await _call<Map>('chapterInfo', {'ref': p.toMap()}))!;
    ({String title, String href})? e(Object? v) => v is Map ? (title: v['title'] as String, href: v['href'] as String) : null;
    return NativeChapterInfo(e(m['prev']), e(m['current']), e(m['next']));
  }

  Future<ui.Image> render(NativePage p, {double scale = 1}) async =>
      _image((await _call<Map>('render', {'ref': p.toMap(), 'scale': scale}))!);

  Future<List<int>> tiles(int resourceIndex) async =>
      ((await _call<List>('tiles', {'r': resourceIndex})) ?? const []).map((e) => (e as num).toInt()).toList();

  Future<ui.Image> renderTile(int resourceIndex, int tile) async =>
      _image((await _call<Map>('renderTile', {'r': resourceIndex, 'tile': tile}))!);

  /// Relayout keeping an exact place (chapter + char offset).
  Future<NativePage> setPrefsAt(NativePrefs prefs, Size pagePx, int resourceIndex, int offset) async {
    lastIndex = null; // the old layout's count no longer applies
    final m = (await _call<Map>('setPrefs', {
      'prefs': prefs.toMap(),
      'width': pagePx.width.round(),
      'height': pagePx.height.round(),
      'r': resourceIndex,
      'offset': offset,
    }))!;
    lastIndex = _index(m['index']) ?? lastIndex;
    return NativePage.fromMap(m);
  }

  Future<NativePage> setPrefs(NativePrefs prefs, Size pagePx, NativePage keep) async => NativePage.fromMap((await _call<Map>('setPrefs', {
        'prefs': prefs.toMap(),
        'width': pagePx.width.round(),
        'height': pagePx.height.round(),
        'ref': keep.toMap(),
      }))!);

  Future<List<NativeSearchHit>> search(String query) async => [
        for (final m in (await _call<List>('search', {'query': query})) ?? const [])
          NativeSearchHit(
            ((m as Map)['r'] as num).toInt(),
            (m['start'] as num).toInt(),
            (m['end'] as num).toInt(),
            m['snippet'] as String,
            m['href'] as String,
          ),
      ];

  Future<NativeSelection?> wordAt(NativePage p, Offset o) async {
    final m = await _call<Map>('wordAt', {'ref': p.toMap(), 'x': o.dx, 'y': o.dy});
    return m == null ? null : NativeSelection.fromMap(m);
  }

  Future<NativeSelection?> rangeBetween(NativePage p, Offset a, Offset b) async {
    final m = await _call<Map>('rangeBetween', {'ref': p.toMap(), 'x1': a.dx, 'y1': a.dy, 'x2': b.dx, 'y2': b.dy});
    return m == null ? null : NativeSelection.fromMap(m);
  }

  Future<String?> cfiRange(int resourceIndex, int start, int end) =>
      _call<String>('cfiRange', {'r': resourceIndex, 'start': start, 'end': end});

  Future<String> chapterHref(int resourceIndex) async => (await _call<String>('chapterHref', {'r': resourceIndex}))!;

  Future<String?> highlightAt(NativePage p, Offset o) => _call<String>('highlightAt', {'ref': p.toMap(), 'x': o.dx, 'y': o.dy});

  Future<({int resourceIndex, int start, int end})?> resolveLegacy(String? cfi, String? quote, double? progression) async {
    final m = await _call<Map>('resolveLegacy', {'cfi': cfi, 'quote': quote, 'progression': progression});
    if (m == null) return null;
    return (resourceIndex: (m['r'] as num).toInt(), start: (m['start'] as num).toInt(), end: (m['end'] as num).toInt());
  }

  Future<void> setHighlights(List<NativeHighlight> highlights) =>
      _call<void>('setHighlights', {'highlights': [for (final h in highlights) h.toMap()]});

  Future<void> close() async {
    await _call<void>('close');
    await _indexes.remove(sessionId)?.close();
  }

  static Future<ui.Image> _image(Map m) {
    final width = (m['width'] as num).toInt();
    final height = (m['height'] as num).toInt();
    final bytes = m['rgba'] as Uint8List;
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, width, height, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }
}
