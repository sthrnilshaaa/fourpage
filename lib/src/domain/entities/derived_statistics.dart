/// Derived publication statistics calculated during extraction (word count, reading time, resource counts).
library;

class DerivedStatistics {
  final int wordCount;
  final int characterCount;
  final int paragraphCount;
  final int chapterCount;
  final int imageCount;
  final int audioCount;
  final int videoCount;
  final int fontCount;
  final int scriptCount;
  final int stylesheetCount;
  final int estimatedReadingTimeMinutes;

  const DerivedStatistics({
    this.wordCount = 0,
    this.characterCount = 0,
    this.paragraphCount = 0,
    this.chapterCount = 0,
    this.imageCount = 0,
    this.audioCount = 0,
    this.videoCount = 0,
    this.fontCount = 0,
    this.scriptCount = 0,
    this.stylesheetCount = 0,
    this.estimatedReadingTimeMinutes = 0,
  });

  Map<String, dynamic> toJson() => {
        'wordCount': wordCount,
        'characterCount': characterCount,
        'paragraphCount': paragraphCount,
        'chapterCount': chapterCount,
        'imageCount': imageCount,
        'audioCount': audioCount,
        'videoCount': videoCount,
        'fontCount': fontCount,
        'scriptCount': scriptCount,
        'stylesheetCount': stylesheetCount,
        'estimatedReadingTimeMinutes': estimatedReadingTimeMinutes,
      };

  factory DerivedStatistics.fromJson(Map<String, dynamic> json) => DerivedStatistics(
        wordCount: json['wordCount'] as int? ?? 0,
        characterCount: json['characterCount'] as int? ?? 0,
        paragraphCount: json['paragraphCount'] as int? ?? 0,
        chapterCount: json['chapterCount'] as int? ?? 0,
        imageCount: json['imageCount'] as int? ?? 0,
        audioCount: json['audioCount'] as int? ?? 0,
        videoCount: json['videoCount'] as int? ?? 0,
        fontCount: json['fontCount'] as int? ?? 0,
        scriptCount: json['scriptCount'] as int? ?? 0,
        stylesheetCount: json['stylesheetCount'] as int? ?? 0,
        estimatedReadingTimeMinutes: json['estimatedReadingTimeMinutes'] as int? ?? 0,
      );
}
