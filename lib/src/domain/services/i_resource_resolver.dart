/// Service interface for acquiring, resolving, and decrypting publication resources.
library;

import 'dart:async';

abstract class IResourceResolver {
  /// Fetches raw bytes for a resource path (e.g., 'OEBPS/Text/ch01.xhtml').
  /// Applies DRM decryption transiently if protected.
  Future<List<int>> fetchResourceBytes(String href);

  /// Fetches text for a resource path.
  Future<String> fetchResourceText(String href);

  /// Checks if a resource exists in the publication container.
  bool hasResource(String href);
}
