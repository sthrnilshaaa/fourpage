import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../state/library_controller.dart';
import '../layout/book_details_pane.dart';
import '../layout/book_grid.dart';
import '../layout/browse_insets.dart';
import '../layout/window_class.dart';
import '../widgets/shelf_dialogs.dart';
import '../theme/app_colors.dart';
import '../utils/reader_launcher.dart';
import '../widgets/add_book_dialog.dart';
import '../widgets/app_chrome.dart';
import '../widgets/book_cover_widget.dart';
import '../widgets/home_skeleton.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Book shown in the expanded-width details pane (mouse selection).
  BookItem? _selected;

  void _openReader(BuildContext context, BookItem book) {
    LibraryController.instance.setActiveBook(book);
    openReader(context, book);
  }

  void _openSearch(BuildContext context) => openBookSearch(context);

  void _showAddBook(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddBookDialog(),
    );
  }

  static double _progressOf(BookItem book) =>
      book.progress;

  static String _authorOf(BookItem book) =>
      book.publication.metadata.authors.isNotEmpty ? book.publication.metadata.authors.first : l10n.unknownAuthor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryController.instance,
      builder: (context, _) {
        final library = LibraryController.instance;
        final books = library.books;
        final recent = library.recentBooks;

        final windowClass = context.windowClass;
        final details = windowClass.isExpanded ? resolveDetailsBook(_selected, books, recent: recent) : null;
        final main = Column(
            children: [
              BrowseTopBar(
                onSearchTap: () => _openSearch(context),
                onAddTap: () => _showAddBook(context),
              ),
              Expanded(
                // Library still loading at startup: skeleton, not the
                // "no books yet" empty state (which flashed before).
                child: !library.isCatalogLoaded
                    ? const HomeSkeleton()
                    : books.isEmpty
                    ? _buildEmptyState(context)
                    // Slivers, so only the book rows/tiles on screen are built.
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          const SliverToBoxAdapter(child: SizedBox(height: 2)),
                          SliverList.list(children: [
                          // 1. "Recent Reading": books by when they were
                          // last opened (hidden until one has been).
                          if (recent.isNotEmpty) ...[
                            _SectionHeader(
                              title: l10n.recentReading,
                              subtitle: l10n.pickUpWhereYouLeftOff,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 244,
                              child: ListView.separated(
                                key: const PageStorageKey('recent-reading'),
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 19),
                                itemCount: recent.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 20),
                                // Books still loading at launch, with no saved
                                // cover yet, are skeletons until they're ready.
                                itemBuilder: (context, index) => recent[index].showsPlaceholder
                                    ? const RecentCardSkeleton()
                                    : _RecentBookCard(
                                        key: ValueKey(recent[index].publication.id),
                                        book: recent[index],
                                        onTap: () => _openReader(context, recent[index]),
                                        onLongPress: () => showBookActions(context, recent[index],
                                            onOpen: () => _openReader(context, recent[index])),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 45),
                          ],

                          // 2. "Books"
                          _SectionHeader(
                            title: l10n.books,
                            subtitle: l10n.viewAllYourBooks,
                            showChevron: true,
                          ),
                          const SizedBox(height: 18),
                          ]),
                          if (!windowClass.isCompact)
                            BookGrid.sliver(
                              books: books,
                              padding: const EdgeInsets.fromLTRB(21, 0, 22, 20),
                              selected: details,
                              onOpen: (b) => _openReader(context, b),
                              onSelect: windowClass.isExpanded ? (b) => setState(() => _selected = b) : null,
                              onSecondary: (b, _) => showBookActions(context, b, onOpen: () => _openReader(context, b)),
                            )
                          else
                            SliverList.builder(
                              itemCount: books.length,
                              itemBuilder: (context, i) {
                                final book = books[i];
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(21, 0, 22, 20),
                                  child: book.showsPlaceholder
                                      ? const BookRowSkeleton()
                                      : _HomeBookRow(
                                          key: ValueKey(book.publication.id),
                                          book: book,
                                          onTap: () => _openReader(context, book),
                                          onLongPress: () =>
                                              showBookActions(context, book, onOpen: () => _openReader(context, book)),
                                        ),
                                );
                              },
                            ),
                          SliverToBoxAdapter(child: SizedBox(height: browseBottomPadding(context, compact: 140))),
                        ],
                      ),
              ),
            ],
          );

        if (!windowClass.isExpanded || books.isEmpty) {
          return Scaffold(backgroundColor: AppColors.figmaBackground, body: main);
        }
        return Scaffold(
          backgroundColor: AppColors.figmaBackground,
          body: Row(
            children: [
              Expanded(child: main),
              BookDetailsPane(
                book: details,
                onOpen: details == null ? null : () => _openReader(context, details),
                onMoveToShelf: details == null ? null : () => showMoveToShelfSheet(context, details),
                shelfName: details == null ? null : LibraryController.instance.shelfOf(details)?.name,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.fg.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 40,
                color: AppColors.figmaLime,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noBooksInYourLibrary,
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.importEpubBooksToStartYour,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 14,
                color: AppColors.fgSubtle,
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddBook(context),
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.figmaSurface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.fg.withValues(alpha: 0.14),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    l10n.importBooks,
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.fg,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Recent Reading" / "Books" heading: Sora 20 title, Sora 14 white-40% subtitle.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showChevron;

  const _SectionHeader({required this.title, required this.subtitle, this.showChevron = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sectionTitle.copyWith(height: 1)),
                const SizedBox(height: 5),
                Text(subtitle, style: AppText.sectionSubtitle),
              ],
            ),
          ),
          if (showChevron)
            const FigmaIcon(AssetConstants.iconChevronRight, width: 8, height: 13),
        ],
      ),
    );
  }
}

