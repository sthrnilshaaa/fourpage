/// Domain model for a navigation item in Table of Contents or Landmarks.
library;

class NavItem {
  final String title;
  final String href;
  final List<NavItem> children;

  const NavItem({
    required this.title,
    required this.href,
    this.children = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'href': href,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory NavItem.fromJson(Map<String, dynamic> json) => NavItem(
        title: json['title'] as String,
        href: json['href'] as String,
        children: (json['children'] as List<dynamic>?)
                ?.map((c) => NavItem.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
