/// Immutable reader state tree.
library;

import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/locator.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/reader_preferences.dart';
import '../../domain/entities/search_match.dart';
import '../../domain/protection/drm_state.dart';

enum ReaderStatus { initial, loading, ready, error }

class ReaderState {
  final ReaderStatus status;
  final Publication? publication;
  final Locator? currentLocator;
  final int currentSpineIndex;
  final double completionPercentage;
  final ReaderPreferences preferences;
  final List<Annotation> annotations;
  final List<Bookmark> bookmarks;
  final List<SearchMatch> searchResults;
  final DrmState drmState;
  final bool controlsVisible;
  final String? errorMessage;

  const ReaderState({
    this.status = ReaderStatus.initial,
    this.publication,
    this.currentLocator,
    this.currentSpineIndex = 0,
    this.completionPercentage = 0.0,
    this.preferences = const ReaderPreferences(),
    this.annotations = const [],
    this.bookmarks = const [],
    this.searchResults = const [],
    this.drmState = const DrmState(status: DrmStatus.unknown),
    this.controlsVisible = true,
    this.errorMessage,
  });

  ReaderState copyWith({
    ReaderStatus? status,
    Publication? publication,
    Locator? currentLocator,
    int? currentSpineIndex,
    double? completionPercentage,
    ReaderPreferences? preferences,
    List<Annotation>? annotations,
    List<Bookmark>? bookmarks,
    List<SearchMatch>? searchResults,
    DrmState? drmState,
    bool? controlsVisible,
    String? errorMessage,
  }) {
    return ReaderState(
      status: status ?? this.status,
      publication: publication ?? this.publication,
      currentLocator: currentLocator ?? this.currentLocator,
      currentSpineIndex: currentSpineIndex ?? this.currentSpineIndex,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      preferences: preferences ?? this.preferences,
      annotations: annotations ?? this.annotations,
      bookmarks: bookmarks ?? this.bookmarks,
      searchResults: searchResults ?? this.searchResults,
      drmState: drmState ?? this.drmState,
      controlsVisible: controlsVisible ?? this.controlsVisible,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'ReaderState(status: $status, spine: $currentSpineIndex, progress: ${completionPercentage.toStringAsFixed(1)}%, drm: ${drmState.status})';
}
