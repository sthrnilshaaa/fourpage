/// In-memory & storage repository implementation for publications.
library;

import '../../domain/entities/publication.dart';
import '../../domain/repositories/i_publication_repository.dart';

class InMemoryPublicationRepository implements IPublicationRepository {
  final Map<String, Publication> _storage = {};

  InMemoryPublicationRepository([List<Publication>? initial]) {
    if (initial != null) {
      for (final pub in initial) {
        _storage[pub.id] = pub;
      }
    }
  }

  @override
  Future<List<Publication>> getAllPublications() async {
    return _storage.values.toList();
  }

  @override
  Future<Publication?> getPublicationById(String id) async {
    return _storage[id];
  }

  @override
  Future<Publication?> getPublicationByFingerprint(String fingerprint) async {
    for (final pub in _storage.values) {
      if (pub.fingerprint == fingerprint) return pub;
    }
    return null;
  }

  @override
  Future<void> savePublication(Publication publication) async {
    _storage[publication.id] = publication;
  }

  @override
  Future<void> deletePublication(String id) async {
    _storage.remove(id);
  }
}
