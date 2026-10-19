/// Resource resolver implementation providing on-demand protected stream decryption and robust path resolution.
library;

import 'dart:convert';
import '../../core/errors/exceptions.dart';
import '../../core/utils/path_utils.dart';
import '../../domain/protection/content_protection.dart';
import '../../domain/services/i_resource_resolver.dart';
import '../container/ocf_container.dart';
import '../protection/plain_protection_provider.dart';

class PublicationResourceResolver implements IResourceResolver {
  final OcfContainer _container;
  final ContentProtection _protection;

  PublicationResourceResolver({
    required OcfContainer container,
    ContentProtection? protection,
  })  : _container = container,
        _protection = protection ?? PlainProtectionProvider();

  String? _resolveContainerPath(String rawHref) {
    final clean = PathUtils.removeFragment(rawHref);
    if (_container.hasEntry(clean)) return clean;

    final normalized = PathUtils.normalizePath(clean);
    if (_container.hasEntry(normalized)) return normalized;

    // Search by suffix or filename match in OcfContainer
    for (final entry in _container.entryPaths) {
      final normEntry = PathUtils.normalizePath(entry);
      if (normEntry == normalized || normEntry.endsWith(normalized) || normalized.endsWith(normEntry)) {
        return entry;
      }
    }

    final filename = normalized.split('/').last.toLowerCase();
    for (final entry in _container.entryPaths) {
      if (entry.split('/').last.toLowerCase() == filename) {
        return entry;
      }
    }

    return null;
  }

  @override
  bool hasResource(String href) {
    return _resolveContainerPath(href) != null;
  }

  @override
  Future<List<int>> fetchResourceBytes(String href) async {
    final resolvedPath = _resolveContainerPath(href);
    if (resolvedPath == null) {
      throw ResourceNotFoundException(href);
    }

    final rawBytes = _container.readBytes(resolvedPath);
    // Apply DRM decryption transiently if protection is required
    return _protection.decryptResourceStream(resolvedPath, rawBytes);
  }

  @override
  Future<String> fetchResourceText(String href) async {
    final bytes = await fetchResourceBytes(href);
    return utf8.decode(bytes, allowMalformed: true);
  }
}
