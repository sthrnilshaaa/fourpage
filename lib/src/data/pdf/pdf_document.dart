/// PDF pages rendered by the platform (Android's built-in PdfRenderer via the
/// `fourpages/pdf` channel in MainActivity). No third-party PDF engine.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this platform can render PDFs. The import picker only offers PDF
/// where this is true, so no platform ends up with books it can't open.
bool get isPdfSupportedPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class PdfDocumentHandle {
  static const _channel = MethodChannel('fourpages/pdf');

  final int _id;
  final int pageCount;

  /// width / height of each page.
  final List<double> aspectRatios;

  PdfDocumentHandle._(this._id, this.pageCount, this.aspectRatios);

  static Future<PdfDocumentHandle> open(String path) async {
    final info = await _channel.invokeMapMethod<String, dynamic>('open', {'path': path});
    if (info == null) throw StateError('Could not open PDF');
    return PdfDocumentHandle._(
      info['id'] as int,
      info['pageCount'] as int,
      (info['aspectRatios'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  /// PNG bytes of [page] (0-based) rendered [width] pixels wide.
  Future<Uint8List> renderPage(int page, int width) async {
    final bytes = await _channel.invokeMethod<Uint8List>('render', {'id': _id, 'page': page, 'width': width});
    if (bytes == null) throw StateError('Could not render page $page');
    return bytes;
  }

  Future<void> close() => _channel.invokeMethod<void>('close', {'id': _id});
}
