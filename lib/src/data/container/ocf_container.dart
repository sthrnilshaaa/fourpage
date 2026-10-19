/// OCF (Open Container Format) ZIP Container reader.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/path_utils.dart';

class OcfContainer {
  final Archive _archive;

  OcfContainer._(this._archive);

  /// Opens an OCF ZIP container from raw bytes.
  factory OcfContainer.fromBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      return OcfContainer._(archive);
    } catch (e) {
      throw ContainerException('Failed to decode EPUB ZIP container archive.', e);
    }
  }

  /// Validates the mandatory EPUB mimetype file if present.
  void validateMimetype() {
    final mimeFile = findEntry('mimetype');
    if (mimeFile != null) {
      final content = String.fromCharCodes(mimeFile.content as List<int>).trim();
      if (!content.startsWith('application/epub+zip')) {
        throw const ContainerException('Invalid EPUB mimetype. Expected application/epub+zip');
      }
    }
  }

  /// Lists all file entry paths in the container.
  List<String> listEntries() {
    return _archive.files
        .where((f) => f.isFile)
        .map((f) => PathUtils.normalizePath(f.name))
        .toList();
  }

  List<String> get entryPaths => listEntries();

  /// Finds an entry in the archive matching the normalized path.
  ArchiveFile? findEntry(String path) {
    final normalized = PathUtils.normalizePath(path);
    for (final file in _archive.files) {
      if (file.isFile && PathUtils.normalizePath(file.name) == normalized) {
        return file;
      }
    }
    return null;
  }

  /// Checks if a file exists in the container.
  bool hasEntry(String path) => findEntry(path) != null;

  /// Reads raw bytes for a file entry.
  List<int> readBytes(String path) {
    final entry = findEntry(path);
    if (entry == null) {
      throw ResourceNotFoundException(path);
    }
    return entry.content as List<int>;
  }

  /// Reads text content for a file entry.
  /// Reads a text entry as UTF-8 (the EPUB default). It used to map each
  /// byte to one character, which garbled every non-ASCII title/author
  /// ("Café" became "CafÃ©").
  String readText(String path) {
    var bytes = readBytes(path);
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      bytes = bytes.sublist(3);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
