import 'package:flutter/material.dart';

/// Colors of the "Color Tiles" design, for the light and the dark look.
///
/// The values follow [isDark], which the app sets before it draws.
class AppColors {
  AppColors._();

  /// True while the dark look is on.
  static bool isDark = false;

  static Color _pick(int light, int dark) => Color(isDark ? dark : light);

  static Color get ink => _pick(0xFF1E1A3B, 0xFFF1EFFF);
  static Color get muted => _pick(0xFF5E5A7A, 0xFFB0ACCB);
  static Color get background => _pick(0xFFF4F2FF, 0xFF0F0D1F);
  static Color get surface => _pick(0xFFFFFFFF, 0xFF1B1833);
  static Color get primary => _pick(0xFF241E4E, 0xFF4B42BB);
  static Color get accent => _pick(0xFF4338CA, 0xFFA9A4FF);
  static Color get line => _pick(0xFFE2DFF2, 0xFF2E2A4D);
  static Color get track => _pick(0xFFECEAF7, 0xFF26223F);
  static Color get navInactive => _pick(0xFFD9D5F5, 0xFFD9D5F5);
  static Color get danger => _pick(0xFFB42318, 0xFFF97066);
  static Color get success => _pick(0xFF15803D, 0xFF4ADE80);
  static Color get successTint => _pick(0xFFD7F5E4, 0xFF163A2A);
}

/// A soft tint and a strong color, used for tool tiles and split parts.
class TilePalette {
  const TilePalette(this.tint, this.color);

  final Color tint;
  final Color color;

  static TilePalette _pick(TilePalette light, TilePalette dark) => AppColors.isDark ? dark : light;

  static TilePalette get blue =>
      _pick(const TilePalette(Color(0xFFDCE6FF), Color(0xFF2346C8)), const TilePalette(Color(0xFF1E2A55), Color(0xFF8FA8FF)));
  static TilePalette get orange =>
      _pick(const TilePalette(Color(0xFFFFE4D2), Color(0xFFB4470F)), const TilePalette(Color(0xFF3A2416), Color(0xFFF5A36B)));
  static TilePalette get pink =>
      _pick(const TilePalette(Color(0xFFFFDDEB), Color(0xFFBE185D)), const TilePalette(Color(0xFF3D1B2C), Color(0xFFF58DB8)));
  static TilePalette get green =>
      _pick(const TilePalette(Color(0xFFD7F5E4), Color(0xFF15803D)), const TilePalette(Color(0xFF163326), Color(0xFF5FD08A)));
  static TilePalette get teal =>
      _pick(const TilePalette(Color(0xFFD4F3F5), Color(0xFF0E7490)), const TilePalette(Color(0xFF123539), Color(0xFF5CC7D6)));
  static TilePalette get purple =>
      _pick(const TilePalette(Color(0xFFE8DEFF), Color(0xFF6D28D9)), const TilePalette(Color(0xFF2D2254), Color(0xFFB79BFF)));
  static TilePalette get yellow =>
      _pick(const TilePalette(Color(0xFFFFF1C2), Color(0xFFA16207)), const TilePalette(Color(0xFF3A3015), Color(0xFFF2C75C)));
  static TilePalette get slate =>
      _pick(const TilePalette(Color(0xFFE0E7EF), Color(0xFF334155)), const TilePalette(Color(0xFF273140), Color(0xFFA9B8CC)));

  /// Colors used to tell split parts apart.
  static List<TilePalette> get cycle => [blue, orange, green, pink, purple, teal, yellow];
}

/// Builds the theme for the light or the dark look.
ThemeData buildTheme({required bool dark}) {
  final before = AppColors.isDark;
  AppColors.isDark = dark;
  try {
    return _buildTheme(dark);
  } finally {
    AppColors.isDark = before;
  }
}

ThemeData _buildTheme(bool dark) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4338CA),
    brightness: dark ? Brightness.dark : Brightness.light,
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
    appBarTheme: AppBarThemeData(
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
