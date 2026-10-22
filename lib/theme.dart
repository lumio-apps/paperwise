import 'package:flutter/material.dart';

/// Colors of the "Clean list" design, for the light and the dark look.
///
/// The values follow [isDark], which the app sets before it draws.
class AppColors {
  AppColors._();

  /// True while the dark look is on.
  static bool isDark = false;

  static Color _pick(int light, int dark) => Color(isDark ? dark : light);

  static Color get ink => _pick(0xFF1F1B3A, 0xFFF1F0FA);
  static Color get muted => _pick(0xFF5E5A7A, 0xFFA9A5C9);

  /// The color behind every screen.
  static Color get background => _pick(0xFFF4F2FB, 0xFF14122B);

  /// Cards, groups of rows, dialogs and sheets.
  static Color get surface => _pick(0xFFFFFFFF, 0xFF1F1C3C);

  /// Main buttons and small filled badges.
  static Color get primary => _pick(0xFF4B42BB, 0xFF5B52D6);

  /// Links, chosen options and the active tab.
  static Color get accent => _pick(0xFF4B42BB, 0xFFB9B3FF);
  static Color get line => _pick(0xFFE6E3F2, 0xFF2C2952);

  /// Fill for a chosen option or an icon well.
  static Color get track => _pick(0xFFEEECF7, 0xFF2A2750);
  static Color get navInactive => _pick(0xFFD9D5F5, 0xFFD9D5F5);
  static Color get danger => _pick(0xFFB42318, 0xFFF97066);
  static Color get success => _pick(0xFF15803D, 0xFF4ADE80);
  static Color get successTint => _pick(0xFFD7F5E4, 0xFF163A2A);
}

/// A soft tint and a strong color, used for tool icons and split parts.
class TilePalette {
  const TilePalette(this.tint, this.color);

  final Color tint;
  final Color color;

  static TilePalette _pick(TilePalette light, TilePalette dark) => AppColors.isDark ? dark : light;

  static TilePalette get blue =>
      _pick(const TilePalette(Color(0xFFE8EDFF), Color(0xFF3B5BDB)), const TilePalette(Color(0xFF27305C), Color(0xFF9DB2FF)));
  static TilePalette get orange =>
      _pick(const TilePalette(Color(0xFFFFEDE0), Color(0xFFC2410C)), const TilePalette(Color(0xFF4A2E22), Color(0xFFFFB68A)));
  static TilePalette get pink =>
      _pick(const TilePalette(Color(0xFFFFE6F1), Color(0xFFBE185D)), const TilePalette(Color(0xFF4A2540), Color(0xFFFF9CC6)));
  static TilePalette get green =>
      _pick(const TilePalette(Color(0xFFE1F6E9), Color(0xFF15803D)), const TilePalette(Color(0xFF1F4030), Color(0xFF7FE0A4)));
  static TilePalette get teal =>
      _pick(const TilePalette(Color(0xFFDDF3F8), Color(0xFF0E7490)), const TilePalette(Color(0xFF1E3F4A), Color(0xFF7FDCEB)));
  static TilePalette get purple =>
      _pick(const TilePalette(Color(0xFFEFE7FF), Color(0xFF6D28D9)), const TilePalette(Color(0xFF3A2A66), Color(0xFFC4A6FF)));
  static TilePalette get yellow =>
      _pick(const TilePalette(Color(0xFFFFF3CC), Color(0xFFA16207)), const TilePalette(Color(0xFF3A3015), Color(0xFFF2C75C)));
  static TilePalette get slate =>
      _pick(const TilePalette(Color(0xFFEAEEF3), Color(0xFF475569)), const TilePalette(Color(0xFF2E3547), Color(0xFFBCC6D6)));

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
