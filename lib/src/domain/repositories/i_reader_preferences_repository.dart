/// Repository interface for persisting reader typography and theme settings.
///
/// Preferences are scoped per publication: each book remembers its own
/// font, size, theme, and layout choices.
library;

import 'dart:async';
import '../entities/reader_preferences.dart';

abstract class IReaderPreferencesRepository {
  Future<ReaderPreferences> getPreferences(String publicationId);
  Future<void> savePreferences(String publicationId, ReaderPreferences preferences);
}
