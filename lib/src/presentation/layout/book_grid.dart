import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../state/library_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/book_cover_widget.dart';
import '../widgets/home_skeleton.dart';
import 'book_tap.dart';

/// Columns for a cover grid [width] wide, tiles at least [minTile] wide.
int gridColumnsFor(double width, {double minTile = 150}) => math.max(2, width ~/ (minTile + 16));

/// Cover grid used by Library/Home/Search on medium and expanded windows.
class BookGrid extends StatelessWidget {
  /// Books to show; one still loading with nothing to draw yet is shown as
  /// a placeholder tile (see [BookItem.showsPlaceholder]).
  final List<BookItem> books;
  final BookItem? selected;
  final ValueChanged<BookItem> onOpen;
  final ValueChanged<BookItem>? onSelect;
  final void Function(BookItem book, Offset globalPosition)? onSecondary;
  final EdgeInsets padding;

  /// When false the grid sizes itself to its content (inside another list).
  final bool scrollable;

  /// Builds a sliver for a CustomScrollView, so only the tiles on screen are
  /// built (see [BookGrid.sliver]).
  final bool _sliver;

  const BookGrid({
    super.key,
    required this.books,
    required this.onOpen,
    this.selected,
    this.onSelect,
    this.onSecondary,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
    this.scrollable = true,
  }) : _sliver = false;

  /// The grid as a sliver, for a page that scrolls the grid along with other
  /// content (Home).
  const BookGrid.sliver({
    super.key,
    required this.books,
    required this.onOpen,
    this.selected,
    this.onSelect,
    this.onSecondary,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
  })  : scrollable = false,
        _sliver = true;

  static const _gap = 16.0;
  static const _textBlock = 66.0;

  SliverGridDelegate _delegateFor(double width) {
    final inner = width - padding.horizontal;
    final columns = gridColumnsFor(inner);
    final tileWidth = (inner - _gap * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: _gap,
      mainAxisSpacing: 22,
      mainAxisExtent: tileWidth * 1.5 + _textBlock,
    );
  }

  Widget _item(BuildContext context, int i) {
    final book = books[i];
    return book.showsPlaceholder ? const BookTileSkeleton() : _tile(book);
  }

  @override
  Widget build(BuildContext context) {
    if (_sliver) {
      return SliverLayoutBuilder(
        builder: (context, constraints) => SliverPadding(
          padding: padding,
          sliver: SliverGrid.builder(
            gridDelegate: _delegateFor(constraints.crossAxisExtent),
            itemCount: books.length,
            itemBuilder: _item,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: padding,
        shrinkWrap: !scrollable,
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        gridDelegate: _delegateFor(constraints.maxWidth),
        itemCount: books.length,
        itemBuilder: _item,
      ),
    );
  }

  Widget _tile(BookItem book) {
    final isSelected = selected != null && selected!.publication.id == book.publication.id;
    final select = onSelect;
    final secondary = onSecondary;
    final meta = book.publication.metadata;
    return BookTapHandler(
      onOpen: () => onOpen(book),
      onSelect: select == null ? null : () => select(book),
      onSecondary: secondary == null ? null : (p) => secondary(book, p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? AppColors.figmaLime : Colors.transparent, width: 2),
              ),
              padding: const EdgeInsets.all(2),
              child: SizedBox.expand(
                child: BookCoverWidget(book: book, layoutMode: CoverLayoutMode.coverOnly, coverRadius: 5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            meta.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.fg),
          ),
          const SizedBox(height: 3),
          Text(
            meta.authors.isNotEmpty ? meta.authors.first : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 11.5, color: AppColors.figmaTextFaint),
          ),
          const SizedBox(height: 9),
          ThinProgressBar(value: book.progress),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
