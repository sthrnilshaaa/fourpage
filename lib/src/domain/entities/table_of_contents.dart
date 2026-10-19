/// Domain representation of Table of Contents, Landmarks, and Page Lists.
library;

import 'nav_item.dart';

class TableOfContents {
  final List<NavItem> items;
  final List<NavItem> landmarks;
  final List<NavItem> pageList;

  const TableOfContents({
    this.items = const [],
    this.landmarks = const [],
    this.pageList = const [],
  });

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'landmarks': landmarks.map((l) => l.toJson()).toList(),
        'pageList': pageList.map((p) => p.toJson()).toList(),
      };

  factory TableOfContents.fromJson(Map<String, dynamic> json) => TableOfContents(
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => NavItem.fromJson(i as Map<String, dynamic>))
                .toList() ??
            const [],
        landmarks: (json['landmarks'] as List<dynamic>?)
                ?.map((l) => NavItem.fromJson(l as Map<String, dynamic>))
                .toList() ??
            const [],
        pageList: (json['pageList'] as List<dynamic>?)
                ?.map((p) => NavItem.fromJson(p as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
