/// Rendition and Fixed-Layout Information for EPUB publications.
library;

enum RenditionLayout { reflowable, fixedLayout }

enum RenditionOrientation { auto, landscape, portrait }

enum RenditionSpread { auto, none, landscape, both }

enum PageProgressionDirection { ltr, rtl, defaultDirection }

class RenditionInformation {
  final RenditionLayout layout;
  final String? viewportWidth;
  final String? viewportHeight;
  final RenditionOrientation orientation;
  final RenditionSpread spread;
  final PageProgressionDirection pageProgressionDirection;

  const RenditionInformation({
    this.layout = RenditionLayout.reflowable,
    this.viewportWidth,
    this.viewportHeight,
    this.orientation = RenditionOrientation.auto,
    this.spread = RenditionSpread.auto,
    this.pageProgressionDirection = PageProgressionDirection.defaultDirection,
  });

  bool get isFixedLayout => layout == RenditionLayout.fixedLayout;
  bool get isRtl => pageProgressionDirection == PageProgressionDirection.rtl;

  Map<String, dynamic> toJson() => {
        'layout': layout.name,
        'viewportWidth': viewportWidth,
        'viewportHeight': viewportHeight,
        'orientation': orientation.name,
        'spread': spread.name,
        'pageProgressionDirection': pageProgressionDirection.name,
      };

  factory RenditionInformation.fromJson(Map<String, dynamic> json) => RenditionInformation(
        layout: RenditionLayout.values.firstWhere(
          (e) => e.name == json['layout'],
          orElse: () => RenditionLayout.reflowable,
        ),
        viewportWidth: json['viewportWidth'] as String?,
        viewportHeight: json['viewportHeight'] as String?,
        orientation: RenditionOrientation.values.firstWhere(
          (e) => e.name == json['orientation'],
          orElse: () => RenditionOrientation.auto,
        ),
        spread: RenditionSpread.values.firstWhere(
          (e) => e.name == json['spread'],
          orElse: () => RenditionSpread.auto,
        ),
        pageProgressionDirection: PageProgressionDirection.values.firstWhere(
          (e) => e.name == json['pageProgressionDirection'],
          orElse: () => PageProgressionDirection.defaultDirection,
        ),
      );
}
