/// Service interface for parsing EPUB files into Publication domain models.
library;

import 'dart:async';
import '../entities/publication.dart';

abstract class IPublicationParser {
  /// Parses an EPUB publication from file path or byte array.
  Future<Publication> parsePublication(List<int> archiveBytes, {String? filePath});
}
