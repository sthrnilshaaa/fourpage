import 'package:flutter_test/flutter_test.dart';
import 'package:aread/src/presentation/utils/reader_tap_tracker.dart';

void main() {
  group('ReaderTapTracker', () {
    final start = DateTime.utc(2026, 1, 1);

    test('accepts a short tap with minor touch movement', () {
      final tracker = ReaderTapTracker();
      tracker.start(0.5, 0.5, at: start);

      expect(
        tracker.finish(
          0.504,
          0.503,
          at: start.add(const Duration(milliseconds: 180)),
        ),
        isTrue,
      );
    });

    test('rejects swipes and long presses', () {
      final swipe = ReaderTapTracker()..start(0.5, 0.5, at: start);
      expect(swipe.finish(0.7, 0.5, at: start.add(const Duration(milliseconds: 180))), isFalse);

      final longPress = ReaderTapTracker()..start(0.5, 0.5, at: start);
      expect(longPress.finish(0.5, 0.5, at: start.add(const Duration(seconds: 1))), isFalse);
    });

    test('consumes a touch pair once and ignores an unmatched up', () {
      final tracker = ReaderTapTracker()..start(0.5, 0.5, at: start);
      final endedAt = start.add(const Duration(milliseconds: 100));

      expect(tracker.finish(0.5, 0.5, at: endedAt), isTrue);
      expect(tracker.finish(0.5, 0.5, at: endedAt), isFalse);
    });
  });
}
