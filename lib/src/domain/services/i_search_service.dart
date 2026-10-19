/// Service interface for full-text search across publication spine items.
library;

import 'dart:async';
import '../entities/publication.dart';
import '../entities/search_match.dart';
import 'i_resource_resolver.dart';

abstract class ISearchService {
  /// Executes search query across the publication spine resources.
  Future<List<SearchMatch>> search({
    required Publication publication,
    required IResourceResolver resolver,
    required String query,
  });
}
