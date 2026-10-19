import 'package:aread/aread.dart';
import 'package:aread/src/presentation/utils/sample_epub_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Engine Architecture & Compatibility Harness Tests', () {
    late EpubCompatibilityHarness harness;
    late List<int> validEpubZip;

    setUp(() {
      harness = EpubCompatibilityHarness();
      validEpubZip = SampleEpubBuilder.buildEpubZip(
        title: 'Harness Test Publication',
        author: 'Test Author',
        chapterTexts: ['Chapter 1 content for harness validation test.'],
      );
    });

    test('EpubCompatibilityHarness evaluates publication and scores engines', () async {
      final report = await harness.evaluatePublication(validEpubZip);

      expect(report.title, equals('Harness Test Publication'));
      expect(report.version, equals(EPUBVersion.epub3));
      expect(report.layout, equals(LayoutType.reflowable));
      expect(report.protection, equals(ProtectionType.unprotected));
      expect(report.engineScores.length, equals(3));
      expect(report.recommendedEngine, isNotEmpty);
    });

    test('PureFlutterReaderEngine opens publication and manages reader session', () async {
      final engine = PureFlutterReaderEngine();
      expect(engine.engineType, equals(EngineType.pureFlutter));

      final pub = await engine.open(validEpubZip);
      expect(pub.metadata.title, equals('Harness Test Publication'));

      await engine.nextPage();
      await engine.previousPage();
      await engine.close();
    });

    test('WebViewEpubJsReaderEngine applies strict security policy', () async {
      final engine = WebViewEpubJsReaderEngine();
      expect(engine.engineType, equals(EngineType.webViewEpubJs));
      expect(engine.securityPolicy.allowGeolocation, isFalse);
      expect(engine.securityPolicy.allowCamera, isFalse);
      expect(engine.securityPolicy.allowMicrophone, isFalse);

      expect(engine.securityPolicy.isPermissionGranted('camera'), isFalse);
      expect(engine.securityPolicy.isPermissionGranted('geolocation'), isFalse);
    });
  });
}
