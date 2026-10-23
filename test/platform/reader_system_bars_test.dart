import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:aread/src/presentation/platform/reader_system_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pageInsets', () {
    const size = Size(400, 800);
    const cutout = DisplayFeature(
      bounds: Rect.fromLTWH(170, 0, 60, 30),
      type: DisplayFeatureType.cutout,
      state: DisplayFeatureState.unknown,
    );

    test('Android: same insets with the system bars shown or hidden', () {
      const shown = MediaQueryData(
        size: size,
        padding: EdgeInsets.only(top: 32, bottom: 48),
        viewPadding: EdgeInsets.only(top: 32, bottom: 48),
        displayFeatures: [cutout],
      );
      const hidden = MediaQueryData(
        size: size,
        padding: EdgeInsets.only(top: 30),
        viewPadding: EdgeInsets.only(top: 30),
        displayFeatures: [cutout],
      );
      final a = ReaderSystemBars.pageInsets(shown, platform: TargetPlatform.android);
      final b = ReaderSystemBars.pageInsets(hidden, platform: TargetPlatform.android);
      expect(a, b);
      expect(a, const EdgeInsets.only(top: 30));
    });

    test('Android without a cutout uses the whole screen', () {
      const media = MediaQueryData(size: size, padding: EdgeInsets.only(top: 24, bottom: 48));
      expect(ReaderSystemBars.pageInsets(media, platform: TargetPlatform.android), EdgeInsets.zero);
    });

    test('Android bottom cutout is kept clear', () {
      const media = MediaQueryData(
        size: size,
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(170, 780, 60, 20),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      expect(ReaderSystemBars.pageInsets(media, platform: TargetPlatform.android), const EdgeInsets.only(bottom: 20));
    });

    test('iOS keeps its safe area', () {
      const media = MediaQueryData(size: size, viewPadding: EdgeInsets.only(top: 47, bottom: 34));
      expect(ReaderSystemBars.pageInsets(media, platform: TargetPlatform.iOS), const EdgeInsets.only(top: 47, bottom: 34));
    });
  });

  test('hide and show switch the system UI mode', () async {
    final modes = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') modes.add(call.arguments);
      return null;
    });
    await ReaderSystemBars.hide();
    await ReaderSystemBars.show();
    expect(modes, ['SystemUiMode.immersive', 'SystemUiMode.edgeToEdge']);
  });
}
