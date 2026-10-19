import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

class ColorConverter implements JsonConverter<Color?, String?> {
  const ColorConverter();

  @override
  Color? fromJson(String? json) {
    if (json == null) {
      return null;
    }
    return Color(int.parse(json, radix: 16));
  }

  @override
  String? toJson(Color? color) {
    if (color == null) {
      return null;
    }
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '$a$r$g$b';
  }
}
