import 'dart:io';
import 'dart:typed_data';

import 'package:sakura_epub/src/epub_data_loader.dart';



/// Epub file source
class EpubSource {
  // aread patch: loaded on first use, not at construction - a book opened
  // by URL (EpubViewer.servedBook) never reads the file at all.
  final Future<Uint8List> Function() _load;
  Future<Uint8List>? _data;
  Future<Uint8List> get epubData => _data ??= _load();

  EpubSource._(this._load);

  ///Loading from a file
  factory EpubSource.fromFile(File file) {
    final loader = FileEpubLoader(file);
    return EpubSource._(loader.loadData);
  }

  ///load from a url with optional headers
  factory EpubSource.fromUrl(String url, {Map<String, String>? headers}) {
    final loader = UrlEpubLoader(url, headers: headers);
    return EpubSource._(loader.loadData);
  }

  ///load from assets
  factory EpubSource.fromAsset(String assetPath) {
    final loader = AssetEpubLoader(assetPath);
    return EpubSource._(loader.loadData);
  }
}
