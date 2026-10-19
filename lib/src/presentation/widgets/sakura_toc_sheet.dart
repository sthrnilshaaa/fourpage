import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../../domain/entities/annotation.dart';
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

  const SakuraTocSheet({
    super.key,
    required this.chapters,
    required this.onNavigateToHref,
    this.notes = const [],
    this.embedded = false,
  });

  @override
  State<SakuraTocSheet> createState() => _SakuraTocSheetState();
}

class _SakuraTocSheetState extends State<SakuraTocSheet> {
  static Color get _sheetColor => AppColors.figmaSurface;
  static Color get _handleColor => AppColors.figmaTextGhost;

  int _tab = 0;
  final Set<NavItem> _expanded = {};

  void _go(String href) {
    if (!widget.embedded) Navigator.of(context).pop();
    widget.onNavigateToHref(href);
  }

  @override
  Widget build(BuildContext context) {
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

  Widget _buildNotes() {
    final notes = widget.notes.where((a) => a.type != AnnotationType.bookmark).toList();
    if (notes.isEmpty) {
      return EmptyHint(l10n.noNotesYetSelectTextWhile, key: ValueKey('no-notes'));
    }
    return ListView.separated(
      key: const ValueKey('notes'),
      padding: const EdgeInsets.fromLTRB(23, 0, 22, 24),
      itemCount: notes.length,
      separatorBuilder: (_, _) => Divider(height: 1, thickness: 1, color: AppColors.figmaDivider),
      itemBuilder: (context, index) {
        final a = notes[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _go(a.locator.locations.cfi ?? a.locator.href),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 16, 0, 16),
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
        );
      },
    );
  }
}
