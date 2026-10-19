import 'package:aread/aread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DRM & Content Protection Tests', () {
    test('PlainProtectionProvider reports contentReady state', () {
      final plain = PlainProtectionProvider();
      expect(plain.currentState.status, equals(DrmStatus.contentReady));
      expect(plain.decryptResourceStream('href', [1, 2, 3]), equals([1, 2, 3]));
      expect(plain.getRights().isExpired, isFalse);
    });
  });
}
