import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'color_converter.dart';

part 'epub_theme.g.dart';

///Theme type
enum EpubThemeType { dark, light, sepia, tan, grey, mint, custom }

///Class for customizing the theme of the reader
@JsonSerializable()
@ColorConverter()
class EpubTheme {
  @JsonKey(toJson: _decorationToJson, fromJson: _decorationFromJson)

  ///Background decoration of the reader, overrides customCss
  Decoration? backgroundDecoration;

  ///Foreground color of the reader, overrides customCss
  Color? foregroundColor;

  ///Custom css for the reader
  Map<String, dynamic>? customCss;
  EpubThemeType themeType;

  EpubTheme({
    this.backgroundDecoration,
    this.foregroundColor,
    this.customCss,
    required this.themeType,
  });

  static Map<String, dynamic>? _decorationToJson(Decoration? decoration) {
    return null;
  }

  static Decoration? _decorationFromJson(Map<String, dynamic> json) {
    return null;
  }

  /// Uses dark theme, black background and white foreground color
  factory EpubTheme.dark() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Color(0xff121212)),
      foregroundColor: Colors.white,
      themeType: EpubThemeType.dark,
    );
  }

  /// Uses light theme, white background and black foreground color
  factory EpubTheme.light() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Colors.white),
      foregroundColor: Colors.black,
      themeType: EpubThemeType.light,
    );
  }

  /// Uses sepia theme, brownish background and dark brown foreground color
  factory EpubTheme.sepia() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Color(0xfff4ecd8)),
      foregroundColor: const Color(0xff5b4636),
      themeType: EpubThemeType.sepia,
    );
  }

  /// Uses tan theme, darker brownish background and dark brown foreground color
  factory EpubTheme.tan() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Color(0xffdfd4b8)),
      foregroundColor: const Color(0xff3e3025),
      themeType: EpubThemeType.tan,
    );
  }

  /// Uses grey theme, dark grey background and light grey foreground color
  factory EpubTheme.grey() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Color(0xff333333)),
      foregroundColor: const Color(0xffcccccc),
      themeType: EpubThemeType.grey,
    );
  }

  /// Uses mint theme, light green background and dark green foreground color
  factory EpubTheme.mint() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Color(0xffe8f5e9)),
      foregroundColor: const Color(0xff2d3e2d),
      themeType: EpubThemeType.mint,
    );
  }

  /// Custom theme option ,
  factory EpubTheme.custom({
    Decoration? backgroundDecoration,
    Color? foregroundColor,
    Map<String, dynamic>? customCss,
  }) {
    return EpubTheme(
      backgroundDecoration: backgroundDecoration,
      foregroundColor: foregroundColor,
      customCss: customCss,
      themeType: EpubThemeType.custom,
    );
  }

  factory EpubTheme.fromJson(Map<String, dynamic> json) =>
      _$EpubThemeFromJson(json);
  Map<String, dynamic> toJson() => _$EpubThemeToJson(this);
}
