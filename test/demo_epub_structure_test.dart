import 'dart:io';

import 'package:aread/src/data/container/ocf_container.dart';
import 'package:aread/src/data/parsers/epub_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Local sample books, git-ignored (some are commercial titles): the test
// runs only on machines that have the folder.
final _demoDir = Directory('E-pub_book_demo');

void main() {
  test('demo EPUBs retain readable metadata and valid spine resources', skip: _demoDir.existsSync() ? false : 'E-pub_book_demo/ not present', () async {
    final directory = _demoDir;
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.epub'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(files, hasLength(5));
    final parser = EpubPublicationParser();
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final publication = await parser.parsePublication(bytes);
      final container = OcfContainer.fromBytes(bytes);

      expect(publication.metadata.title.trim(), isNotEmpty, reason: file.path);
      expect(publication.spine, isNotEmpty, reason: file.path);
      expect(
        publication.spine.every((item) => container.hasEntry(item.href)),
        isTrue,
        reason: 'Every spine href should resolve inside ${file.path}',
      );
    }
  });
}
