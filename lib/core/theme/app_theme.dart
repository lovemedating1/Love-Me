import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Light + dark [ThemeData] for the app.
///
/// UI-parity update (2026-07-10, Phase 1): matched the old app's look —
/// fully-rounded buttons, 20px cards with a soft shadow, 16px inputs, and
/// large pink switches. See UI_REBUILD_PLAN.md §1.1.
class AppTheme {
  AppTheme._();

  /// Inputs.
  static const double _radius = 16;

  /// Cards — the old app uses a large, soft radius.
  static const double cardRadius = 20;

  /// The soft drop shadow under white cards in the old app.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6)),
  ];

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
      // Old app's CTAs are fully-rounded pills.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pink,
          foregroundColor: AppColors.white,
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondary.withValues(alpha: 0.35),
        labelStyle: textTheme.labelSmall,
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      // Large, pink-filled switches (old app style).
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.pink
              : scheme.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
    );
  }
}
