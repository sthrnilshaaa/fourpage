import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../aread.dart';
import '../state/library_controller.dart';
import '../layout/adaptive_sheet.dart';
import '../layout/browse_insets.dart';
import '../layout/max_width.dart';
import '../layout/window_class.dart';
import '../theme/app_colors.dart';
import '../utils/reader_launcher.dart';
import '../utils/saved_item_actions.dart';
import '../widgets/add_book_dialog.dart';
import '../widgets/app_chrome.dart';
import 'search_screen.dart';

enum SavedTabSection { bookmark, quotes, notes }

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  SavedTabSection _selectedTab = SavedTabSection.quotes;

  late final _pages = PageController(initialPage: _selectedTab.index);

  // Set while a tab tap animates the pages, so passing through a middle page
  // doesn't flick the underline to it.
  bool _jumping = false;

  Future<void> _goToTab(SavedTabSection tab) async {
    setState(() => _selectedTab = tab);
    if (!_pages.hasClients) return;
    _jumping = true;
    await _pages.animateToPage(tab.index, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    _jumping = false;
  }

  // Each book's session, so highlights/bookmarks added or removed anywhere show here at once.
  final Map<String, StreamSubscription<Object?>> _subs = {};
  // Removed from the long-press menu (hidden at once, before the session updates).
  final Set<String> _hidden = {};

  @override
  void initState() {
    super.initState();
    LibraryController.instance.addListener(_watchSessions);
    _watchSessions();
  }

  @override
  void dispose() {
    _pages.dispose();
    LibraryController.instance.removeListener(_watchSessions);
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _watchSessions() {
    final books = {for (final b in LibraryController.instance.books) b.publication.id: b};
    _subs.removeWhere((id, sub) {
      if (books.containsKey(id)) return false;
      sub.cancel();
      return true;
    });
    for (final entry in books.entries) {
      _subs.putIfAbsent(
        entry.key,
        () => entry.value.session.stateStream.listen((state) {
          if (!mounted) return;
          final live = {for (final a in state.annotations) a.id, for (final b in state.bookmarks) b.id};
          setState(() => _hidden.removeWhere((id) => !live.contains(id) && _ownedBy(entry.key, id)));
        }),
      );
    }
  }

  // Hidden ids are remembered with their book so one book's update doesn't clear another's.
  final Map<String, String> _hiddenBook = {};
  bool _ownedBy(String bookId, String id) => _hiddenBook[id] == bookId;

  void _hide(BookItem book, String id) {
    _hiddenBook[id] = book.publication.id;
    setState(() => _hidden.add(id));
  }

  void _open(BookItem book, Locator locator) {
    LibraryController.instance.setActiveBook(book);
    openReader(context, book, initialLocator: locator);
  }

  Future<void> _removeAnnotation(BookItem book, Annotation a) =>
      removeAnnotationWithUndo(ScaffoldMessenger.of(context), book.session, a);

  Future<void> _removeBookmark(BookItem book, Bookmark b) =>
      removeBookmarkWithUndo(ScaffoldMessenger.of(context), book.session, b);

  /// Long-press menu on a saved item: open, copy, share, remove.
  Future<void> _showItemMenu({
    required String title,
    String? text,
    required VoidCallback onOpen,
    required String removeLabel,
    required VoidCallback onRemove,
  }) async {
    final choice = await showAdaptiveSheet<String>(
      context: context,
      backgroundColor: AppColors.sheetSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        Widget tile(IconData icon, String label, String value, {bool danger = false}) => ListTile(
          leading: Icon(icon, color: danger ? Colors.redAccent : AppColors.fgMuted),
          title: Text(label, style: GoogleFonts.sora(fontSize: 15, color: danger ? Colors.redAccent : AppColors.fg)),
          onTap: () => Navigator.of(sheetContext).pop(value),
        );
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 16, color: AppColors.fg, fontWeight: FontWeight.w600),
                  ),
                ),
                tile(Icons.menu_book_rounded, l10n.openBook, 'open'),
                if (text != null && text.isNotEmpty) ...[
                  tile(Icons.copy_rounded, l10n.copy, 'copy'),
                  tile(Icons.ios_share_rounded, l10n.share, 'share'),
                ],
                tile(Icons.delete_outline_rounded, removeLabel, 'remove', danger: true),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'open':
        onOpen();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
        }
      case 'share':
        await SharePlus.instance.share(ShareParams(text: text!));
      case 'remove':
        onRemove();
    }
  }

  void _openSearch() => openBookSearch(context);

  void _showAddBookDialog() {
    showDialog(context: context, builder: (_) => const AddBookDialog());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryController.instance,
      builder: (context, _) {
        final books = LibraryController.instance.books;

        final allBookmarks = <Map<String, dynamic>>[];
        final allQuotes = <Map<String, dynamic>>[];
        final allNotes = <Map<String, dynamic>>[];

        for (final b in books) {
          for (final bm in b.session.state.bookmarks) {
            if (_hidden.contains(bm.id)) continue;
            allBookmarks.add({'book': b, 'bookmark': bm});
          }
          for (final ann in b.session.state.annotations) {
            if (_hidden.contains(ann.id)) continue;
            if (ann.type == AnnotationType.highlight || ann.type == AnnotationType.bookmark) {
              allQuotes.add({'book': b, 'annotation': ann});
            } else {
              allNotes.add({'book': b, 'annotation': ann});
            }
          }
        }
        // Newest first.
        DateTime at(Map<String, dynamic> m) =>
            (m['annotation'] as Annotation?)?.createdAt ?? (m['bookmark'] as Bookmark).createdAt;
        for (final list in [allBookmarks, allQuotes, allNotes]) {
          list.sort((a, b) => at(b).compareTo(at(a)));
        }

        return Scaffold(
          backgroundColor: AppColors.figmaBackground,
          body: Column(
            children: [
              BrowseTopBar(onSearchTap: _openSearch, onAddTap: _showAddBookDialog),
              const SizedBox(height: 5),
              UnderlineTabs(
                labels: [l10n.bookmark, l10n.quotes, l10n.notes],
                selectedIndex: _selectedTab.index,
                onSelected: (i) => _goToTab(SavedTabSection.values[i]),
              ),
              Expanded(
                // Swipe sideways to move between Bookmark / Quotes / Notes.
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) {
                    if (!_jumping) setState(() => _selectedTab = SavedTabSection.values[i]);
                  },
                  children: [
                    _capWidth(_buildBookmarksView(allBookmarks)),
                    _capWidth(_buildQuotesView(allQuotes)),
                    _capWidth(_buildNotesView(allNotes)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Quotes View (saved_page in Figma): serif quote, Sora source title,
  /// hairline dividers between entries.
  /// Lists stay readable on big windows: centered, at most 760 wide.
  Widget _capWidth(Widget list) => context.windowClass.isCompact ? list : MaxWidth(maxWidth: 760, child: list);

  Widget _buildQuotesView(List<Map<String, dynamic>> quotes) {
    if (quotes.isEmpty) {
      return EmptyHint(l10n.noSavedQuotesYetHighlightText);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(22, 12, 21, browseBottomPadding(context, compact: 140)),
      itemCount: quotes.length,
      separatorBuilder: (_, _) => Divider(height: 1, thickness: 1, color: AppColors.figmaDivider),
      itemBuilder: (context, index) {
        final item = quotes[index];
        final BookItem book = item['book'];
        final String quoteText = item['text'] ?? item['annotation']?.textQuote ?? '';
        final String bookTitle = item['title'] ?? book.publication.metadata.title;

        final annotation = item['annotation'] as Annotation;
        void remove() {
          _hide(book, annotation.id);
          _removeAnnotation(book, annotation);
        }

        return KeyedSubtree(
          key: ValueKey('q-${annotation.id}'),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _open(book, annotation.locator),
            onLongPress: () => _showItemMenu(
              title: bookTitle,
              text: quoteText,
              onOpen: () => _open(book, annotation.locator),
              removeLabel: l10n.removeHighlight,
              onRemove: remove,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 0, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quoteText,
                    style: GoogleFonts.amethysta(fontSize: 19, height: 25 / 19, color: AppColors.fg),
                  ),
                  const SizedBox(height: 10),
                  Text(bookTitle, style: GoogleFonts.sora(fontSize: 15, height: 1, color: AppColors.figmaTextFaint)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarksView(List<Map<String, dynamic>> bookmarks) {
    if (bookmarks.isEmpty) {
      return EmptyHint(l10n.noBookmarksSavedTapBookmarkWhile);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final item = bookmarks[index];
        final BookItem book = item['book'];
        final bm = item['bookmark'] as Bookmark;
        void remove() {
          _hide(book, bm.id);
          _removeBookmark(book, bm);
        }

        return KeyedSubtree(
          key: ValueKey('b-${bm.id}'),
          child: ListTile(
            leading: Icon(Icons.bookmark_rounded, color: AppColors.figmaLime),
            title: Text(bm.title, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 15)),
            subtitle: Text(
              book.publication.metadata.title,
              style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 12),
            ),
            onTap: () => _open(book, bm.locator),
            onLongPress: () => _showItemMenu(
              title: bm.title,
              onOpen: () => _open(book, bm.locator),
              removeLabel: l10n.removeBookmark,
              onRemove: remove,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesView(List<Map<String, dynamic>> notes) {
    if (notes.isEmpty) {
      return EmptyHint(l10n.noNotesCreatedYet);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final item = notes[index];
        final BookItem book = item['book'];
        final ann = item['annotation'] as Annotation;
        final note = (ann.note ?? '').trim();
        void remove() {
          _hide(book, ann.id);
          _removeAnnotation(book, ann);
        }

        return KeyedSubtree(
          key: ValueKey('n-${ann.id}'),
          child: ListTile(
            leading: Icon(Icons.note_alt_outlined, color: AppColors.figmaLime),
            title: Text(
              note.isNotEmpty ? note : (ann.textQuote ?? l10n.note),
              style: GoogleFonts.sora(color: AppColors.fg, fontSize: 15),
            ),
            subtitle: Text(
              note.isNotEmpty && (ann.textQuote ?? '').isNotEmpty
                  ? '“${ann.textQuote}” · ${book.publication.metadata.title}'
                  : book.publication.metadata.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 12),
            ),
            onTap: () => _open(book, ann.locator),
            onLongPress: () => _showItemMenu(
              title: book.publication.metadata.title,
              text: note.isNotEmpty ? note : ann.textQuote,
              onOpen: () => _open(book, ann.locator),
              removeLabel: l10n.removeNote,
              onRemove: remove,
            ),
          ),
        );
      },
    );
  }
}
