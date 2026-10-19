import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../aread.dart';
import '../state/library_controller.dart';
import '../layout/browse_insets.dart';
import '../theme/app_colors.dart';
import '../utils/reader_launcher.dart';
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

  void _openSearch() => openBookSearch(context);

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

        final allBookmarks = <Map<String, dynamic>>[];
        final allQuotes = <Map<String, dynamic>>[];
        final allNotes = <Map<String, dynamic>>[];

        for (final b in books) {
          for (final bm in b.session.state.bookmarks) {
            allBookmarks.add({'book': b, 'bookmark': bm});
          }
          for (final ann in b.session.state.annotations) {
            if (ann.type == AnnotationType.highlight || ann.type == AnnotationType.bookmark) {
              allQuotes.add({'book': b, 'annotation': ann});
            } else {
              allNotes.add({'book': b, 'annotation': ann});
            }
          }
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
                onSelected: (i) => setState(() => _selectedTab = SavedTabSection.values[i]),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_selectedTab),
                    child: switch (_selectedTab) {
                      SavedTabSection.quotes => _buildQuotesView(allQuotes),
                      SavedTabSection.bookmark => _buildBookmarksView(allBookmarks),
                      SavedTabSection.notes => _buildNotesView(allNotes),
                    },
                  ),
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

        final annotation = item['annotation'] as Annotation?;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            LibraryController.instance.setActiveBook(book);
            openReader(context, book, initialLocator: annotation?.locator);
          },
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
                Text(
                  bookTitle,
                  style: GoogleFonts.sora(fontSize: 15, height: 1, color: AppColors.figmaTextFaint),
                ),
              ],
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
        final bm = item['bookmark'];

        return ListTile(
          leading: Icon(Icons.bookmark_rounded, color: AppColors.figmaLime),
          title: Text(bm.title, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 15)),
          subtitle: Text(book.publication.metadata.title, style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 12)),
          onTap: () {
            LibraryController.instance.setActiveBook(book);
            openReader(context, book, initialLocator: bm.locator);
          },
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
        final ann = item['annotation'];

        return ListTile(
          leading: Icon(Icons.note_alt_outlined, color: AppColors.figmaLime),
          title: Text(ann.textQuote ?? l10n.note, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 15)),
          subtitle: Text(book.publication.metadata.title, style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 12)),
          onTap: () {
            LibraryController.instance.setActiveBook(book);
            openReader(context, book, initialLocator: ann.locator);
          },
        );
      },
    );
  }
}
