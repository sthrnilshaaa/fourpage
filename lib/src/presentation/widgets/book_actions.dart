/// Book-level actions shown from a book's long-press menu: info, share and
/// remove from library.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/l10n.dart';
import '../layout/adaptive_sheet.dart';
import '../state/library_controller.dart';
import '../theme/app_colors.dart';
import 'app_chrome.dart';
import 'book_cover_widget.dart';

LibraryController get _lib => LibraryController.instance;

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// The book's stored file, written out first when only its bytes are kept.
Future<File> _bookFile(BookItem book) async {
  final id = book.publication.id;
  if (!book.isPdf && book.archiveBytes.isNotEmpty) return _lib.ensureBookFileOnDisk(id, book.archiveBytes);
  return _lib.getBookFile(id, kind: book.kind);
}

/// "1.4 MB" style size.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${units[unit]}';
}

/// File names can't hold these characters on common file systems.
String safeFileName(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return 'book';
  return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
}

/// Shares the book file through the system share sheet, named after its title.
Future<void> shareBookFile(BuildContext context, BookItem book) async {
  try {
    final source = await _bookFile(book);
    if (!await source.exists()) throw const FileSystemException('Book file missing');
    final ext = book.isPdf ? 'pdf' : 'epub';
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    if (!await dir.exists()) await dir.create(recursive: true);
    final named = await source.copy('${dir.path}/${safeFileName(book.publication.metadata.title)}.$ext');
    await SharePlus.instance.share(ShareParams(
      files: [XFile(named.path, mimeType: book.isPdf ? 'application/pdf' : 'application/epub+zip')],
      subject: book.publication.metadata.title,
    ));
  } catch (e) {
    debugPrint('Share book: $e');
    if (context.mounted) _snack(context, l10n.couldNotShareBook);
  }
}

/// Asks first, then removes [book] from the library.
Future<bool> confirmRemoveBook(BuildContext context, BookItem book) async {
  final title = book.publication.metadata.title;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.sheetSurface,
      title: Text(l10n.removeFromLibrary, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
      content: Text(
        l10n.removeFromLibraryBody(title),
        style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14, height: 1.45),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: Text(l10n.remove),
        ),
      ],
    ),
  );
  if (confirm != true) return false;
  await _lib.deleteBook(book.publication.id);
  if (context.mounted) _snack(context, l10n.removedFromLibrary(title));
  return true;
}

/// Sheet with the book's cover and everything known about it.
Future<void> showBookInfoSheet(BuildContext context, BookItem book) {
  return showAdaptiveSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.sheetSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
      child: SafeArea(top: false, child: _BookInfo(book: book)),
    ),
  );
}

class _BookInfo extends StatelessWidget {
  final BookItem book;
  const _BookInfo({required this.book});

  @override
  Widget build(BuildContext context) {
    final meta = book.publication.metadata;
    final shelf = _lib.shelfOf(book);
    final description = _plainText(meta.description);
    final label = GoogleFonts.sora(fontSize: 12, color: AppColors.figmaTextFaint);
    final value = GoogleFonts.sora(fontSize: 13.5, color: AppColors.fg, height: 1.4);

    Widget row(String name, String? text) {
      if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: Text(name, style: label)),
            Expanded(child: SelectableText(text.trim(), style: value)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                height: 126,
                child: BookCoverWidget(book: book, layoutMode: CoverLayoutMode.coverOnly, coverRadius: 4),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      meta.title,
                      style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, color: AppColors.fg),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta.authors.isNotEmpty ? meta.authors.join(', ') : l10n.unknownAuthor,
                      style: GoogleFonts.sora(fontSize: 13, color: AppColors.figmaTextFaint),
                    ),
                    const SizedBox(height: 14),
                    ThinProgressBar(value: book.progress),
                    const SizedBox(height: 6),
                    Text(l10n.percentRead((book.progress * 100).round()), style: label),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          row(l10n.bookInfoPublisher, meta.publisher),
          row(l10n.bookInfoPublished, meta.publicationDate),
          row(l10n.bookInfoLanguage, meta.language),
          row(l10n.bookInfoFormat, book.format),
          FutureBuilder<int?>(
            future: _fileSize(),
            builder: (context, snap) => row(l10n.bookInfoFileSize, snap.data == null ? null : formatFileSize(snap.data!)),
          ),
          row(l10n.bookInfoShelf, shelf?.name ?? l10n.notOnAShelf),
          row(l10n.bookInfoSubjects, meta.subjects.isEmpty ? null : meta.subjects.join(', ')),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(l10n.bookInfoDescription, style: label),
            const SizedBox(height: 8),
            SelectableText(description, style: value),
          ],
        ],
      ),
    );
  }

  Future<int?> _fileSize() async {
    try {
      final file = await _lib.getBookFile(book.publication.id, kind: book.kind);
      if (await file.exists()) return await file.length();
      return book.archiveBytes.isEmpty ? null : book.archiveBytes.length;
    } catch (_) {
      return null;
    }
  }

  /// EPUB descriptions are often HTML; show them as plain text.
  static String? _plainText(String? html) {
    if (html == null) return null;
    final text = html
        .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text.isEmpty ? null : text;
  }
}
