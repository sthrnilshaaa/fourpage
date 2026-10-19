/// Reader preferences and typography configuration settings.
library;

enum ReaderTheme { publisher, light, dark, sepia, highContrast }

enum LayoutMode { reflowable, fixed }

enum ScrollMode { paginated, continuous }

enum WritingMode { horizontalTb, verticalRl, verticalLr }

class ReaderPreferences {
  final String fontFamily;
  final double fontSize; // Base pt/px font size
  final double fontWeight;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double marginHorizontal;
  final double marginVertical;
  final String textAlignment; // 'left', 'right', 'justify', 'center'
  final ReaderTheme theme;
  final LayoutMode layoutMode;
  final ScrollMode scrollMode;
  final WritingMode writingMode;

  const ReaderPreferences({
    // Must be one of the families the reader can actually render (see
    // ReaderScreen._getReaderTextStyle / ReaderCustomizationSheet's font
    // chips) - 'Georgia' used to be the default despite not being an
    // option anywhere, so no font chip ever showed as selected initially.
    this.fontFamily = 'Merriweather',
    this.fontSize = 16.0,
    this.fontWeight = 400.0,
    this.lineHeight = 2.0, // the sheet's line spacing step 05
    this.letterSpacing = 0.0,
    this.paragraphSpacing = 1.0,
    this.marginHorizontal = 0.0,
    this.marginVertical = 16.0,
    this.textAlignment = 'left',
    this.theme = ReaderTheme.dark,
    this.layoutMode = LayoutMode.reflowable,
    this.scrollMode = ScrollMode.paginated,
    this.writingMode = WritingMode.horizontalTb,
  });

  ReaderPreferences copyWith({
    String? fontFamily,
    double? fontSize,
    double? fontWeight,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    double? marginHorizontal,
    double? marginVertical,
    String? textAlignment,
    ReaderTheme? theme,
    LayoutMode? layoutMode,
    ScrollMode? scrollMode,
    WritingMode? writingMode,
  }) {
    return ReaderPreferences(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      marginHorizontal: marginHorizontal ?? this.marginHorizontal,
      marginVertical: marginVertical ?? this.marginVertical,
      textAlignment: textAlignment ?? this.textAlignment,
      theme: theme ?? this.theme,
      layoutMode: layoutMode ?? this.layoutMode,
      scrollMode: scrollMode ?? this.scrollMode,
      writingMode: writingMode ?? this.writingMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'fontWeight': fontWeight,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
        'paragraphSpacing': paragraphSpacing,
        'marginHorizontal': marginHorizontal,
        'marginVertical': marginVertical,
        'textAlignment': textAlignment,
        'theme': theme.name,
        'layoutMode': layoutMode.name,
        'scrollMode': scrollMode.name,
        'writingMode': writingMode.name,
      };

  factory ReaderPreferences.fromJson(Map<String, dynamic> json) => ReaderPreferences(
        fontFamily: json['fontFamily'] as String? ?? 'Merriweather',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
        fontWeight: (json['fontWeight'] as num?)?.toDouble() ?? 400.0,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 2.0,
        letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
        paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 1.0,
        marginHorizontal: (json['marginHorizontal'] as num?)?.toDouble() ?? 0.0,
        marginVertical: (json['marginVertical'] as num?)?.toDouble() ?? 16.0,
        textAlignment: json['textAlignment'] as String? ?? 'left',
        theme: ReaderTheme.values.firstWhere(
          (e) => e.name == json['theme'],
          orElse: () => ReaderTheme.dark,
        ),
        layoutMode: LayoutMode.values.firstWhere(
          (e) => e.name == json['layoutMode'],
          orElse: () => LayoutMode.reflowable,
        ),
        scrollMode: ScrollMode.values.firstWhere(
          (e) => e.name == json['scrollMode'],
          orElse: () => ScrollMode.paginated,
        ),
        writingMode: WritingMode.values.firstWhere(
          (e) => e.name == json['writingMode'],
          orElse: () => WritingMode.horizontalTb,
        ),
      );
}
