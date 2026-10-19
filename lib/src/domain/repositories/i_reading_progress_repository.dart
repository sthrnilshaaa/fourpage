/// Repository interface for persisting reading progress and position locators.
library;

import 'dart:async';
import '../entities/reading_progress.dart';

abstract class IReadingProgressRepository {
  Future<ReadingProgress?> getProgress(String publicationId);
  Future<void> saveProgress(ReadingProgress progress);
}
