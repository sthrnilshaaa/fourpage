/// UseCase for parsing, validating, and opening publications.
library;

import '../../domain/entities/publication.dart';
import '../../domain/repositories/i_publication_repository.dart';
import '../../domain/services/i_publication_parser.dart';

class OpenPublicationUseCase {
  final IPublicationParser _parser;
  final IPublicationRepository _repository;

  OpenPublicationUseCase({
    required IPublicationParser parser,
    required IPublicationRepository repository,
  })  : _parser = parser,
        _repository = repository;

  Future<Publication> execute(List<int> archiveBytes, {String? filePath}) async {
    final publication = await _parser.parsePublication(archiveBytes, filePath: filePath);
    await _repository.savePublication(publication);
    return publication;
  }
}
