/// Command pattern representation for all user actions (Section 24 of specification).
library;

import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/locator.dart';
import '../../domain/entities/reader_preferences.dart';

abstract class ReaderCommand {
  const ReaderCommand();
}

class OpenPublicationCommand extends ReaderCommand {
  final List<int> archiveBytes;
  final String? filePath;

  const OpenPublicationCommand({required this.archiveBytes, this.filePath});
}

class NavigateToLocatorCommand extends ReaderCommand {
  final Locator locator;
  const NavigateToLocatorCommand(this.locator);
}

class NextPageCommand extends ReaderCommand {
  const NextPageCommand();
}

class PreviousPageCommand extends ReaderCommand {
  const PreviousPageCommand();
}

class ToggleControlsCommand extends ReaderCommand {
  const ToggleControlsCommand();
}

class CreateAnnotationCommand extends ReaderCommand {
  final Locator locator;
  final String? textQuote;
  final String? note;
  final String colorHex;
  final AnnotationType type;

  const CreateAnnotationCommand({
    required this.locator,
    this.textQuote,
    this.note,
    this.colorHex = '#FFD54F',
    this.type = AnnotationType.highlight,
  });
}

/// Replaces a saved annotation (same id): a colour change, or a migrated position.
class UpdateAnnotationCommand extends ReaderCommand {
  final Annotation annotation;
  const UpdateAnnotationCommand(this.annotation);
}

class DeleteAnnotationCommand extends ReaderCommand {
  final String annotationId;
  const DeleteAnnotationCommand(this.annotationId);
}

class CreateBookmarkCommand extends ReaderCommand {
  final Locator locator;
  final String title;

  const CreateBookmarkCommand({required this.locator, required this.title});
}

class DeleteBookmarkCommand extends ReaderCommand {
  final String bookmarkId;
  const DeleteBookmarkCommand(this.bookmarkId);
}

/// Puts a removed bookmark back as it was (same id), for Undo.
class RestoreBookmarkCommand extends ReaderCommand {
  final Bookmark bookmark;
  const RestoreBookmarkCommand(this.bookmark);
}

class ExecuteSearchCommand extends ReaderCommand {
  final String query;
  const ExecuteSearchCommand(this.query);
}

class UpdatePreferencesCommand extends ReaderCommand {
  final ReaderPreferences preferences;
  const UpdatePreferencesCommand(this.preferences);
}

class AuthenticateDrmCommand extends ReaderCommand {
  final String passphrase;
  const AuthenticateDrmCommand(this.passphrase);
}
