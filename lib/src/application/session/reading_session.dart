/// Reading session lifecycle manager coordinating state, navigation, DRM, and persistence.
library;

import 'dart:async';
import '../../data/container/ocf_container.dart';
import '../../data/parsers/epub_parser.dart';
import '../../data/protection/plain_protection_provider.dart';
import '../../data/repositories/in_memory_annotation_repository.dart';
import '../../data/repositories/in_memory_publication_repository.dart';
import '../../data/repositories/in_memory_reader_preferences_repository.dart';
import '../../data/repositories/in_memory_reading_progress_repository.dart';
import '../../data/resolvers/publication_resource_resolver.dart';
import '../../data/search/epub_search_service.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/locator.dart';
import '../../domain/entities/reader_preferences.dart';
import '../../domain/protection/content_protection.dart';

import '../../domain/repositories/i_annotation_repository.dart';
import '../../domain/repositories/i_publication_repository.dart';
import '../../domain/repositories/i_reader_preferences_repository.dart';
import '../../domain/repositories/i_reading_progress_repository.dart';
import '../../domain/services/i_publication_parser.dart';
import '../../domain/services/i_resource_resolver.dart';
import '../../domain/services/i_search_service.dart';
import '../commands/reader_command.dart';
import '../navigator/locator_position_manager.dart';

import '../state/reader_state.dart';
import '../usecases/manage_annotations_usecase.dart';

import '../usecases/navigate_usecase.dart';
import '../usecases/open_publication_usecase.dart';
import '../usecases/search_publication_usecase.dart';
import '../usecases/update_preferences_usecase.dart';

class ReadingSession {
  ReaderState _state = const ReaderState();
  final _stateController = StreamController<ReaderState>.broadcast();

  final IPublicationParser _parser;
  final IPublicationRepository _publicationRepository;
  final IAnnotationRepository _annotationRepository;
  final IReadingProgressRepository _progressRepository;
  final IReaderPreferencesRepository _preferencesRepository;
  final ISearchService _searchService;
  final LocatorPositionManager _positionManager;

  late final OpenPublicationUseCase _openPublicationUseCase;
  late final NavigateUseCase _navigateUseCase;
  late final ManageAnnotationsUseCase _manageAnnotationsUseCase;
  late final SearchPublicationUseCase _searchPublicationUseCase;
  late final UpdatePreferencesUseCase _updatePreferencesUseCase;

  IResourceResolver? _resourceResolver;
  ContentProtection? _protection;
  StreamSubscription? _drmSubscription;

  ReadingSession({
    IPublicationParser? parser,
    IPublicationRepository? publicationRepository,
    IAnnotationRepository? annotationRepository,
    IReadingProgressRepository? progressRepository,
    IReaderPreferencesRepository? preferencesRepository,
    ISearchService? searchService,
    LocatorPositionManager? positionManager,
  })  : _parser = parser ?? EpubPublicationParser(),
        _publicationRepository = publicationRepository ?? InMemoryPublicationRepository(),
        _annotationRepository = annotationRepository ?? InMemoryAnnotationRepository(),
        _progressRepository = progressRepository ?? InMemoryReadingProgressRepository(),
        _preferencesRepository = preferencesRepository ?? InMemoryReaderPreferencesRepository(),
        _searchService = searchService ?? EpubSearchService(),
        _positionManager = positionManager ?? LocatorPositionManager() {
    _openPublicationUseCase = OpenPublicationUseCase(
      parser: _parser,
      repository: _publicationRepository,
    );
    _navigateUseCase = NavigateUseCase(
      positionManager: _positionManager,
      progressRepository: _progressRepository,
    );
    _manageAnnotationsUseCase = ManageAnnotationsUseCase(_annotationRepository);
    _searchPublicationUseCase = SearchPublicationUseCase(_searchService);
    _updatePreferencesUseCase = UpdatePreferencesUseCase(_preferencesRepository);
  }

  ReaderState get state => _state;
  Stream<ReaderState> get stateStream => _stateController.stream;
  IResourceResolver? get resourceResolver => _resourceResolver;

  /// Dispatcher processing immutable commands (Command pattern).
  Future<void> dispatchCommand(ReaderCommand command) async {
    if (command is OpenPublicationCommand) {
      await _handleOpenPublication(command);
    } else if (command is NavigateToLocatorCommand) {
      await _handleNavigateToLocator(command.locator);
    } else if (command is NextPageCommand) {
      await _handleNextPage();
    } else if (command is PreviousPageCommand) {
      await _handlePreviousPage();
    } else if (command is ToggleControlsCommand) {
      _updateState(_state.copyWith(controlsVisible: !_state.controlsVisible));
    } else if (command is CreateAnnotationCommand) {
      await _handleCreateAnnotation(command);
    } else if (command is UpdateAnnotationCommand) {
      await _handleUpdateAnnotation(command.annotation);
    } else if (command is DeleteAnnotationCommand) {
      await _handleDeleteAnnotation(command.annotationId);
    } else if (command is CreateBookmarkCommand) {
      await _handleCreateBookmark(command);
    } else if (command is DeleteBookmarkCommand) {
      await _handleDeleteBookmark(command.bookmarkId);
    } else if (command is ExecuteSearchCommand) {
      await _handleSearch(command.query);
    } else if (command is UpdatePreferencesCommand) {
      await _handleUpdatePreferences(command.preferences);
    } else if (command is AuthenticateDrmCommand) {
      await _handleAuthenticateDrm(command.passphrase);
    }
  }

