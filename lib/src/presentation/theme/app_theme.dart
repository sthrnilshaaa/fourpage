import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Built on demand: AppColors reflect the current mode when called.
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final scheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: AppColors.accentLime,
            secondary: AppColors.accentLavender,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimary,
          )
        : ColorScheme.light(
            primary: AppColors.accentLime,
            secondary: AppColors.accentLavender,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimary,
          );
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: scheme,
      textTheme: GoogleFonts.soraTextTheme(base.textTheme),
      useMaterial3: true,
    );
  }
}
