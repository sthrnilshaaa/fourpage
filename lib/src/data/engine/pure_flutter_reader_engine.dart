/// Engine A — Pure Flutter Reflow Engine wrapping ReadingSession.
library;

import '../../domain/engine/i_reader_engine.dart';
import '../../domain/entities/locator.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/reader_preferences.dart';
import '../../domain/entities/search_match.dart';
import '../../application/commands/reader_command.dart';
import '../../application/session/reading_session.dart';
import '../../application/state/reader_state.dart';

class PureFlutterReaderEngine implements IReaderEngine {
  final ReadingSession _session;

  PureFlutterReaderEngine({ReadingSession? session})
      : _session = session ?? ReadingSession();

  @override
  EngineType get engineType => EngineType.pureFlutter;

  @override
  Stream<ReaderState> get stateStream => _session.stateStream;

  @override
  Future<Publication> open(List<int> archiveBytes) async {
    await _session.dispatchCommand(OpenPublicationCommand(archiveBytes: archiveBytes));
    return _session.state.publication!;
  }

  @override
  Future<void> nextPage() async {
    await _session.dispatchCommand(const NextPageCommand());
  }

  @override
  Future<void> previousPage() async {
    await _session.dispatchCommand(const PreviousPageCommand());
  }

  @override
  Future<void> goTo(Locator locator) async {
    await _session.dispatchCommand(NavigateToLocatorCommand(locator));
  }

  @override
  Future<List<SearchMatch>> search(String query) async {
    await _session.dispatchCommand(ExecuteSearchCommand(query));
    return _session.state.searchResults;
  }

  @override
  Future<void> updatePreferences(ReaderPreferences preferences) async {
    await _session.dispatchCommand(UpdatePreferencesCommand(preferences));
  }


  @override
  Future<void> close() async {
    await _session.close();
  }
}
