import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aread/src/data/pdf/pdf_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('fourpages/pdf');
  final calls = <MethodCall>[];
  late Object? Function(MethodCall) defaultResponder;
  late Object? Function(MethodCall) responder;

  setUp(() {
    calls.clear();
    defaultResponder = (call) => switch (call.method) {
          'open' => {'id': 7, 'pageCount': 2, 'aspectRatios': [0.7, 0.7]},
          'render' => Uint8List.fromList([1, 2, 3]),
          'close' => null,
          _ => null,
        };
    responder = defaultResponder;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return responder(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('renders page one as a cover and closes the document', () async {
    final bytes = await PdfDocumentHandle.renderCover('/books/a.pdf', width: 180);

    expect(bytes, [1, 2, 3]);
    expect(calls.map((c) => c.method), ['open', 'render', 'close']);
    expect(calls[0].arguments, {'path': '/books/a.pdf'});
    expect(calls[1].arguments, {'id': 7, 'page': 0, 'width': 180});
  });

  test('closes the document and falls back to the gradient when rendering fails', () async {
    responder = (call) => call.method == 'render' ? throw PlatformException(code: 'pdf') : defaultResponder(call);

    expect(await PdfDocumentHandle.renderCover('/books/a.pdf'), isNull);
    expect(calls.map((c) => c.method), ['open', 'render', 'close']);
  });

  test('does not render an empty PDF', () async {
    responder = (call) => call.method == 'open'
        ? {'id': 7, 'pageCount': 0, 'aspectRatios': <double>[]}
        : defaultResponder(call);

    expect(await PdfDocumentHandle.renderCover('/books/a.pdf'), isNull);
    expect(calls.map((c) => c.method), ['open', 'close']);
  });
}
