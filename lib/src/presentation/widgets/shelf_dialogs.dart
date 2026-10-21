/// Dialogs and sheets for managing shelves, shared by Library › Shelves and
/// Settings › Shelves.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n.dart';
import '../state/library_controller.dart';
import '../state/shelves.dart';
import '../layout/adaptive_sheet.dart';
import '../theme/app_colors.dart';
import 'book_actions.dart';
import 'book_cover_widget.dart';

LibraryController get _lib => LibraryController.instance;

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// Asks for a name and creates a shelf. When [withBook] is given the book
/// is moved onto the new shelf.
Future<Shelf?> showCreateShelfDialog(BuildContext context, {BookItem? withBook}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _ShelfNameDialog(title: l10n.newShelf, action: l10n.create),
  );
  if (name == null || !context.mounted) return null;
  final shelf = _lib.createShelf(name);
  if (withBook != null) {
    _lib.moveBookToShelf(withBook, shelf);
    _snack(context, l10n.movedToShelf(shelf.name));
  } else {
    _snack(context, l10n.shelfCreated(shelf.name));
  }
  return shelf;
}

Future<void> showRenameShelfDialog(BuildContext context, Shelf shelf) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _ShelfNameDialog(
      title: l10n.renameShelf,
      action: l10n.save,
      initial: shelf.name,
      shelfId: shelf.id,
    ),
  );
  if (name != null && name != shelf.name) _lib.renameShelf(shelf, name);
}

Future<void> confirmDeleteShelf(BuildContext context, Shelf shelf) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.sheetSurface,
      title: Text(l10n.deleteShelf, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
      content: Text(
        l10n.deleteShelfBody(shelf.name),
        style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14, height: 1.45),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (confirm == true) _lib.deleteShelf(shelf);
}

