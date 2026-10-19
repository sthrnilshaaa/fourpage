/// Portable BookSource abstraction handling files, Android URIs, and byte streams without requiring physical file paths.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';

abstract class BookSource {
  String get name;
  int? get size;
  String get mimeType;

  /// Returns a stream of bytes for reading the EPUB container.
  Stream<List<int>> openStream();

  /// Reads all bytes into memory.
  Future<Uint8List> readBytes();
}

/// BookSource backed by a local physical filesystem path (Linux, Windows, macOS, Android/iOS local storage).
class LocalFileBookSource implements BookSource {
  final File _file;

  LocalFileBookSource(String path) : _file = File(path);

  @override
  String get name => _file.path.split(Platform.pathSeparator).last;

  @override
  int? get size => _file.existsSync() ? _file.lengthSync() : null;

  @override
  String get mimeType => 'application/epub+zip';

  @override
  Stream<List<int>> openStream() => _file.openRead();

  @override
  Future<Uint8List> readBytes() => _file.readAsBytes();
}

/// BookSource backed by an Android Content URI (content://...).
class AndroidUriBookSource implements BookSource {
  final String uri;
  final Uint8List _bytes;
  final String _displayName;

  AndroidUriBookSource({
    required this.uri,
    required Uint8List bytes,
    String? displayName,
  })  : _bytes = bytes,
        _displayName = displayName ?? 'ebook.epub';

  @override
  String get name => _displayName;

  @override
  int? get size => _bytes.length;

  @override
  String get mimeType => 'application/epub+zip';

  @override
  Stream<List<int>> openStream() => Stream.value(_bytes);

  @override
  Future<Uint8List> readBytes() async => _bytes;
}

/// Memory-backed BookSource for byte arrays and unit tests.
class MemoryBookSource implements BookSource {
  final String _name;
  final Uint8List _bytes;

  MemoryBookSource({
    required String name,
    required List<int> bytes,
  })  : _name = name,
        _bytes = Uint8List.fromList(bytes);

  @override
  String get name => _name;

  @override
  int? get size => _bytes.length;

  @override
  String get mimeType => 'application/epub+zip';

  @override
  Stream<List<int>> openStream() => Stream.value(_bytes);

  @override
  Future<Uint8List> readBytes() async => _bytes;
}
