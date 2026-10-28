import 'dart:async';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../state/app_preferences.dart';
import '../platform/app_haptics.dart';
import '../platform/folder_tree.dart';
import '../state/library_controller.dart';
import '../state/shelves.dart';
import '../utils/library_sort.dart';
import '../layout/browse_insets.dart';
import '../layout/adaptive_sheet.dart';
import '../layout/book_details_pane.dart';
import '../layout/book_grid.dart';
import '../layout/max_width.dart';
import '../layout/window_class.dart';
import '../theme/app_colors.dart';
import '../utils/reader_launcher.dart';
import '../widgets/add_book_dialog.dart';
import '../widgets/app_chrome.dart';
import '../widgets/book_cover_widget.dart';
import '../widgets/shelf_dialogs.dart';
import 'search_screen.dart';

enum LibraryTabSection { allBooks, shelves, folders }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryTabSection _selectedTab = LibraryTabSection.allBooks;
  String? _folderFilter;

  /// Book shown in the expanded-width details pane (mouse selection).
  BookItem? _selected;

  final _pages = PageController();

  // Set while a tab tap animates the pages, so passing through a middle page
  // doesn't flick the underline to it.
  bool _jumping = false;

  Future<void> _goToTab(LibraryTabSection tab) async {
    setState(() => _selectedTab = tab);
    if (!_pages.hasClients) return;
    _jumping = true;
    await _pages.animateToPage(tab.index, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    _jumping = false;
  }

  // Shelf tint colours from the Figma file (Rectangle 578/579/580, 50% alpha).
  static const _shelfTints = [Color(0x80097C9D), Color(0x80302E5F), Color(0x802E5F4B)];

  void _openReader(BookItem book) {
    LibraryController.instance.setActiveBook(book);
    openReader(context, book);
  }

  void _openSearch() => openBookSearch(context);

  /// The arrow on the selected tab: choose how the library is ordered.
  Future<void> _showSortSheet() async {
    final current = AppPreferences.instance.librarySort;
    final picked = await showAdaptiveSheet<LibrarySort>(
      context: context,
      backgroundColor: AppColors.sheetSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(l10n.sortBy, style: GoogleFonts.sora(fontSize: 16, color: AppColors.fg, fontWeight: FontWeight.w600)),
              ),
              for (final sort in LibrarySort.values)
                ListTile(
                  title: Text(librarySortLabel(sort), style: GoogleFonts.sora(fontSize: 15, color: AppColors.fg)),
                  trailing: sort == current ? Icon(Icons.check_rounded, color: AppColors.accentLime) : null,
                  onTap: () => Navigator.of(sheetContext).pop(sort),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != current) {
      await AppPreferences.instance.setLibrarySort(picked);
      if (mounted) setState(() {});
    }
  }

  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder: (_) => const AddBookDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryController.instance,
      builder: (context, _) {
        final books = LibraryController.instance.books;

        final showDetails = context.windowClass.isExpanded && _selectedTab == LibraryTabSection.allBooks;
        final main = Column(
            children: [
              BrowseTopBar(onSearchTap: _openSearch, onAddTap: _showAddBookDialog),
              const SizedBox(height: 3),
              UnderlineTabs(
                labels: [l10n.allBooks, l10n.shelves, l10n.folders],
                selectedIndex: _selectedTab.index,
                onSelectedTap: (_) => _showSortSheet(),
                onSelected: (i) {
                  if (i == 0 && _selectedTab == LibraryTabSection.allBooks) {
                    setState(() => _folderFilter = null);
                  }
                  _goToTab(LibraryTabSection.values[i]);
                },
              ),
              Expanded(
                // Swipe sideways to move between All books / Shelves / Folders.
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) {
                    if (!_jumping) setState(() => _selectedTab = LibraryTabSection.values[i]);
                  },
                  children: [
                    KeyedSubtree(key: ValueKey(_folderFilter), child: _buildAllBooksView(books)),
                    _buildShelvesView(books),
                    _buildFoldersView(books),
                  ],
                ),
              ),
            ],
          );

        if (!showDetails) {
          return Scaffold(backgroundColor: AppColors.figmaBackground, body: main);
        }
        final lib = LibraryController.instance;
        final details = resolveDetailsBook(_selected, books, recent: lib.recentBooks);
        return Scaffold(
          backgroundColor: AppColors.figmaBackground,
          body: Row(
            children: [
              Expanded(child: main),
              BookDetailsPane(
                book: details,
                onOpen: details == null ? null : () => _openReader(details),
                onMoveToShelf: details == null ? null : () => showMoveToShelfSheet(context, details),
                shelfName: details == null ? null : lib.shelfOf(details)?.name,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _authorOf(BookItem book) =>
      book.publication.metadata.authors.isNotEmpty ? book.publication.metadata.authors.first : l10n.unknownAuthor;

  /// 1. All Books (library_all-books)
  Widget _buildAllBooksView(List<BookItem> books) {
    final displayedBooks = sortBooks(
      _folderFilter == null ? books : books.where((b) => b.folderPath == _folderFilter).toList(),
      AppPreferences.instance.librarySort,
    );

    if (displayedBooks.isEmpty) {
      if (_folderFilter != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.noBooksFoundInThisFolder,
                style: GoogleFonts.sora(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _folderFilter = null),
                child: Text(l10n.showAllBooks, style: GoogleFonts.sora(color: AppColors.accentLime)),
              ),
            ],
          ),
        );
      }
      return EmptyHint(l10n.noBooksAvailableImportBooksTo);
    }

    return Column(
      children: [
        if (_folderFilter != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 23, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.folderLabel(folderSegments(_folderFilter!).lastOrNull ?? _folderFilter!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 13, color: AppColors.accentLime, fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _folderFilter = null),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(l10n.clear, style: TextStyle(color: AppColors.fgMuted, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        if (!context.windowClass.isCompact)
          Expanded(
            child: BookGrid(
              books: displayedBooks,
              selected: context.windowClass.isExpanded
                  ? resolveDetailsBook(_selected, displayedBooks, recent: LibraryController.instance.recentBooks)
                  : null,
              onOpen: _openReader,
              onSelect: context.windowClass.isExpanded ? (b) => setState(() => _selected = b) : null,
              onSecondary: (b, _) => showBookActions(context, b, onOpen: () => _openReader(b)),
            ),
          )
        else
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(22, 20, 23, browseBottomPadding(context, compact: 140)),
            itemCount: displayedBooks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 22),
            itemBuilder: (context, index) {
              final book = displayedBooks[index];
              return BookListRow(
                cover: BookCoverWidget(
                  book: book,
                  layoutMode: CoverLayoutMode.coverOnly,
                  coverRadius: 2,
                  showFormatBadge: false,
                ),
                title: book.publication.metadata.title,
                author: _authorOf(book),
                format: book.format,
                progress: book.progress,
                onTap: () => _openReader(book),
                onLongPress: () => showBookActions(context, book, onOpen: () => _openReader(book)),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 2. Shelves (library_shelves): a row of overlapping covers with a tinted
  /// band across their lower part, then "Name ... NN Books >".
  ///
  /// Long-press a cover and drag it onto another shelf to move it. While a
  /// book is being dragged the top bar turns into two drop zones: a new
  /// shelf, and (for shelved books) "unshelve".
  Widget _buildShelvesView(List<BookItem> books) {
    final lib = LibraryController.instance;
    final shelves = lib.shelves;
    if (books.isEmpty && shelves.isEmpty) {
      return Column(
        children: [
          _shelvesTopBar(),
          Expanded(child: EmptyHint(l10n.noShelvesYetImportBooksTo)),
        ],
      );
    }
    final unshelved = lib.unshelvedBooks;

    return Column(
      children: [
        _shelvesTopBar(),
        Expanded(
          child: ListView(
            key: _shelvesListKey,
            controller: _shelvesScroll,
            padding: EdgeInsets.fromLTRB(11, 6, 12, browseBottomPadding(context, compact: 140)),
            children: [
              if (shelves.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  child: Text(l10n.noShelvesCreateOne, style: GoogleFonts.sora(fontSize: 13, color: AppColors.fgSubtle)),
                ),
              for (final (i, shelf) in shelves.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 21),
                  child: _ShelfTile(
                    name: shelf.name,
                    books: lib.booksOnShelf(shelf),
                    tint: _shelfTints[i % _shelfTints.length],
                    accepts: (book) => lib.shelfOf(book)?.id != shelf.id,
                    onDrop: (book) => _dropOnShelf(book, shelf),
                    onOptions: () => showShelfOptionsSheet(context, shelf),
                    dragCallbacks: _dragCallbacks,
                    onBookTap: _openReader,
                    onTap: () => _openShelf(shelf),
                  ),
                ),
              if (unshelved.isNotEmpty || (_dragging != null && lib.shelfOf(_dragging!) != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 21),
                  child: _ShelfTile(
                    name: l10n.unshelved,
                    books: unshelved,
                    tint: _shelfTints[shelves.length % _shelfTints.length],
                    accepts: (book) => lib.shelfOf(book) != null,
                    onDrop: (book) => _dropOnShelf(book, null),
                    dragCallbacks: _dragCallbacks,
                    onBookTap: _openReader,
                    onTap: () => _openShelf(null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- shelves: drag & drop ----------------------------------------------------

  final _shelvesListKey = GlobalKey();
  final _shelvesScroll = ScrollController();
  BookItem? _dragging;
  Offset? _dragPoint;
  Timer? _autoScroll;

  late final _dragCallbacks = _DragCallbacks(
    started: (book) {
      AppHaptics.tick();
      setState(() => _dragging = book);
      _autoScroll?.cancel();
      _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) => _autoScrollTick());
    },
    moved: (point) => _dragPoint = point,
    ended: () {
      _autoScroll?.cancel();
      _autoScroll = null;
      _dragPoint = null;
      if (mounted) setState(() => _dragging = null);
    },
  );

  /// Scrolls the shelf list while a dragged book is held near its top or
  /// bottom edge, so far-away shelves can be reached.
  void _autoScrollTick() {
    final point = _dragPoint;
    final box = _shelvesListKey.currentContext?.findRenderObject() as RenderBox?;
    if (point == null || box == null || !_shelvesScroll.hasClients) return;
    final local = box.globalToLocal(point);
    const edge = 80.0;
    // The bottom nav floats over the last ~110px of the list.
    final bottomEdge = box.size.height - 110;
    double delta = 0;
    if (local.dy < edge) {
      delta = -(edge - local.dy) / edge * 14;
    } else if (local.dy > bottomEdge - edge) {
      delta = (local.dy - (bottomEdge - edge)) / edge * 14;
    }
    if (delta == 0) return;
    final pos = _shelvesScroll.position;
    final target = (pos.pixels + delta.clamp(-14.0, 14.0)).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (target != pos.pixels) _shelvesScroll.jumpTo(target);
  }

  void _dropOnShelf(BookItem book, Shelf? shelf) {
    final lib = LibraryController.instance;
    final from = lib.shelfOf(book);
    lib.moveBookToShelf(book, shelf);
    AppHaptics.confirm();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        persist: false,
        content: Text(shelf != null ? l10n.movedToShelf(shelf.name) : l10n.removedFromShelf(from?.name ?? '')),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () {
            final back = from == null ? null : lib.shelves.where((s) => s.id == from.id).firstOrNull;
            lib.moveBookToShelf(book, back);
          },
        ),
      ));
  }

  /// "New shelf" button, or two drop zones while a book is being dragged.
  Widget _shelvesTopBar() {
    final dragging = _dragging;
    final shelved = dragging != null && LibraryController.instance.shelfOf(dragging) != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 23, 10),
      child: SizedBox(
        height: 44,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: dragging == null
              ? Row(
                  key: const ValueKey('idle'),
                  children: [
                    Expanded(
                      child: Text(
                        l10n.shelvesDragHint,
                        maxLines: 2,
                        style: GoogleFonts.sora(fontSize: 11, height: 1.35, color: AppColors.fgSubtle),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PillButton(
                      icon: Icons.add_rounded,
                      label: l10n.newShelf,
                      onTap: () => showCreateShelfDialog(context),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('dragging'),
                  children: [
                    Expanded(
                      child: _DropZone(
                        icon: Icons.add_rounded,
                        label: l10n.dropToCreateShelf,
                        onDrop: (book) => showCreateShelfDialog(context, withBook: book),
                      ),
                    ),
                    if (shelved) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DropZone(
                          icon: Icons.remove_circle_outline_rounded,
                          label: l10n.dropToRemoveFromShelf,
                          danger: true,
                          onDrop: (book) => _dropOnShelf(book, null),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  void _openShelf(Shelf? shelf) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShelfBooksScreen(shelfId: shelf?.id, onOpenBook: _openReader),
    ));
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _shelvesScroll.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// 3. Folders (library_folders).
  ///
  /// Lists all tracked source folders with live EPUB counts.
  Widget _buildFoldersView(List<BookItem> books) {
    final scannedFolders = LibraryController.instance.scannedFolders;
    if (books.isEmpty && scannedFolders.isEmpty) {
      return EmptyHint(l10n.noFoldersYetImportAFolder);
    }

    final folderTiles = <Widget>[];

    for (final folder in scannedFolders) {
      final folderBooks = books.where((b) => b.folderPath == folder).toList();
      final epubCount = folderBooks.where((b) => b.format.toUpperCase() == 'EPUB').length;
      final otherCount = folderBooks.length - epubCount;

      final parts = folderSegments(folder);
      final displayPath = parts.length >= 2
          ? '${parts[parts.length - 2]}/${parts.last}'
          : (parts.isNotEmpty ? parts.last : folder);

      folderTiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _FolderTile(
            path: displayPath,
            counts: {
              'EPUB': epubCount,
              if (otherCount > 0) l10n.other: otherCount,
            },
            onTap: () {
              setState(() => _folderFilter = folder);
              _goToTab(LibraryTabSection.allBooks);
            },
          ),
        ),
      );
    }

    final unassignedBooks = books.where((b) => b.folderPath == null || !scannedFolders.contains(b.folderPath)).toList();
    if (unassignedBooks.isNotEmpty || folderTiles.isEmpty) {
      final epubCount = unassignedBooks.where((b) => b.format.toUpperCase() == 'EPUB').length;
      final otherCount = unassignedBooks.length - epubCount;

      folderTiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _FolderTile(
            path: l10n.fourpageImported,
            counts: {
              'EPUB': epubCount,
              if (otherCount > 0) l10n.other: otherCount,
            },
            onTap: () {
              setState(() => _folderFilter = null);
              _goToTab(LibraryTabSection.allBooks);
            },
          ),
        ),
      );
    }

    final list = ListView(
      padding: EdgeInsets.fromLTRB(22, 20, 23, browseBottomPadding(context, compact: 140)),
      children: folderTiles,
    );
    return context.windowClass.isCompact ? list : MaxWidth(maxWidth: 900, child: list);
  }
}

class _DragCallbacks {
  final ValueChanged<BookItem> started;
  final ValueChanged<Offset> moved;
  final VoidCallback ended;
  const _DragCallbacks({required this.started, required this.moved, required this.ended});
}

class _ShelfTile extends StatelessWidget {
  final String name;
  final List<BookItem> books;
  final Color tint;
  final ValueChanged<BookItem> onBookTap;
  final VoidCallback onTap;

  /// Whether a dragged book may be dropped here (not the shelf it's on).
  final bool Function(BookItem) accepts;
  final ValueChanged<BookItem> onDrop;

  /// ⋮ menu; null for the built-in "Unshelved" group.
  final VoidCallback? onOptions;
  final _DragCallbacks dragCallbacks;

  const _ShelfTile({
    required this.name,
    required this.books,
    required this.tint,
    required this.onBookTap,
    required this.onTap,
    required this.accepts,
    required this.onDrop,
    required this.dragCallbacks,
    this.onOptions,
  });

  Widget _cover(BookItem book, {double scale = 1}) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          width: 75 * scale,
          height: 114 * scale,
          child: BookCoverWidget(
            book: book,
            layoutMode: CoverLayoutMode.coverOnly,
            coverRadius: 2,
            showFormatBadge: false,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DragTarget<BookItem>(
      onWillAcceptWithDetails: (d) => accepts(d.data),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: hovering ? AppColors.accentLime : Colors.transparent, width: 2),
            color: hovering ? AppColors.accentLime.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 130,
                child: Stack(
                  children: [
                    // Tinted band over the covers' lower part (417x104, 26pt down).
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 26,
                      height: 104,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.fg.withValues(alpha: 0.05)),
                          ),
                        ),
                      ),
                    ),
                    // Covers: 75x114, 5pt apart, starting 12pt in.
                    Positioned.fill(
                      child: books.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                              child: Center(
                                child: Text(
                                  l10n.emptyShelfHint,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.sora(fontSize: 12, color: AppColors.fg.withValues(alpha: 0.75)),
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                              itemCount: books.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 5),
                              itemBuilder: (context, index) {
                                final book = books[index];
                                return LongPressDraggable<BookItem>(
                                  data: book,
                                  hapticFeedbackOnStart: false,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    elevation: 12,
                                    shadowColor: Colors.black,
                                    child: _cover(book, scale: 1.1),
                                  ),
                                  childWhenDragging: Opacity(opacity: 0.25, child: _cover(book)),
                                  onDragStarted: () => dragCallbacks.started(book),
                                  onDragUpdate: (d) => dragCallbacks.moved(d.globalPosition),
                                  onDragEnd: (_) => dragCallbacks.ended(),
                                  onDraggableCanceled: (_, _) => dragCallbacks.ended(),
                                  child: GestureDetector(
                                    onTap: () => onBookTap(book),
                                    child: _cover(book),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(14, 9, onOptions == null ? 15 : 4, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.listTitle),
                            ),
                            Text(
                              '${books.length.toString().padLeft(2, '0')} Books',
                              style: AppText.listAuthor,
                            ),
                            const SizedBox(width: 12),
                            const FigmaIcon(AssetConstants.iconChevronRight, width: 6, height: 11),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onOptions != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: SizedBox(
                        width: 36,
                        height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: l10n.shelfOptions,
                          icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.fgMuted),
                          onPressed: onOptions,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pillSurface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.fgHairline)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.accentLime),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.sora(fontSize: 13, color: AppColors.fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A drop area shown at the top of Shelves while a book is dragged.
class _DropZone extends StatelessWidget {
  final IconData icon;
  final String label;
  final ValueChanged<BookItem> onDrop;
  final bool danger;
  const _DropZone({required this.icon, required this.label, required this.onDrop, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : AppColors.accentLime;
    return DragTarget<BookItem>(
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: hovering ? 0.25 : 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: hovering ? 1 : 0.5), width: hovering ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 12, color: AppColors.fg),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Every book on one shelf ([shelfId]), or the unshelved books when null.
/// Long-press a book to move it or take it off the shelf.
class ShelfBooksScreen extends StatelessWidget {
  final String? shelfId;
  final ValueChanged<BookItem> onOpenBook;
  const ShelfBooksScreen({super.key, required this.shelfId, required this.onOpenBook});

  @override
  Widget build(BuildContext context) {
    final lib = LibraryController.instance;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final shelf = shelfId == null ? null : lib.shelves.where((s) => s.id == shelfId).firstOrNull;
        if (shelfId != null && shelf == null) {
          // Deleted from its own menu: leave.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return Scaffold(backgroundColor: AppColors.figmaBackground);
        }
        final books = sortBooks(
          shelf == null ? lib.unshelvedBooks : lib.booksOnShelf(shelf),
          AppPreferences.instance.librarySort,
        );
        return Scaffold(
          backgroundColor: AppColors.figmaBackground,
          appBar: AppBar(
            backgroundColor: AppColors.figmaBackground,
            foregroundColor: AppColors.fg,
            surfaceTintColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shelf?.name ?? l10n.unshelved, style: GoogleFonts.sora(fontSize: 18, color: AppColors.fg)),
                Text(l10n.shelfBookCount(books.length), style: GoogleFonts.sora(fontSize: 12, color: AppColors.fgSubtle)),
              ],
            ),
            actions: [
              if (shelf != null) ...[
                IconButton(
                  tooltip: l10n.addBooks,
                  icon: Icon(Icons.library_add_outlined, color: AppColors.fg),
                  onPressed: () => showAddBooksToShelfSheet(context, shelf),
                ),
                IconButton(
                  tooltip: l10n.shelfOptions,
                  icon: Icon(Icons.more_vert_rounded, color: AppColors.fg),
                  onPressed: () => showShelfOptionsSheet(context, shelf),
                ),
              ],
            ],
          ),
          body: books.isEmpty
              ? EmptyHint(shelf == null ? l10n.noBooksAvailableImportBooksTo : l10n.emptyShelfHint)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 12, 23, 40),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 22),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return BookListRow(
                      cover: BookCoverWidget(
                        book: book,
                        layoutMode: CoverLayoutMode.coverOnly,
                        coverRadius: 2,
                        showFormatBadge: false,
                      ),
                      title: book.publication.metadata.title,
                      author: book.publication.metadata.authors.firstOrNull ?? l10n.unknownAuthor,
                      format: book.format,
                      progress: book.progress,
                      onTap: () => onOpenBook(book),
                      onLongPress: () => showBookActions(context, book, onOpen: () => onOpenBook(book)),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _FolderTile extends StatelessWidget {
  final String path;
  final Map<String, int> counts;
  final VoidCallback onTap;

  const _FolderTile({required this.path, required this.counts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.figmaSurface,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const FigmaIcon(AssetConstants.iconFolder, width: 25, height: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 15, height: 23 / 15, color: AppColors.fg),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      for (final entry in counts.entries) ...[
                        Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.figmaSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.key}: ${entry.value.toString().padLeft(2, '0')}',
                            style: GoogleFonts.sora(fontSize: 11, height: 1, color: AppColors.figmaTextFaint),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const FigmaIcon(AssetConstants.iconChevronRight, width: 6, height: 11),
          ],
        ),
      ),
    );
  }
}
