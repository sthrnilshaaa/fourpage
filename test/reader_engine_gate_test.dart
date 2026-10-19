import 'package:aread/src/presentation/utils/reader_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveReaderEngine', () {
    const sakuraPlatforms = [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows];

    test('auto: native on Android, sakura where its plugin exists, epubx on Linux and Web', () {
      expect(resolveReaderEngine(platform: TargetPlatform.android, isWeb: false, override: 'auto'), ReaderEngine.native);
      for (final p in sakuraPlatforms.where((p) => p != TargetPlatform.android)) {
        expect(resolveReaderEngine(platform: p, isWeb: false, override: 'auto'), ReaderEngine.sakura, reason: '$p');
      }
      expect(resolveReaderEngine(platform: TargetPlatform.linux, isWeb: false, override: 'auto'), ReaderEngine.epubx);
      expect(resolveReaderEngine(platform: TargetPlatform.android, isWeb: true, override: 'auto'), ReaderEngine.epubx);
    });

    test('epubx can be forced on any platform', () {
      for (final p in [...sakuraPlatforms, TargetPlatform.linux]) {
        expect(resolveReaderEngine(platform: p, isWeb: false, override: 'epubx'), ReaderEngine.epubx, reason: '$p');
      }
    });

    test('forcing sakura never selects it where the WebView plugin is missing', () {
      expect(resolveReaderEngine(platform: TargetPlatform.linux, isWeb: false, override: 'sakura'), ReaderEngine.epubx);
      expect(resolveReaderEngine(platform: TargetPlatform.macOS, isWeb: true, override: 'sakura'), ReaderEngine.epubx);
      expect(resolveReaderEngine(platform: TargetPlatform.android, isWeb: false, override: 'sakura'), ReaderEngine.sakura);
    });

    test('unknown override values behave like auto', () {
      expect(resolveReaderEngine(platform: TargetPlatform.linux, isWeb: false, override: 'nonsense'), ReaderEngine.epubx);
      expect(resolveReaderEngine(platform: TargetPlatform.android, isWeb: false, override: ' EPUBX '), ReaderEngine.epubx);
    });
  
    test('native override: native on Android only', () {
      expect(resolveReaderEngine(platform: TargetPlatform.android, isWeb: false, override: 'native'), ReaderEngine.native);
      expect(resolveReaderEngine(platform: TargetPlatform.iOS, isWeb: false, override: 'native'), ReaderEngine.sakura);
      expect(resolveReaderEngine(platform: TargetPlatform.linux, isWeb: false, override: 'native'), ReaderEngine.epubx);
    });
  });
}
