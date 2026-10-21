import 'dart:async';

import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../../application/session/reading_session.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/locator.dart';
import '../utils/saved_item_actions.dart';
import '../../domain/entities/nav_item.dart';
import '../theme/app_colors.dart';
import 'app_chrome.dart';

/// Chapters / Notes sheet for the sakura_epub-backed reader, laid out like
/// the Figma "opened_chapter" sheet. Shows the real chapter tree sakura_epub
/// parses from the book (nested entries collapse under their parent) and
/// the book's own notes/highlights - no fabricated page numbers.
class SakuraTocSheet extends StatefulWidget {
  final List<NavItem> chapters;
  final ValueChanged<String> onNavigateToHref;

  /// Notes and highlights for this book, shown on the Notes tab.
  final List<Annotation> notes;

  /// Shown inline in a reader side pane: no fixed height, handle, close
  /// button or sheet corners, and choosing an item doesn't pop a route.
  final bool embedded;

  /// When given, the Notes tab follows this session live (notes and
  /// bookmarks) and each entry can be removed, with Undo.
  final ReadingSession? session;

  /// Runs after a highlight is removed or put back (redraw the page).
  final Future<void> Function()? onAnnotationsChanged;

  const SakuraTocSheet({
    super.key,
    required this.chapters,
    required this.onNavigateToHref,
    this.notes = const [],
    this.embedded = false,
    this.session,
    this.onAnnotationsChanged,
  });

  @override
  State<SakuraTocSheet> createState() => _SakuraTocSheetState();
}

class _SakuraTocSheetState extends State<SakuraTocSheet> {
  static Color get _sheetColor => AppColors.figmaSurface;
  static Color get _handleColor => AppColors.figmaTextGhost;

  int _tab = 0;
  final Set<NavItem> _expanded = {};
  StreamSubscription<Object?>? _sessionSub;
  // Swiped away and being removed; hidden at once so the list never shows them again mid-removal.
  final Set<String> _hidden = {};

