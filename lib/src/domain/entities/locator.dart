/// Domain model for canonical reading position locators.
library;

class LocationParameters {
  final double? progression; // 0.0 to 1.0 within current spine item
  final int? position; // page index or item index
  final double? totalProgression; // 0.0 to 1.0 across full publication
  final String? fragment; // HTML fragment / element ID anchor
  final String? cfi; // Canonical Fragment Identifier
  // Native (Android PageEngine) reader: character offsets in the chapter's text.
  final int? charOffset;
  final int? charEnd;

  const LocationParameters({
    this.progression,
    this.position,
    this.totalProgression,
    this.fragment,
    this.cfi,
    this.charOffset,
    this.charEnd,
  });

  Map<String, dynamic> toJson() => {
        'progression': progression,
        'position': position,
        'totalProgression': totalProgression,
        'fragment': fragment,
        'cfi': cfi,
        if (charOffset != null) 'charOffset': charOffset,
        if (charEnd != null) 'charEnd': charEnd,
      };

  factory LocationParameters.fromJson(Map<String, dynamic> json) => LocationParameters(
        progression: (json['progression'] as num?)?.toDouble(),
        position: json['position'] as int?,
        totalProgression: (json['totalProgression'] as num?)?.toDouble(),
        fragment: json['fragment'] as String?,
        cfi: json['cfi'] as String?,
        charOffset: (json['charOffset'] as num?)?.toInt(),
        charEnd: (json['charEnd'] as num?)?.toInt(),
      );
}

class TextContext {
  final String? before;
  final String? highlight;
  final String? after;

  const TextContext({
    this.before,
    this.highlight,
    this.after,
  });

  Map<String, dynamic> toJson() => {
        'before': before,
        'highlight': highlight,
        'after': after,
      };

  factory TextContext.fromJson(Map<String, dynamic> json) => TextContext(
        before: json['before'] as String?,
        highlight: json['highlight'] as String?,
        after: json['after'] as String?,
      );
}

class Locator {
  final String href;
  final String type;
  final String? title;
  final LocationParameters locations;
  final TextContext? text;

  const Locator({
    required this.href,
    this.type = 'application/xhtml+xml',
    this.title,
    this.locations = const LocationParameters(),
    this.text,
  });

  Locator copyWith({
    String? href,
    String? type,
    String? title,
    LocationParameters? locations,
    TextContext? text,
  }) {
    return Locator(
      href: href ?? this.href,
      type: type ?? this.type,
      title: title ?? this.title,
      locations: locations ?? this.locations,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
        'href': href,
        'type': type,
        'title': title,
        'locations': locations.toJson(),
        'text': text?.toJson(),
      };

  factory Locator.fromJson(Map<String, dynamic> json) => Locator(
        href: json['href'] as String,
        type: json['type'] as String? ?? 'application/xhtml+xml',
        title: json['title'] as String?,
        locations: json['locations'] != null
            ? LocationParameters.fromJson(json['locations'] as Map<String, dynamic>)
            : const LocationParameters(),
        text: json['text'] != null
            ? TextContext.fromJson(json['text'] as Map<String, dynamic>)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Locator &&
          runtimeType == other.runtimeType &&
          href == other.href &&
          locations.fragment == other.locations.fragment &&
          locations.progression == other.locations.progression &&
          locations.position == other.locations.position;

  @override
  int get hashCode =>
      href.hashCode ^
      (locations.fragment?.hashCode ?? 0) ^
      (locations.progression?.hashCode ?? 0);
}
