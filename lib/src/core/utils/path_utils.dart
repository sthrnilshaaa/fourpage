/// Utility for URL normalization, relative resolution, and security sanitization.
library;

import 'package:path/path.dart' as p;

class PathUtils {
  PathUtils._();

  /// Normalizes a path/href string by resolving relative segments (e.g., `.` and `..`)
  /// and ensuring forward-slash separation.
  static String normalizePath(String path) {
    if (path.isEmpty) return '';
    
    // Split fragment if present
    final parts = path.split('#');
    final mainPath = parts[0];
    final fragment = parts.length > 1 ? parts.sublist(1).join('#') : null;

    final normalized = p.posix.normalize(mainPath.replaceAll(r'\', '/'));

    if (fragment != null && fragment.isNotEmpty) {
      return '$normalized#$fragment';
    }
    return normalized;
  }

  /// Resolves an href relative to a base directory or base file path.
  static String resolveHref(String baseFilePath, String href) {
    if (href.startsWith('/')) {
      return normalizePath(href.substring(1));
    }
    
    // If href is an absolute URI scheme (http, https, urn, data), return as is.
    if (href.contains('://') || href.startsWith('data:')) {
      return href;
    }

    final parts = href.split('#');
    final relativePath = parts[0];
    final fragment = parts.length > 1 ? parts.sublist(1).join('#') : null;

    final baseDir = p.posix.dirname(baseFilePath);
    final resolvedPath = p.posix.normalize(p.posix.join(baseDir, relativePath));

    // Prevent directory traversal escape outside of container root
    final sanitized = resolvedPath.startsWith('../')
        ? resolvedPath.replaceFirst(RegExp(r'^(\.\./)+'), '')
        : resolvedPath;

    if (fragment != null && fragment.isNotEmpty) {
      return '$sanitized#$fragment';
    }
    return sanitized;
  }

  /// Extracts the fragment identifier (without `#`) from a URL or path.
  static String? extractFragment(String href) {
    final index = href.indexOf('#');
    if (index == -1 || index == href.length - 1) return null;
    return href.substring(index + 1);
  }

  /// Removes any fragment identifier from a URL or path.
  static String removeFragment(String href) {
    final index = href.indexOf('#');
    if (index == -1) return href;
    return href.substring(0, index);
  }

  /// Determines mime-type from file extension fallback.
  static String inferMediaType(String path) {
    final cleanPath = removeFragment(path).toLowerCase();
    if (cleanPath.endsWith('.xhtml') || cleanPath.endsWith('.html') || cleanPath.endsWith('.htm')) {
      return 'application/xhtml+xml';
    } else if (cleanPath.endsWith('.css')) {
      return 'text/css';
    } else if (cleanPath.endsWith('.png')) {
      return 'image/png';
    } else if (cleanPath.endsWith('.jpg') || cleanPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (cleanPath.endsWith('.gif')) {
      return 'image/gif';
    } else if (cleanPath.endsWith('.svg')) {
      return 'image/svg+xml';
    } else if (cleanPath.endsWith('.ncx')) {
      return 'application/x-dtbncx+xml';
    } else if (cleanPath.endsWith('.otf')) {
      return 'font/otf';
    } else if (cleanPath.endsWith('.ttf')) {
      return 'font/ttf';
    } else if (cleanPath.endsWith('.woff')) {
      return 'font/woff';
    } else if (cleanPath.endsWith('.woff2')) {
      return 'font/woff2';
    } else if (cleanPath.endsWith('.mp3')) {
      return 'audio/mpeg';
    } else if (cleanPath.endsWith('.mp4')) {
      return 'video/mp4';
    }
    return 'application/octet-stream';
  }
}
