import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../state/library_controller.dart';
import '../layout/book_grid.dart';
import '../layout/browse_insets.dart';
import '../layout/window_class.dart';
import '../theme/app_colors.dart';
import '../utils/reader_launcher.dart';
import '../widgets/shelf_dialogs.dart';
import '../widgets/add_book_dialog.dart';
import '../widgets/app_chrome.dart';
import '../widgets/book_cover_widget.dart';
import 'main_navigation_shell.dart';

/// Opens search inside the main shell (so the bottom nav stays visible, as
/// in the Figma Search_page), or as a plain route when there's no shell.
void openBookSearch(BuildContext context) {
  final shell = MainNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.openSearch();
  } else {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }
}

class SearchScreen extends StatefulWidget {
  final String initialQuery;

  /// Called to dismiss search when it's hosted inside the shell; when null
  /// the screen pops its own route instead.
  final VoidCallback? onClose;

  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.onClose,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _openReader(BookItem book) {
    LibraryController.instance.setActiveBook(book);
    openReader(context, book);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryController.instance,
      builder: (context, _) {
        final allBooks = LibraryController.instance.books;
        final q = _query.trim().toLowerCase();
        final matchingBooks = q.isEmpty
            ? allBooks
            : allBooks.where((b) {
                final titleMatch = b.publication.metadata.title.toLowerCase().contains(q);
                final authorMatch = b.publication.metadata.authors.any((a) => a.toLowerCase().contains(q));
                return titleMatch || authorMatch;
              }).toList();

        return Scaffold(
          backgroundColor: AppColors.figmaBackground,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                child: SegmentedTopBar(
                  leading: const AppLogoMark(),
                  onLeadingTap: _close,
                  middle: Row(
                    children: [
                      const SizedBox(width: 34),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: widget.initialQuery.isEmpty,
                          cursorColor: AppColors.figmaLime,
                          style: AppText.searchInput,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            hintText: l10n.searchBooks,
                            hintStyle: AppText.searchPlaceholder,
                            border: InputBorder.none,
                          ),
                          onChanged: (val) => setState(() => _query = val),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(12, 12, 13, 12),
                            child: FigmaIcon(AssetConstants.iconCloseSmall, width: 10.5, height: 10.5),
                          ),
                        )
                      else
                        const SizedBox(width: 12),
                    ],
                  ),
                  trailing: const FigmaIcon(AssetConstants.iconAddBook, width: 17, height: 18),
                  onTrailingTap: () => showDialog(context: context, builder: (_) => const AddBookDialog()),
                ),
              ),

              // "01 Results"
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 0, 19, 14),
                child: Text(
                  '${matchingBooks.length.toString().padLeft(2, '0')} Results',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    height: 23 / 15,
                    letterSpacing: -0.3,
                    color: AppColors.figmaTextFaint,
                  ),
                ),
              ),

              Expanded(
                child: matchingBooks.isEmpty
                    ? EmptyHint(l10n.noMatchingBooksFound)
                    : !context.windowClass.isCompact
                    ? BookGrid(
                        books: matchingBooks,
                        padding: const EdgeInsets.fromLTRB(20, 0, 23, 24),
                        onOpen: _openReader,
                        onSecondary: (b, _) => showBookActions(context, b, onOpen: () => _openReader(b)),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(20, 0, 23, browseBottomPadding(context, compact: 140)),
                        itemCount: matchingBooks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 22),
                        itemBuilder: (context, index) {
                          final book = matchingBooks[index];
                          return BookListRow(
                            cover: BookCoverWidget(
                              book: book,
                              layoutMode: CoverLayoutMode.coverOnly,
                              coverRadius: 2,
                              showFormatBadge: false,
                            ),
                            title: book.publication.metadata.title,
                            author: book.publication.metadata.authors.isNotEmpty
                                ? book.publication.metadata.authors.first
                                : l10n.unknownAuthor,
                            format: book.format,
                            progress: book.progress,
                            progressColor: AppColors.fg,
                            badge: FormatBadge(
                              format: book.format,
                              color: AppColors.fg.withValues(alpha: 0.1),
                              labelColor: AppColors.figmaTextFaint,
                              filled: false,
                            ),
                            onTap: () => _openReader(book),
                            onLongPress: () => showBookActions(context, book, onOpen: () => _openReader(book)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
