import 'dart:io';
import 'package:flutter/foundation.dart';

/// Exception thrown when OS-level storage permissions block scanning a directory.
class FolderScanPermissionException implements Exception {
  final String path;
  final String message;

  const FolderScanPermissionException(this.path, [this.message = 'Storage permission denied']);

  @override
  String toString() => 'FolderScanPermissionException: $message ($path)';
}

/// Fault-tolerant utility to recursively find EPUB files in a directory tree.
/// Skips inaccessible directories, broken symlinks, and hidden files/directories.
class FolderScanner {
  const FolderScanner._();

  /// Recursively scans [dir] and returns all found `.epub` files.
  /// Handles permission errors gracefully so an error in one subfolder
  /// never aborts scanning the rest of the directory tree.
  /// Throws [FolderScanPermissionException] if the root directory itself cannot be accessed
  /// due to OS-level storage permission denial.
  static Future<List<File>> findEpubFiles(Directory dir) => findFiles(dir, const ['epub']);

  /// Like [findEpubFiles] for any of [extensions] (lowercase, no dot).
  static Future<List<File>> findFiles(Directory dir, List<String> extensions) async {
    final suffixes = extensions.map((e) => '.${e.toLowerCase()}').toList();
    final epubs = <File>[];
    final queue = <Directory>[dir];
    final visitedPaths = <String>{};
    bool rootPermissionDenied = false;

    while (queue.isNotEmpty) {
      final currentDir = queue.removeAt(0);

      String canonical;
      try {
        canonical = currentDir.resolveSymbolicLinksSync();
      } catch (_) {
        canonical = currentDir.path;
      }

      if (!visitedPaths.add(canonical)) continue;

      try {
        final stream = currentDir.list(followLinks: false);
        await for (final entity in stream.handleError((error) {
          debugPrint('FolderScanner: Skipping inaccessible entity in ${currentDir.path}: $error');
          if (currentDir.path == dir.path && _isPermissionError(error)) {
            rootPermissionDenied = true;
          }
        })) {
          try {
            final basename = entity.path.split(Platform.pathSeparator).last;
            // Ignore hidden directories and hidden files (e.g. .git, .thumbnails, ._book.epub)
            if (basename.startsWith('.')) continue;

            if (entity is Directory) {
              queue.add(entity);
            } else if (entity is File) {
              final lower = basename.toLowerCase();
              if (suffixes.any(lower.endsWith)) {
                epubs.add(entity);
              }
            }
          } catch (_) {
            // Ignore single entity errors
          }
        }
      } catch (e) {
        debugPrint('FolderScanner: Skipping unreadable directory ${currentDir.path}: $e');
        if (currentDir.path == dir.path && _isPermissionError(e)) {
          rootPermissionDenied = true;
        }
      }
    }

    if (epubs.isEmpty && rootPermissionDenied) {
      throw FolderScanPermissionException(
        dir.path,
        'Storage permission denied when accessing ${dir.path}',
      );
    }

    return epubs;
  }

  static bool _isPermissionError(dynamic error) {
    if (error is FileSystemException) {
      final msg = error.message.toLowerCase();
      final osMsg = error.osError?.message.toLowerCase() ?? '';
      final code = error.osError?.errorCode ?? 0;
      return code == 13 ||
          msg.contains('permission') ||
          osMsg.contains('permission') ||
          msg.contains('access denied');
    }
    final str = error.toString().toLowerCase();
    return str.contains('permission denied') ||
        str.contains('access denied') ||
        str.contains('errno = 13');
  }
}

