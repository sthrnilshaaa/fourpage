/// Folder scans in the Play build: the system folder picker (Storage Access
/// Framework) grants read access to one folder, instead of the "All files
/// access" permission the GitHub build uses. See FolderTree.kt (src/playstore).
///
/// Folders picked this way are stored as `content://` tree URIs in the same
/// places a file path would be (scanned folders, book → folder map).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FolderTreeFile {
  final String uri;
  final String name;
  const FolderTreeFile(this.uri, this.name);
}

class FolderTree {
  FolderTree._();

  static const _channel = MethodChannel('fourpages/folder_tree');

  /// True only in the Play build on Android. `appFlavor` is a compile-time
  /// constant, so the GitHub build compiles these code paths out.
  static bool get isUsed =>
      appFlavor == 'playstore' && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool isTreeUri(String folder) => folder.startsWith('content://');

  /// Opens the system folder picker; the folder's URI, or null if cancelled.
  static Future<String?> pick() => _channel.invokeMethod<String>('pick');

  /// Every file in the folder (recursively) with one of [extensions].
  static Future<List<FolderTreeFile>> list(String uri, List<String> extensions) async {
    final rows = await _channel.invokeListMethod<Map>('list', {'uri': uri, 'extensions': extensions}) ?? const [];
    return [for (final r in rows) FolderTreeFile(r['uri'] as String, r['name'] as String)];
  }

  static Future<Uint8List> read(String uri) async =>
      (await _channel.invokeMethod<Uint8List>('read', {'uri': uri}))!;

  /// Whether the app still holds read access to a picked folder.
  static Future<bool> hasAccess(String uri) async =>
      await _channel.invokeMethod<bool>('hasAccess', {'uri': uri}) ?? false;

  /// Gives back the folder's access (folder no longer tracked).
  static Future<void> release(String uri) => _channel.invokeMethod<void>('release', {'uri': uri});

  /// "Books/Novels" for a tree URI like `.../tree/primary%3ABooks%2FNovels`.
  static String displayPath(String uri) {
    final tree = Uri.decodeComponent(uri.split('/tree/').last.split('/document/').first);
    final path = tree.contains(':') ? tree.substring(tree.indexOf(':') + 1) : tree;
    return path.isEmpty ? tree.replaceAll(':', '') : path;
  }
}

/// How a scanned folder is shown: its path segments, for file paths and
/// picked (tree URI) folders alike.
List<String> folderSegments(String folder) => (FolderTree.isTreeUri(folder) ? FolderTree.displayPath(folder) : folder)
    .split(RegExp(r'[\\/]'))
    .where((s) => s.isNotEmpty)
    .toList();
