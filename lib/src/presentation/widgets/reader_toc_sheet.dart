import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../aread.dart';
import '../theme/app_colors.dart';
import 'epub_controller.dart';

class ReaderTocSheet extends StatefulWidget {
  final Publication publication;
  final List<Annotation> annotations;
  final List<Bookmark> bookmarks;
  final ValueChanged<Locator>? onNavigate;
  final EpubController? epubController;

  /// Shown inline in a reader side pane: no fixed height, handle, close
  /// button or sheet corners, and choosing an item doesn't pop a route.
  final bool embedded;

  const ReaderTocSheet({
    super.key,
    required this.publication,
    required this.annotations,
    required this.bookmarks,
    this.onNavigate,
    this.epubController,
    this.embedded = false,
  });

  @override
  State<ReaderTocSheet> createState() => _ReaderTocSheetState();
}

class _ReaderTocSheetState extends State<ReaderTocSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tocLinks = widget.publication.tableOfContents.items;

    return Container(
      height: widget.embedded ? null : MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.fromLTRB(20, widget.embedded ? 16 : 10, 20, 20),
      decoration: BoxDecoration(
        // Embedded: the pane paints the surface (and ListTile ink needs the
        // Material below it, not a coloured box in between).
        color: widget.embedded ? null : AppColors.sheetSurface,
        borderRadius: widget.embedded ? null : BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          if (!widget.embedded)
          Center(
            child: Container(
              width: UIConstants.dragHandleWidth,
              height: UIConstants.dragHandleHeight,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.fg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Tabs (Chapters | Notes) & Circular Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.fg,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                labelColor: AppColors.fg,
                unselectedLabelColor: AppColors.fgSubtle,
                labelStyle: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w400),
                tabs: [
                  Tab(text: l10n.chapters),
                  Tab(text: l10n.notes),
                ],
              ),
              ),
              if (!widget.embedded)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: UIConstants.popupCloseButtonSize,
                  height: UIConstants.popupCloseButtonSize,
                  decoration: BoxDecoration(
                    color: AppColors.fg.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Bar View Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ValueListenableBuilder<List<EpubViewChapter>>(
                  valueListenable: widget.epubController?.tableOfContentsListenable ?? ValueNotifier([]),
                  builder: (context, chapters, _) {
                    if (tocLinks.isEmpty && chapters.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.loadingChapters,
                          style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 14),
                        ),
                      );
                    }

                    final count = chapters.isNotEmpty ? chapters.length : tocLinks.length;

                    return ListView.builder(
                      itemCount: count,
                      itemBuilder: (context, index) {
                        final String? title = chapters.isNotEmpty
                            ? chapters[index].title?.replaceAll('\n', '').trim()
                            : (index < tocLinks.length ? tocLinks[index].title : null);

                        final displayTitle = (title != null && title.isNotEmpty) ? title : l10n.chapterN(index + 1);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          title: Text(
                            displayTitle,
                            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.fg),
                          ),
                          onTap: () {
                            if (!widget.embedded) Navigator.of(context).pop();
                            if (widget.epubController != null && chapters.isNotEmpty) {
                              // startIndex is the chapter's first paragraph;
                              // the row index is not (it used to be passed
                              // here, jumping to paragraph N for chapter N).
                              widget.epubController!.scrollTo(index: chapters[index].startIndex);
                            } else if (widget.onNavigate != null && index < tocLinks.length) {
                              widget.onNavigate!(Locator(href: tocLinks[index].href));
                            }
                          },
                        );
                      },
                    );
                  },
                ),

                // 2. Notes & Annotations List
                widget.annotations.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noNotesSavedInThisBook,
                          style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.annotations.length,
                        itemBuilder: (context, index) {
                          final ann = widget.annotations[index];
                          return ListTile(
                            title: Text(
                              ann.textQuote ?? l10n.noteN(index + 1),
                              style: GoogleFonts.sora(color: AppColors.fg, fontSize: 14),
                            ),
                            subtitle: Text(
                              ann.locator.href,
                              style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 12),
                            ),
                            onTap: () {
                              if (!widget.embedded) Navigator.of(context).pop();
                              if (widget.onNavigate != null) {
                                widget.onNavigate!(ann.locator);
                              }
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
