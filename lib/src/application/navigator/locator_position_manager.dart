/// Manager for current active reading position, page calculations, and navigation.
library;

import '../../domain/entities/locator.dart';
import '../../domain/entities/publication.dart';

class LocatorPositionManager {
  LocatorPositionManager();

  /// Calculates next spine locator.
  Locator? getNextSpineLocator(Publication publication, Locator current) {
    final currentIndex = publication.findSpineIndex(current.href);
    if (currentIndex == -1 || currentIndex >= publication.spine.length - 1) {
      return null;
    }
    final nextItem = publication.spine[currentIndex + 1];
    final nextIndex = currentIndex + 1;
    final totalProgression = (nextIndex) / publication.spine.length;

    return Locator(
      href: nextItem.href,
      type: nextItem.mediaType,
      title: publication.metadata.title,
      locations: LocationParameters(
        progression: 0.0,
        position: nextIndex,
        totalProgression: totalProgression,
      ),
    );
  }

  /// Calculates previous spine locator.
  Locator? getPreviousSpineLocator(Publication publication, Locator current) {
    final currentIndex = publication.findSpineIndex(current.href);
    if (currentIndex <= 0) {
      return null;
    }
    final prevItem = publication.spine[currentIndex - 1];
    final prevIndex = currentIndex - 1;
    final totalProgression = (prevIndex) / publication.spine.length;

    return Locator(
      href: prevItem.href,
      type: prevItem.mediaType,
      title: publication.metadata.title,
      locations: LocationParameters(
        progression: 0.0,
        position: prevIndex,
        totalProgression: totalProgression,
      ),
    );
  }

  /// Computes overall publication completion percentage [0.0 - 100.0].
  double computePercentage(Publication publication, Locator locator) {
    final totalProg = locator.locations.totalProgression;
    if (totalProg != null) {
      return (totalProg * 100.0).clamp(0.0, 100.0);
    }
    final spineIndex = publication.findSpineIndex(locator.href);
    if (spineIndex != -1 && publication.spine.isNotEmpty) {
      return ((spineIndex / publication.spine.length) * 100.0).clamp(0.0, 100.0);
    }
    return 0.0;
  }
}
