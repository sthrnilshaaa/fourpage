/// Book Import Controller orchestrating file selection, validation, parsing, and database persistence.
library;

import '../../data/parsers/epub_parser.dart';

import '../../domain/entities/publication.dart';
import '../../domain/repositories/i_publication_repository.dart';
import '../../domain/source/book_source.dart';
import '../../domain/validation/epub_validator.dart';
import '../usecases/open_publication_usecase.dart';

class BookImporterResult {
  final Publication? publication;
  final ValidationResult validationResult;

  bool get isSuccess => publication != null && validationResult.isValid;

  const BookImporterResult({
    this.publication,
    required this.validationResult,
  });
}

class BookImporter {
  final EpubValidator _validator;
  final EpubPublicationParser _parser;
  final IPublicationRepository _repository;

  BookImporter({
    EpubValidator? validator,
    EpubPublicationParser? parser,
    required IPublicationRepository repository,
  })  : _validator = validator ?? const EpubValidator(),
        _parser = parser ?? EpubPublicationParser(),
        _repository = repository;

  /// Imports an EPUB publication from any BookSource (File, Android Content URI, or Memory bytes).
  Future<BookImporterResult> importBook(BookSource source) async {
    // 1. Validate EPUB container and package document
    final validation = await _validator.validate(source);
    if (!validation.isValid) {
      return BookImporterResult(validationResult: validation);
    }

    // 2. Parse EPUB publication model
    final bytes = await source.readBytes();
    final openUseCase = OpenPublicationUseCase(parser: _parser, repository: _repository);
    final publication = await openUseCase.execute(bytes);

    return BookImporterResult(
      publication: publication,
      validationResult: validation,
    );
  }
}
