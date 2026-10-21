/// Remove highlights, notes and bookmarks with an Undo bar, the same way in
/// the reader, its Chapters & Notes sheet and the Saved screen.
library;

import 'package:flutter/material.dart';

import '../../../aread.dart';
import '../../../l10n/l10n.dart';
import '../state/library_controller.dart';
import '../theme/app_colors.dart';

/// False once the book was removed from the library: Undo must not write its rows back.
bool _inLibrary(ReadingSession session) => LibraryController.instance.books.any((b) => identical(b.session, session));

/// Shows [text] with an Undo button. [onUndo] runs at most once.
void showUndoSnackBar(ScaffoldMessengerState messenger, String text, Future<void> Function() onUndo) {
  var undone = false;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        persist: false,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.undo,
          textColor: AppColors.accentLime,
          onPressed: () {
            if (undone) return;
            undone = true;
            onUndo().catchError((Object e) => debugPrint('Undo failed: $e'));
          },
        ),
      ),
    );
}

/// Deletes [annotation]; Undo puts the same one back (same id, note and colour).
Future<void> removeAnnotationWithUndo(
  ScaffoldMessengerState messenger,
  ReadingSession session,
  Annotation annotation, {
  Future<void> Function()? onChanged,
}) async {
  await session.dispatchCommand(DeleteAnnotationCommand(annotation.id));
  await onChanged?.call();
  final isNote = (annotation.note ?? '').isNotEmpty;
  showUndoSnackBar(messenger, isNote ? l10n.noteRemoved : l10n.highlightRemoved, () async {
    if (!_inLibrary(session)) return;
    await session.dispatchCommand(UpdateAnnotationCommand(annotation));
    await onChanged?.call();
  });
}

/// Deletes [bookmark]; Undo puts the same one back.
Future<void> removeBookmarkWithUndo(
  ScaffoldMessengerState messenger,
  ReadingSession session,
  Bookmark bookmark, {
  Future<void> Function()? onChanged,
}) async {
  await session.dispatchCommand(DeleteBookmarkCommand(bookmark.id));
  await onChanged?.call();
  showUndoSnackBar(messenger, l10n.bookmarkRemoved, () async {
    if (!_inLibrary(session)) return;
    await session.dispatchCommand(RestoreBookmarkCommand(bookmark));
    await onChanged?.call();
  });
}