  @override
  void initState() {
    super.initState();
    _sessionSub = widget.session?.stateStream.listen((state) {
      if (!mounted) return;
      final live = {for (final a in state.annotations) a.id, for (final b in state.bookmarks) b.id};
      setState(() => _hidden.removeWhere((id) => !live.contains(id)));
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  List<Annotation> get _annotations => widget.session?.state.annotations ?? widget.notes;
  List<Bookmark> get _bookmarks => widget.session?.state.bookmarks ?? const [];

  /// Where a saved place opens: exact text offset when known, else its CFI or href.
  static String _target(Locator l) {
    final chars = l.locations.charOffset;
    if (chars != null && l.href.isNotEmpty && !l.href.startsWith('epubcfi(')) {
      return '${l.href.split('#').first}#aread:$chars';
    }
    return l.locations.cfi ?? l.href;
  }

  void _go(String href) {
    if (!widget.embedded) Navigator.of(context).pop();
    widget.onNavigateToHref(href);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _sheet(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.62,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Builder(builder: _sheet),
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    return Container(
      height: widget.embedded ? null : MediaQuery.of(context).size.height * 0.62,
      decoration: BoxDecoration(
        color: _sheetColor,
        borderRadius: widget.embedded ? null : BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 11),
          if (!widget.embedded)
          Center(
            child: Container(
              width: 75,
              height: 6,
              decoration: BoxDecoration(color: _handleColor, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 11, 23, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tabButton(l10n.chapters, 0),
                const SizedBox(width: 12),
                _tabButton(l10n.notes, 1),
                const Spacer(),
                if (!widget.embedded)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const FigmaIcon(AssetConstants.iconCloseCircle, width: 48, height: 48),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _tab == 0 ? _buildChapters() : _buildNotes(),
            ),
          ),
        ],
      ),
    );
  }

  /// Sora 17 label with a 121x3 white underline when active.
  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = index),
      child: SizedBox(
        width: 121,
        height: 55,
        child: Column(
          children: [
            const SizedBox(height: 22),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: GoogleFonts.sora(
                fontSize: 17,
                height: 14 / 17,
                letterSpacing: -0.34,
                fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
                color: selected ? AppColors.fg : AppColors.figmaTextFaint,
              ),
              child: Text(label),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              decoration: BoxDecoration(
                color: selected ? AppColors.fg : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapters() {
    if (widget.chapters.isEmpty) {
      return EmptyHint(l10n.loadingChapters, key: ValueKey('loading'));
    }
    return Scrollbar(
      key: const ValueKey('chapters'),
      thickness: 6,
      radius: const Radius.circular(3),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(23, 0, 22, 24),
        itemCount: widget.chapters.length,
        separatorBuilder: (_, _) => Divider(height: 1, thickness: 1, color: AppColors.figmaDivider),
        itemBuilder: (context, index) => _buildTopLevel(widget.chapters[index], index),
      ),
    );
  }

  Widget _buildTopLevel(NavItem item, int index) {
    final expandable = item.children.isNotEmpty;
    final expanded = _expanded.contains(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _entry(
          title: item.title,
          subtitle: l10n.sectionLabel((index + 1).toString().padLeft(2, '0')),
          indent: 9,
          onTap: () => _go(item.href),
          trailing: expandable
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => expanded ? _expanded.remove(item) : _expanded.add(item)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const FigmaIcon(AssetConstants.iconChevronDown, width: 12, height: 7.7),
                    ),
                  ),
                )
              : null,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, child) in item.children.indexed)
                      _entry(
                        title: child.title,
                        subtitle: l10n.sectionLabel('${(index + 1).toString().padLeft(2, '0')}.${i + 1}'),
                        indent: 42,
                        onTap: () => _go(child.href),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Title (Sora 15 white) over a white-50% subtitle, 73pt row.
  Widget _entry({
    required String title,
    required String subtitle,
    required double indent,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 73,
        child: Row(
          children: [
            SizedBox(width: indent),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : l10n.untitled,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 15, height: 25 / 15, color: AppColors.fg),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.sora(fontSize: 15, height: 25 / 15, color: AppColors.figmaTextMuted),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Future<void> _removeNote(BuildContext context, Annotation a) async {
    final session = widget.session;
    if (session == null) return;
    await removeAnnotationWithUndo(ScaffoldMessenger.of(context), session, a, onChanged: widget.onAnnotationsChanged);
  }

  Future<void> _removeBookmark(BuildContext context, Bookmark b) async {
    final session = widget.session;
    if (session == null) return;
    await removeBookmarkWithUndo(ScaffoldMessenger.of(context), session, b);
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 0, 4),
        child: Text(text, style: GoogleFonts.sora(fontSize: 12, color: AppColors.figmaTextFaint)),
      );

  Widget _removeButton(String tooltip, VoidCallback onPressed) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.figmaTextFaint),
      );

  Widget _buildNotes() {
    final notes = _annotations.where((a) => a.type != AnnotationType.bookmark && !_hidden.contains(a.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final bookmarks = _bookmarks.where((b) => !_hidden.contains(b.id)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final removable = widget.session != null;
    if (notes.isEmpty && bookmarks.isEmpty) {
      return EmptyHint(l10n.noNotesYetSelectTextWhile, key: ValueKey('no-notes'));
    }
    return Builder(
      key: const ValueKey('notes'),
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(23, 0, 22, 24),
        children: [
          if (bookmarks.isNotEmpty) ...[
            _sectionLabel(l10n.bookmarksSection),
            for (final b in bookmarks)
              Dismissible(
                key: ValueKey('bm-${b.id}'),
                direction: removable ? DismissDirection.endToStart : DismissDirection.none,
                background: _swipeBackground(),
                onDismissed: (_) {
                  setState(() => _hidden.add(b.id));
                  _removeBookmark(context, b);
                },
                child: InkWell(
                  onTap: () => _go(_target(b.locator)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 6, 0, 6),
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_rounded, size: 20, color: AppColors.accentLime),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(b.title, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fg)),
                        ),
                        if (removable) _removeButton(l10n.removeBookmark, () => _removeBookmark(context, b)),
                      ],
                    ),
                  ),
                ),
              ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionLabel(l10n.highlightsSection),
            ],
          ],
          for (final a in notes) ...[
            Dismissible(
              key: ValueKey('note-${a.id}'),
              direction: removable ? DismissDirection.endToStart : DismissDirection.none,
              background: _swipeBackground(),
              onDismissed: (_) {
                setState(() => _hidden.add(a.id));
                _removeNote(context, a);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _go(a.locator.locations.cfi ?? a.locator.href),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 16, 0, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '“${a.textQuote ?? ''}”',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.amethysta(fontSize: 16, height: 1.45, color: AppColors.fg),
                            ),
                            if ((a.note ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                a.note!,
                                style: GoogleFonts.sora(fontSize: 14, color: AppColors.figmaTextMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (removable)
                        _removeButton(
                          (a.note ?? '').isNotEmpty ? l10n.removeNote : l10n.removeHighlight,
                          () => _removeNote(context, a),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: AppColors.figmaDivider),
          ],
        ],
      ),
    );
  }

  Widget _swipeBackground() => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withValues(alpha: 0.18),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      );
}
