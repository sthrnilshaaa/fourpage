import 'dart:convert';
import 'dart:ui';

class Utils {
  static String encodeMap(Map<String, dynamic> data) {
    return jsonEncode(data);
  }
}

extension ColorToHex on Color {
  /// Converts the [Color] to a hex string in the format #RRGGBB.
  /// If [includeAlpha] is true, the format will be #AARRGGBB.
  String toHex({bool includeAlpha = false}) {
    final alpha = includeAlpha
        ? (a * 255).round().toRadixString(16).padLeft(2, '0')
        : '';
    final red = (r * 255).round().toRadixString(16).padLeft(2, '0');
    final green = (g * 255).round().toRadixString(16).padLeft(2, '0');
    final blue = (b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$alpha$red$green$blue';
  }
}
