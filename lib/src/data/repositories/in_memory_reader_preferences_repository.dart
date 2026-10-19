/// In-memory repository implementation for user reader preferences.
library;

import '../../domain/entities/reader_preferences.dart';
import '../../domain/repositories/i_reader_preferences_repository.dart';

class InMemoryReaderPreferencesRepository implements IReaderPreferencesRepository {
  final Map<String, ReaderPreferences> _preferences;

  InMemoryReaderPreferencesRepository([Map<String, ReaderPreferences>? initial])
      : _preferences = initial ?? {};

  @override
  Future<ReaderPreferences> getPreferences(String publicationId) async {
    return _preferences[publicationId] ?? const ReaderPreferences();
  }

  @override
  Future<void> savePreferences(String publicationId, ReaderPreferences preferences) async {
    _preferences[publicationId] = preferences;
  }
}
