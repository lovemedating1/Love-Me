import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Light + dark [ThemeData] for the app. Radius 14 (buttons/inputs) / 16 (cards).
class AppTheme {
  AppTheme._();

  static const double _radius = 14;

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.pink,
      onPrimary: AppColors.white,
      secondary: AppColors.pinkSoft,
      onSecondary: Color(0xFF990048),
      tertiary: AppColors.gold,
      surface: AppColors.cardLight,
      onSurface: AppColors.fgLight,
      error: AppColors.destructive,
      onError: AppColors.white,
      outline: AppColors.borderLight,
    );
    return _base(scheme, AppColors.bgLight, AppColors.fgLight);
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.pink,
      onPrimary: AppColors.white,
      secondary: Color(0xFF472030),
      onSecondary: AppColors.fgDark,
      tertiary: AppColors.gold,
      surface: AppColors.cardDark,
      onSurface: AppColors.fgDark,
      error: AppColors.destructive,
      onError: AppColors.white,
      outline: AppColors.borderDark,
    );
    return _base(scheme, AppColors.bgDark, AppColors.fgDark);
  }

  static ThemeData _base(ColorScheme scheme, Color bg, Color fg) {
    final textTheme = AppTextStyles.textTheme(fg);
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: fg,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pink,
          foregroundColor: AppColors.white,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.pink, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondary.withValues(alpha: 0.35),
        labelStyle: textTheme.labelSmall,
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
    );
  }
}