/// 121x182 cover (5pt radius, EPUB glyph top-left), title, author, and a
/// full-width 3pt progress bar underneath.
class _RecentBookCard extends StatelessWidget {
  final BookItem book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RecentBookCard({super.key, required this.book, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final progress = _HomeScreenState._progressOf(book);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 121,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 182,
              width: 121,
              child: BookCoverWidget(
                book: book,
                layoutMode: CoverLayoutMode.coverOnly,
                coverRadius: 5,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              book.publication.metadata.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 14, height: 18 / 14, color: AppColors.fg),
            ),
            const SizedBox(height: 6),
            Text(
              progress > 0 ? l10n.percentComplete((progress * 100).round()) : _HomeScreenState._authorOf(book),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 13, height: 14 / 13, color: AppColors.figmaTextMuted),
            ),
            const SizedBox(height: 9),
            ThinProgressBar(value: progress, trackColor: AppColors.figmaDivider),
          ],
        ),
      ),
    );
  }
}

/// Home "Books" row: 76x114 cover, DM Sans 17 title, Sora 15 author, then a
/// progress bar with "NN% Complete" at its end, and the format glyph top-right.
class _HomeBookRow extends StatelessWidget {
  final BookItem book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _HomeBookRow({super.key, required this.book, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final progress = _HomeScreenState._progressOf(book);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 114,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 76,
                child: BookCoverWidget(
                  book: book,
                  layoutMode: CoverLayoutMode.coverOnly,
                  coverRadius: 2,
                  showFormatBadge: false,
                ),
              ),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 40,
                    top: 9,
                    child: Text(
                      book.publication.metadata.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 17, height: 25 / 17, color: AppColors.fg),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 40,
                    top: 70,
                    child: Text(
                      _HomeScreenState._authorOf(book),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.listAuthor,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 95,
                    child: Row(
                      children: [
                        Expanded(
                          child: ThinProgressBar(value: progress, trackColor: AppColors.figmaDivider),
                        ),
                        const SizedBox(width: 13),
                        Text(
                          l10n.percentComplete((progress * 100).round()),
                          style: GoogleFonts.sora(fontSize: 13, height: 14 / 13, color: AppColors.figmaTextMuted),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 9,
                    child: FormatBadge(format: book.format),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
