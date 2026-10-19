import 'package:epubx/epubx.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class EpubViewChapter {
  EpubViewChapter(this.title, this.startIndex);

  final String? title;
  final int startIndex;

  String get type => this is EpubViewSubChapter ? 'subchapter' : 'chapter';

  @override
  String toString() => '$type: {title: $title, startIndex: $startIndex}';
}

class EpubViewSubChapter extends EpubViewChapter {
  EpubViewSubChapter(super.title, super.startIndex);
}

class EpubChapterViewValue {
  const EpubChapterViewValue({
    required this.chapter,
    required this.chapterNumber,
    required this.paragraphNumber,
    required this.position,
  });

  final EpubChapter? chapter;
  final int chapterNumber;
  final int paragraphNumber;
  final ItemPosition position;

  /// Chapter view in percentage (0 to 100)
  double get progress {
    final itemLeadingEdgeAbsolute = position.itemLeadingEdge.abs();
    final fullHeight = itemLeadingEdgeAbsolute + position.itemTrailingEdge;
    if (fullHeight == 0) return 0.0;
    final heightPercent = fullHeight / 100;
    return itemLeadingEdgeAbsolute / heightPercent;
  }
}