  Future<void> _handleOpenPublication(OpenPublicationCommand cmd) async {
    _updateState(_state.copyWith(status: ReaderStatus.loading, errorMessage: null));

    try {
      final publication = await _openPublicationUseCase.execute(
        cmd.archiveBytes,
        filePath: cmd.filePath,
      );

      final container = OcfContainer.fromBytes(cmd.archiveBytes);
      _protection = PlainProtectionProvider();
      _resourceResolver = PublicationResourceResolver(
        container: container,
        protection: _protection,
      );

      final prefs = await _updatePreferencesUseCase.getPreferences(publication.id);
      final savedProgress = await _progressRepository.getProgress(publication.id);

      final initialLocator = savedProgress?.locator ??
          Locator(
            href: publication.spine.isNotEmpty ? publication.spine.first.href : '',
            type: publication.spine.isNotEmpty ? publication.spine.first.mediaType : 'application/xhtml+xml',
            title: publication.metadata.title,
            locations: const LocationParameters(progression: 0.0, position: 0, totalProgression: 0.0),
          );

      final annotations = await _manageAnnotationsUseCase.getAnnotations(publication.id);
      final bookmarks = await _manageAnnotationsUseCase.getBookmarks(publication.id);

      _updateState(_state.copyWith(
        status: ReaderStatus.ready,
        publication: publication,
        preferences: prefs,
        annotations: annotations,
        bookmarks: bookmarks,
        drmState: _protection!.currentState,
      ));

      await _handleNavigateToLocator(initialLocator);
    } catch (e) {
      _updateState(_state.copyWith(
        status: ReaderStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _handleNavigateToLocator(Locator locator) async {
    final pub = _state.publication;
    final resolver = _resourceResolver;
    if (pub == null || resolver == null) return;

    try {
      final result = await _navigateUseCase.execute(
        publication: pub,
        targetLocator: locator,
        resolver: resolver,
      );

      final spineIndex = pub.findSpineIndex(result.locator.href);
      final percentage = _positionManager.computePercentage(pub, result.locator);

      _updateState(_state.copyWith(
        currentLocator: result.locator,
        currentSpineIndex: spineIndex != -1 ? spineIndex : 0,
        completionPercentage: percentage,
      ));
    } catch (e) {
      _updateState(_state.copyWith(errorMessage: 'Navigation failed: $e'));
    }
  }

  Future<void> _handleNextPage() async {
    final pub = _state.publication;
    final current = _state.currentLocator;
    if (pub == null || current == null) return;

    final nextLocator = _positionManager.getNextSpineLocator(pub, current);
    if (nextLocator != null) {
      await _handleNavigateToLocator(nextLocator);
    }
  }

  Future<void> _handlePreviousPage() async {
    final pub = _state.publication;
    final current = _state.currentLocator;
    if (pub == null || current == null) return;

    final prevLocator = _positionManager.getPreviousSpineLocator(pub, current);
    if (prevLocator != null) {
      await _handleNavigateToLocator(prevLocator);
    }
  }

  Future<void> _handleCreateAnnotation(CreateAnnotationCommand cmd) async {
    final pub = _state.publication;
    if (pub == null) return;

    final annotation = await _manageAnnotationsUseCase.createAnnotation(
      publicationId: pub.id,
      locator: cmd.locator,
      textQuote: cmd.textQuote,
      note: cmd.note,
      colorHex: cmd.colorHex,
      type: cmd.type,
    );

    final updated = List<Annotation>.from(_state.annotations)..add(annotation);
    _updateState(_state.copyWith(annotations: updated));
  }

  Future<void> _handleUpdateAnnotation(Annotation annotation) async {
    await _annotationRepository.saveAnnotation(annotation);
    final updated = List<Annotation>.from(_state.annotations);
    final i = updated.indexWhere((a) => a.id == annotation.id);
    if (i >= 0) {
      updated[i] = annotation;
    } else {
      updated.add(annotation);
    }
    _updateState(_state.copyWith(annotations: updated));
  }

  Future<void> _handleDeleteAnnotation(String id) async {
    await _manageAnnotationsUseCase.deleteAnnotation(id);
    final updated = List<Annotation>.from(_state.annotations)..removeWhere((a) => a.id == id);
    _updateState(_state.copyWith(annotations: updated));
  }

  Future<void> _handleCreateBookmark(CreateBookmarkCommand cmd) async {
    final pub = _state.publication;
    if (pub == null) return;

    final bookmark = await _manageAnnotationsUseCase.createBookmark(
      publicationId: pub.id,
      locator: cmd.locator,
      title: cmd.title,
    );

    final updated = List<Bookmark>.from(_state.bookmarks)..add(bookmark);
    _updateState(_state.copyWith(bookmarks: updated));
  }

  Future<void> _handleDeleteBookmark(String id) async {
    await _manageAnnotationsUseCase.deleteBookmark(id);
    final updated = List<Bookmark>.from(_state.bookmarks)..removeWhere((b) => b.id == id);
    _updateState(_state.copyWith(bookmarks: updated));
  }

  Future<void> _handleSearch(String query) async {
    final pub = _state.publication;
    final resolver = _resourceResolver;
    if (pub == null || resolver == null) return;

    final matches = await _searchPublicationUseCase.execute(
      publication: pub,
      resolver: resolver,
      query: query,
    );

    _updateState(_state.copyWith(searchResults: matches));
  }

  Future<void> _handleUpdatePreferences(ReaderPreferences prefs) async {
    final pub = _state.publication;
    if (pub == null) return;

    final updated = await _updatePreferencesUseCase.execute(pub.id, prefs);
    _updateState(_state.copyWith(preferences: updated));
  }

  Future<void> _handleAuthenticateDrm(String passphrase) async {
    if (_protection != null) {
      await _protection!.authenticate(passphrase);
      _updateState(_state.copyWith(drmState: _protection!.currentState));
    }
  }

  void _updateState(ReaderState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  Future<void> close() async {
    _drmSubscription?.cancel();
    _stateController.close();
  }
}
