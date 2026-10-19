// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epub_theme.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EpubTheme _$EpubThemeFromJson(Map<String, dynamic> json) => EpubTheme(
      backgroundDecoration: EpubTheme._decorationFromJson(
          json['backgroundDecoration'] as Map<String, dynamic>),
      foregroundColor:
          const ColorConverter().fromJson(json['foregroundColor'] as String?),
      customCss: json['customCss'] as Map<String, dynamic>?,
      themeType: $enumDecode(_$EpubThemeTypeEnumMap, json['themeType']),
    );

Map<String, dynamic> _$EpubThemeToJson(EpubTheme instance) => <String, dynamic>{
      'backgroundDecoration':
          EpubTheme._decorationToJson(instance.backgroundDecoration),
      'foregroundColor':
          const ColorConverter().toJson(instance.foregroundColor),
      'customCss': instance.customCss,
      'themeType': _$EpubThemeTypeEnumMap[instance.themeType]!,
    };

const _$EpubThemeTypeEnumMap = {
  EpubThemeType.dark: 'dark',
  EpubThemeType.light: 'light',
  EpubThemeType.sepia: 'sepia',
  EpubThemeType.tan: 'tan',
  EpubThemeType.grey: 'grey',
  EpubThemeType.mint: 'mint',
  EpubThemeType.custom: 'custom',
};
