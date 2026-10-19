/// UseCase for reading and updating reader settings and preferences (per publication).
library;

import '../../domain/entities/reader_preferences.dart';
import '../../domain/repositories/i_reader_preferences_repository.dart';

class UpdatePreferencesUseCase {
  final IReaderPreferencesRepository _repository;

  UpdatePreferencesUseCase(this._repository);

  Future<ReaderPreferences> getPreferences(String publicationId) async {
    return _repository.getPreferences(publicationId);
  }

  Future<ReaderPreferences> execute(String publicationId, ReaderPreferences newPreferences) async {
    await _repository.savePreferences(publicationId, newPreferences);
    return newPreferences;
  }
}
