import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n.dart';
import '../state/library_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/book_cover_widget.dart';

/// Which book the details pane shows: the selection while it is still in
/// [books], else the most recently read book still in [books], else none.
BookItem? resolveDetailsBook(BookItem? selected, List<BookItem> books, {List<BookItem> recent = const []}) {
  bool inLibrary(BookItem b) => books.any((x) => x.publication.id == b.publication.id);
  if (selected != null && inLibrary(selected)) return selected;
  for (final b in recent) {
    if (inLibrary(b)) return b;
  }
  return null;
}

/// Right-hand pane on expanded Library/Home: the selected book's details.
class BookDetailsPane extends StatelessWidget {
  final BookItem? book;
  final VoidCallback? onOpen;
  final VoidCallback? onMoveToShelf;
  final String? shelfName;

  static const width = 320.0;

  const BookDetailsPane({super.key, required this.book, required this.onOpen, this.onMoveToShelf, this.shelfName});

  @override
  Widget build(BuildContext context) {
    final b = book;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.figmaSurface,
        border: Border(left: BorderSide(color: AppColors.dividerSubtle)),
      ),
      child: b == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.noBookSelected,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 13, color: AppColors.figmaTextFaint),
                ),
              ),
            )
          : _details(b),
    );
  }

  Widget _details(BookItem b) {
    final meta = b.publication.metadata;
    final percent = (b.progress * 100).round();
    return SafeArea(
      left: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        children: [
          Center(
            child: SizedBox(
              width: 150,
              height: 225,
              child: BookCoverWidget(book: b, layoutMode: CoverLayoutMode.coverOnly, coverRadius: 6, showFormatBadge: true),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            meta.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3, color: AppColors.fg),
          ),
          const SizedBox(height: 6),
          Text(
            meta.authors.isNotEmpty ? meta.authors.join(', ') : l10n.unknownAuthor,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 13, color: AppColors.figmaTextFaint),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              FormatBadge(format: b.format),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shelfName ?? l10n.notOnAShelf,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 12, color: AppColors.figmaTextFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ThinProgressBar(value: b.progress),
          const SizedBox(height: 8),
          Text(l10n.percentRead(percent), style: GoogleFonts.sora(fontSize: 12, color: AppColors.figmaTextFaint)),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.figmaLime,
              foregroundColor: AppColors.figmaBackground,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
              textStyle: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text(l10n.continueReading),
          ),
          if (onMoveToShelf != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onMoveToShelf,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.fg,
                side: BorderSide(color: AppColors.borderDark),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                textStyle: GoogleFonts.sora(fontSize: 13),
              ),
              child: Text(l10n.moveToShelf),
            ),
          ],
        ],
      ),
    );
  }
}
