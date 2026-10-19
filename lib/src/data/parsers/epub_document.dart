import 'dart:io';
import 'package:epubx/epubx.dart';
import 'package:flutter/services.dart';
import 'epub_archive_repair.dart';

class EpubDocument {
  static Future<EpubBook> openAsset(String assetName) async {
    final byteData = await rootBundle.load(assetName);
    final bytes = byteData.buffer.asUint8List();
    return EpubReader.readBook(EpubArchiveRepair.fillMissingManifestEntries(bytes));
  }

  static Future<EpubBook> openData(Uint8List bytes) async {
    return EpubReader.readBook(EpubArchiveRepair.fillMissingManifestEntries(bytes));
  }

  static Future<EpubBook> openFile(File file) async {
    final bytes = await file.readAsBytes();
    return EpubReader.readBook(EpubArchiveRepair.fillMissingManifestEntries(bytes));
  }
}
