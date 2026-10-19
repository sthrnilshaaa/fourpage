/// Repository interface for managing publication metadata and library storage.
library;

import 'dart:async';
import '../entities/publication.dart';

abstract class IPublicationRepository {
  Future<List<Publication>> getAllPublications();
  Future<Publication?> getPublicationById(String id);
  Future<Publication?> getPublicationByFingerprint(String fingerprint);
  Future<void> savePublication(Publication publication);
  Future<void> deletePublication(String id);
}
