import 'package:flutter/material.dart';

/// Canonical brand palette for Love Me International.
///
/// Locked decision (2026-07-03): primary pink #E6287A + gold #FFB800.
/// Do NOT hardcode colors in widgets — always reference [AppColors] (or pull
/// from the active [ThemeData]).
class AppColors {
  AppColors._();

  // ---- Brand -------------------------------------------------------------
  static const Color pink = Color(0xFFE6287A); // primary
  static const Color pinkSoft = Color(0xFFFFB0CE); // secondary
  static const Color gold = Color(0xFFFFB800); // accent
  static const Color goldWarm = Color(0xFFFFA61A);

  // ---- Light -------------------------------------------------------------
  static const Color bgLight = Color(0xFFFFF0F5);
  static const Color cardLight = Color(0xFFFFF7FA);
  static const Color fgLight = Color(0xFF2B2B2B);
  static const Color mutedLight = Color(0xFFF8E8ED);
  static const Color mutedFg = Color(0xFF737373);
  static const Color borderLight = Color(0xFFEED9E1);

  // ---- Dark --------------------------------------------------------------
  static const Color bgDark = Color(0xFF181013);
  static const Color cardDark = Color(0xFF25181D);
  static const Color fgDark = Color(0xFFFFF0F5);
  static const Color mutedDark = Color(0xFF2E1E24);
  static const Color mutedFgDark = Color(0xFFB79AA5);
  static const Color borderDark = Color(0xFF38242C);

  // ---- Semantic ----------------------------------------------------------
  static const Color online = Color(0xFF3DCB6A);
  static const Color success = Color(0xFF00C853);
  static const Color destructive = Color(0xFFF04444);
  static const Color purple = Color(0xFF7A33CC);
  static const Color paypal = Color(0xFFFFC439);
  static const Color white = Color(0xFFFFFFFF);
}
