/// In-memory repository implementation for persistent reading progress.
library;

import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/i_reading_progress_repository.dart';

class InMemoryReadingProgressRepository implements IReadingProgressRepository {
  final Map<String, ReadingProgress> _storage = {};

  @override
  Future<ReadingProgress?> getProgress(String publicationId) async {
    return _storage[publicationId];
  }

  @override
  Future<void> saveProgress(ReadingProgress progress) async {
    _storage[progress.publicationId] = progress;
  }
}
