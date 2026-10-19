/// Implementation of the hierarchical position restoration algorithm (Section 15 of specification).
library;

import '../../domain/entities/locator.dart';
import '../../domain/entities/publication.dart';
import '../../domain/services/i_resource_resolver.dart';

class PositionRestorationResult {
  final Locator locator;
  final String restorationStepName;
  final bool isExact;

  const PositionRestorationResult({
    required this.locator,
    required this.restorationStepName,
    required this.isExact,
  });
}

class PositionRestorationStrategy {
  PositionRestorationStrategy();

  /// Hierarchical fallback algorithm:
  /// 1. Exact fragment anchor
  /// 2. Element ID
  /// 3. Text quote context match
  /// 4. Resource progression
  /// 5. Spine index match
  /// 6. Fallback to start of publication
  Future<PositionRestorationResult> restorePosition({
    required Publication publication,
    required Locator targetLocator,
    required IResourceResolver resolver,
  }) async {
    // Step 0: engine-native CFI positions. Both reader engines report CFIs,
    // not spine hrefs; the engine itself resolves them on open. Keep them
    // exactly - falling through to the steps below (which need a spine
    // href) used to reset every saved position to the start of the book.
    final cfi = targetLocator.locations.cfi ??
        (targetLocator.href.startsWith('epubcfi(') ? targetLocator.href : null);
    if (cfi != null && cfi.isNotEmpty) {
      return PositionRestorationResult(
        locator: targetLocator,
        restorationStepName: 'Step 0: Engine CFI',
        isExact: true,
      );
    }

    // Step 0b: native (Android PageEngine) positions carry an exact char offset in a chapter the
    // engine resolves by href itself. Rebuilding them below would drop the offset.
    if (targetLocator.locations.charOffset != null) {
      return PositionRestorationResult(
        locator: targetLocator,
        restorationStepName: 'Step 0b: Native char offset',
        isExact: true,
      );
    }

    final href = targetLocator.href.split('#')[0];
    final spineIndex = publication.findSpineIndex(href);

    // Step 1 & 2: Fragment / Element ID anchor
    final fragment = targetLocator.locations.fragment;
    if (fragment != null && fragment.isNotEmpty && spineIndex != -1) {
      if (resolver.hasResource(href)) {
        final content = await resolver.fetchResourceText(href);
        if (content.contains('id="$fragment"') || content.contains("id='$fragment'")) {
          return PositionRestorationResult(
            locator: targetLocator,
            restorationStepName: 'Step 1/2: Fragment ID match ($fragment)',
            isExact: true,
          );
        }
      }
    }

    // Step 3: Text quote / context match
    final highlightText = targetLocator.text?.highlight;
    if (highlightText != null && highlightText.isNotEmpty && spineIndex != -1) {
      if (resolver.hasResource(href)) {
        final content = await resolver.fetchResourceText(href);
        if (content.toLowerCase().contains(highlightText.toLowerCase())) {
          return PositionRestorationResult(
            locator: targetLocator,
            restorationStepName: 'Step 3: Text quote context match',
            isExact: true,
          );
        }
      }
    }

    // Step 4: Resource progression match
    if (targetLocator.locations.progression != null && spineIndex != -1) {
      final item = publication.getSpineItemAt(spineIndex)!;
      final progression = targetLocator.locations.progression!.clamp(0.0, 1.0);
      final totalProgression = publication.spine.isNotEmpty
          ? (spineIndex + progression) / publication.spine.length
          : 0.0;

      final restoredLocator = Locator(
        href: item.href,
        type: item.mediaType,
        title: publication.metadata.title,
        locations: LocationParameters(
          progression: progression,
          position: spineIndex,
          totalProgression: totalProgression,
        ),
      );

      return PositionRestorationResult(
        locator: restoredLocator,
        restorationStepName: 'Step 4: Resource progression fallback',
        isExact: false,
      );
    }

    // Step 5: Spine index match
    if (spineIndex != -1) {
      final item = publication.getSpineItemAt(spineIndex)!;
      final totalProgression = publication.spine.isNotEmpty ? spineIndex / publication.spine.length : 0.0;

      final restoredLocator = Locator(
        href: item.href,
        type: item.mediaType,
        title: publication.metadata.title,
        locations: LocationParameters(
          progression: 0.0,
          position: spineIndex,
          totalProgression: totalProgression,
        ),
      );

      return PositionRestorationResult(
        locator: restoredLocator,
        restorationStepName: 'Step 5: Spine index fallback',
        isExact: false,
      );
    }

    // Step 6: Fallback to beginning of publication
    final defaultSpine = publication.spine.isNotEmpty ? publication.spine.first : null;
    final fallbackLocator = Locator(
      href: defaultSpine?.href ?? '',
      type: defaultSpine?.mediaType ?? 'application/xhtml+xml',
      title: publication.metadata.title,
      locations: const LocationParameters(
        progression: 0.0,
        position: 0,
        totalProgression: 0.0,
      ),
    );

    return PositionRestorationResult(
      locator: fallbackLocator,
      restorationStepName: 'Step 6: Publication start fallback',
      isExact: false,
    );
  }
}
