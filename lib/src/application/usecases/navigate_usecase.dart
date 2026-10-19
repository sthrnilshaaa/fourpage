/// UseCase for performing locator restoration and saving reading progress.
library;

import '../../domain/entities/locator.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/i_reading_progress_repository.dart';
import '../../domain/services/i_resource_resolver.dart';
import '../navigator/locator_position_manager.dart';
import '../navigator/position_restoration_strategy.dart';

class NavigateUseCase {
  final PositionRestorationStrategy _restorationStrategy;
  final LocatorPositionManager _positionManager;
  final IReadingProgressRepository _progressRepository;

  NavigateUseCase({
    PositionRestorationStrategy? restorationStrategy,
    LocatorPositionManager? positionManager,
    required IReadingProgressRepository progressRepository,
  })  : _restorationStrategy = restorationStrategy ?? PositionRestorationStrategy(),
        _positionManager = positionManager ?? LocatorPositionManager(),
        _progressRepository = progressRepository;

  Future<PositionRestorationResult> execute({
    required Publication publication,
    required Locator targetLocator,
    required IResourceResolver resolver,
  }) async {
    final result = await _restorationStrategy.restorePosition(
      publication: publication,
      targetLocator: targetLocator,
      resolver: resolver,
    );

    final percentage = _positionManager.computePercentage(publication, result.locator);

    final progress = ReadingProgress(
      publicationId: publication.id,
      locator: result.locator,
      percentage: percentage,
      lastReadAt: DateTime.now(),
    );

    await _progressRepository.saveProgress(progress);
    return result;
  }
}
