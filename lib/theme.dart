import 'package:flutter/material.dart';

/// Colors of the "Color Tiles" design.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF1E1A3B);
  static const muted = Color(0xFF5E5A7A);
  static const background = Color(0xFFF4F2FF);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF241E4E);
  static const accent = Color(0xFF4338CA);
  static const line = Color(0xFFE2DFF2);
  static const track = Color(0xFFECEAF7);
  static const navInactive = Color(0xFFD9D5F5);
  static const danger = Color(0xFFB42318);
  static const success = Color(0xFF15803D);
  static const successTint = Color(0xFFD7F5E4);
}

/// A soft tint and a strong color, used for tool tiles and split parts.
class TilePalette {
  const TilePalette(this.tint, this.color);

  final Color tint;
  final Color color;

  static const blue = TilePalette(Color(0xFFDCE6FF), Color(0xFF2346C8));
  static const orange = TilePalette(Color(0xFFFFE4D2), Color(0xFFB4470F));
  static const pink = TilePalette(Color(0xFFFFDDEB), Color(0xFFBE185D));
  static const green = TilePalette(Color(0xFFD7F5E4), Color(0xFF15803D));
  static const teal = TilePalette(Color(0xFFD4F3F5), Color(0xFF0E7490));
  static const purple = TilePalette(Color(0xFFE8DEFF), Color(0xFF6D28D9));
  static const yellow = TilePalette(Color(0xFFFFF1C2), Color(0xFFA16207));
  static const slate = TilePalette(Color(0xFFE0E7EF), Color(0xFF334155));

  /// Colors used to tell split parts apart.
  static const cycle = [blue, orange, green, pink, purple, teal, yellow];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Outfit',
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.accent, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
