/// Native (Kotlin) EPUB unpacking for the reader - see EpubUnpacker.kt.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sakura_epub/sakura_epub.dart' show EpubServedBook;

class EpubUnpacker {
  EpubUnpacker._();

  static const _channel = MethodChannel('fourpages/epub');

  /// Android only: other platforms keep sakura's original bytes path.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<Directory> _root() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/epub_unpacked');

  static String _folder(String publicationId) =>
      publicationId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Unpacks [epub] once (no-op when already unpacked) and returns how to
  /// serve it to the reader, or null if that isn't possible here.
  static Future<EpubServedBook?> serve(String publicationId, File epub) async {
    if (!supported) return null;
    try {
      final root = await _root();
      final folder = _folder(publicationId);
      await _channel.invokeMethod<String>('unpack', {
        'zipPath': epub.path,
        'outDir': '${root.path}/$folder',
      });
      return EpubServedBook(directory: root.path, folder: folder);
    } catch (e) {
      debugPrint('EpubUnpacker: falling back to in-page unzip: $e');
      return null;
    }
  }

  /// Deletes the unpacked copy of a book (the book was removed).
  static Future<void> remove(String publicationId) async {
    if (!supported) return;
    try {
      final root = await _root();
      await _channel.invokeMethod('remove', {'outDir': '${root.path}/${_folder(publicationId)}'});
    } catch (e) {
      debugPrint('EpubUnpacker: could not remove: $e');
    }
  }
}
