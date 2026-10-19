/// UseCase for executing full-text search across a publication.
library;

import '../../domain/entities/publication.dart';
import '../../domain/entities/search_match.dart';
import '../../domain/services/i_resource_resolver.dart';
import '../../domain/services/i_search_service.dart';

class SearchPublicationUseCase {
  final ISearchService _searchService;

  SearchPublicationUseCase(this._searchService);

  Future<List<SearchMatch>> execute({
    required Publication publication,
    required IResourceResolver resolver,
    required String query,
  }) async {
    return _searchService.search(
      publication: publication,
      resolver: resolver,
      query: query,
    );
  }
}
