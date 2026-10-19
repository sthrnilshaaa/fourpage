import 'package:aread/src/presentation/platform/folder_tree.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picked folders (tree URIs) show as readable paths', () {
    const uri = 'content://com.android.externalstorage.documents/tree/primary%3ABooks%2FNovels';
    expect(FolderTree.isTreeUri(uri), isTrue);
    expect(FolderTree.displayPath(uri), 'Books/Novels');
    expect(folderSegments(uri), ['Books', 'Novels']);
    // Root of a storage volume.
    expect(FolderTree.displayPath('content://com.android.externalstorage.documents/tree/primary%3A'), 'primary');
  });

  test('file paths are unchanged', () {
    expect(FolderTree.isTreeUri('/storage/emulated/0/Books'), isFalse);
    expect(folderSegments('/storage/emulated/0/Books'), ['storage', 'emulated', '0', 'Books']);
  });
}
