import 'package:aread/src/presentation/layout/spread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two pages from 900 wide', () {
    expect(useSpread(899), isFalse);
    expect(useSpread(900), isTrue);
    expect(useSpread(1600), isTrue);
  });
}
