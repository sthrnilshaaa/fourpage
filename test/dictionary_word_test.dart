import 'package:aread/src/data/dictionary/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DictionaryService.wordFrom', () {
    test('strips punctuation and quotes, lower-cases', () {
      expect(DictionaryService.wordFrom('“Melancholy,”'), 'melancholy');
      expect(DictionaryService.wordFrom('  Sarajevo. '), 'sarajevo');
    });
    test('drops possessives and trailing hyphens', () {
      expect(DictionaryService.wordFrom("Stoner’s"), 'stoner');
      expect(DictionaryService.wordFrom('auto-'), 'auto');
    });
    test('keeps hyphenated words, takes the first word of a phrase', () {
      expect(DictionaryService.wordFrom('well-known fact'), 'well-known');
      expect(DictionaryService.wordFrom('the yellow flame'), 'the');
    });
    test('null when there is no word', () {
      expect(DictionaryService.wordFrom('— 42 …'), isNull);
    });
  });
}