/// ⋮ menu on a shelf: add books, rename, delete.
Future<void> showShelfOptionsSheet(BuildContext context, Shelf shelf) async {
  final action = await _showSheet<String>(
    context,
    title: shelf.name,
    children: (pop) => [
      _sheetTile(Icons.library_add_outlined, l10n.addBooks, () => pop('add')),
      _sheetTile(Icons.drive_file_rename_outline_rounded, l10n.renameShelf, () => pop('rename')),
      _sheetTile(Icons.delete_outline_rounded, l10n.deleteShelf, () => pop('delete'), danger: true),
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case 'add':
      await showAddBooksToShelfSheet(context, shelf);
    case 'rename':
      await showRenameShelfDialog(context, shelf);
    case 'delete':
      await confirmDeleteShelf(context, shelf);
  }
}

/// Picks a shelf for [book] (or a new one, or none).
Future<void> showMoveToShelfSheet(BuildContext context, BookItem book) async {
  final current = _lib.shelfOf(book);
  const newShelf = '\u0000new';
  const unshelve = '\u0000none';
  final picked = await _showSheet<String>(
    context,
    title: l10n.moveToShelf,
    children: (pop) => [
      for (final shelf in _lib.shelves)
        _sheetTile(
          Icons.shelves,
          shelf.name,
          () => pop(shelf.id),
          selected: shelf.id == current?.id,
          trailingText: '${_lib.booksOnShelf(shelf).length}',
        ),
      _sheetTile(Icons.add_rounded, l10n.newShelf, () => pop(newShelf), accent: true),
      if (current != null) _sheetTile(Icons.remove_circle_outline_rounded, l10n.removeFromShelf, () => pop(unshelve)),
    ],
  );
  if (picked == null || !context.mounted) return;
  if (picked == newShelf) {
    await showCreateShelfDialog(context, withBook: book);
  } else if (picked == unshelve) {
    _lib.moveBookToShelf(book, null);
    _snack(context, l10n.removedFromShelf(current!.name));
  } else if (picked != current?.id) {
    final shelf = _lib.shelves.where((s) => s.id == picked).firstOrNull;
    if (shelf == null) return; // deleted meanwhile
    _lib.moveBookToShelf(book, shelf);
    _snack(context, l10n.movedToShelf(shelf.name));
  }
}

/// Long-press (or right-click) menu on any book: open, details, shelf,
/// share and remove from library.
Future<void> showBookActions(BuildContext context, BookItem book, {required VoidCallback onOpen}) async {
  final current = _lib.shelfOf(book);
  final action = await _showSheet<String>(
    context,
    title: book.publication.metadata.title,
    children: (pop) => [
      _sheetTile(Icons.menu_book_rounded, l10n.openBook, () => pop('open')),
      _sheetTile(Icons.info_outline_rounded, l10n.aboutThisBook, () => pop('info')),
      _sheetTile(Icons.drive_file_move_outline, l10n.moveToShelf, () => pop('move')),
      if (current != null) _sheetTile(Icons.remove_circle_outline_rounded, l10n.removeFromShelf, () => pop('unshelve')),
      _sheetTile(Icons.ios_share_rounded, l10n.shareBookFile, () => pop('share')),
      _sheetTile(Icons.delete_outline_rounded, l10n.removeFromLibrary, () => pop('delete'), danger: true),
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case 'open':
      onOpen();
    case 'info':
      await showBookInfoSheet(context, book);
    case 'move':
      await showMoveToShelfSheet(context, book);
    case 'unshelve':
      _lib.moveBookToShelf(book, null);
      _snack(context, l10n.removedFromShelf(current!.name));
    case 'share':
      await shareBookFile(context, book);
    case 'delete':
      await confirmRemoveBook(context, book);
  }
}

/// Checklist of books not yet on [shelf]; ticked ones are moved onto it.
Future<void> showAddBooksToShelfSheet(BuildContext context, Shelf shelf) async {
  final candidates = _lib.books.where((b) => _lib.shelfOf(b)?.id != shelf.id).toList();
  if (candidates.isEmpty) {
    _snack(context, l10n.noBooksToAdd);
    return;
  }
  final picked = await showAdaptiveSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.sheetSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AddBooksSheet(shelf: shelf, books: candidates),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  for (final book in candidates) {
    if (picked.contains(book.publication.id)) _lib.moveBookToShelf(book, shelf);
  }
  _snack(context, l10n.movedToShelf(shelf.name));
}

// --- building blocks -----------------------------------------------------------

Future<T?> _showSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> Function(void Function(T) pop) children,
}) {
  return showAdaptiveSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.sheetSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
        child: SingleChildScrollView(
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
              ...children((value) => Navigator.of(sheetContext).pop(value)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _sheetTile(
  IconData icon,
  String label,
  VoidCallback onTap, {
  bool danger = false,
  bool accent = false,
  bool selected = false,
  String? trailingText,
}) {
  final color = danger ? Colors.redAccent : (accent ? AppColors.accentLime : AppColors.fg);
  return ListTile(
    leading: Icon(icon, color: danger ? Colors.redAccent : (accent ? AppColors.accentLime : AppColors.fgMuted)),
    title: Text(label, style: GoogleFonts.sora(fontSize: 15, color: color)),
    trailing: selected
        ? Icon(Icons.check_rounded, color: AppColors.accentLime)
        : (trailingText != null
            ? Text(trailingText, style: GoogleFonts.sora(fontSize: 13, color: AppColors.fgSubtle))
            : null),
    onTap: onTap,
  );
}

class _ShelfNameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String? initial;
  final String? shelfId;
  const _ShelfNameDialog({required this.title, required this.action, this.initial, this.shelfId});

  @override
  State<_ShelfNameDialog> createState() => _ShelfNameDialogState();
}

class _ShelfNameDialogState extends State<_ShelfNameDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    if (LibraryController.instance.shelfNameTaken(name, exceptId: widget.shelfId)) {
      setState(() => _error = l10n.shelfNameTaken);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.sheetSurface,
      title: Text(widget.title, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.sora(color: AppColors.fg, fontSize: 15),
        cursorColor: AppColors.accentLime,
        decoration: InputDecoration(
          hintText: l10n.shelfName,
          hintStyle: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 15),
          errorText: _error,
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentLime)),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
          setState(() {});
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        TextButton(
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

class _AddBooksSheet extends StatefulWidget {
  final Shelf shelf;
  final List<BookItem> books;
  const _AddBooksSheet({required this.shelf, required this.books});

  @override
  State<_AddBooksSheet> createState() => _AddBooksSheetState();
}

class _AddBooksSheetState extends State<_AddBooksSheet> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.addBooksToShelf(widget.shelf.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 16, color: AppColors.fg, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _picked.isEmpty ? null : () => Navigator.of(context).pop(_picked),
                    child: Text(_picked.isEmpty ? l10n.done : l10n.doneWithCount(_picked.length)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                itemCount: widget.books.length,
                itemBuilder: (context, i) {
                  final book = widget.books[i];
                  final id = book.publication.id;
                  final onShelf = LibraryController.instance.shelfOf(book);
                  return CheckboxListTile(
                    value: _picked.contains(id),
                    activeColor: AppColors.accentLime,
                    checkColor: Colors.black,
                    onChanged: (v) => setState(() => v == true ? _picked.add(id) : _picked.remove(id)),
                    secondary: SizedBox(
                      width: 34,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: BookCoverWidget(
                          book: book,
                          layoutMode: CoverLayoutMode.coverOnly,
                          coverRadius: 2,
                          showFormatBadge: false,
                        ),
                      ),
                    ),
                    title: Text(
                      book.publication.metadata.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 14, color: AppColors.fg),
                    ),
                    subtitle: Text(
                      onShelf?.name ?? l10n.unshelved,
                      style: GoogleFonts.sora(fontSize: 12, color: AppColors.fgSubtle),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
