import 'package:aread/src/presentation/widgets/book_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatFileSize', () {
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(1536), '1.5 KB');
    expect(formatFileSize(12 * 1024 * 1024), '12 MB');
    expect(formatFileSize(3 * 1024 * 1024 * 1024), '3.0 GB');
  });

  test('safeFileName strips characters file systems reject', () {
    expect(safeFileName('War: and/Peace?'), 'War and Peace');
    expect(safeFileName('  '), 'book');
    expect(safeFileName('a' * 100).length, 80);
  });
}
