import 'package:flutter/material.dart';

/// Canonical brand palette for Love Me International.
///
/// UI-parity update (2026-07-10, Phase 1): the primary pink was warmed from
/// the original #E6287A to the old app's more saturated hot pink #FF1F8E to
/// match `app doctumant/old app ss/`. See UI_REBUILD_PLAN.md §1.1.
///
/// Do NOT hardcode colors in widgets — always reference [AppColors] (or pull
/// from the active [ThemeData]).
class AppColors {
  AppColors._();

  // ---- Brand -------------------------------------------------------------
  static const Color pink = Color(0xFFFF1F8E); // primary (old app hot pink)
  static const Color pinkDeep = Color(0xFFE6187C); // gradient start / pressed
  static const Color pinkSoft = Color(0xFFFF8FCF); // secondary
  static const Color gold = Color(0xFFFFB800); // accent
  static const Color goldWarm = Color(0xFFFFA61A);
  static const Color orange = Color(0xFFFF9E1B); // "Manage Plan" gradient end

  // ---- Chips (old app uses multi-colour pills) ---------------------------
  static const Color chipYellowBg = Color(0xFFFFE9A8);
  static const Color chipYellowFg = Color(0xFF2B2B2B);
  static const Color chipPinkBg = Color(0xFFFFD6EA);
  static const Color chipPinkFg = Color(0xFFD6136F);
  static const Color chipGreyBg = Color(0xFFECECEC);
  static const Color chipGreyFg = Color(0xFF3A3A3A);

  // ---- Subscription tier badges ------------------------------------------
  static const Color tierSilver = Color(0xFFB8B8B8);
  static const Color tierGold = Color(0xFFFFB800);
  static const Color tierDiamond = Color(0xFFFF4FA3);
  static const Color tierCrown = Color(0xFFFF2E93);
  static const Color tierVip = Color(0xFF6C2BD9);

  // ---- Light -------------------------------------------------------------
  /// Page background — the old app's pale pink wash, used on every screen.
  static const Color bgLight = Color(0xFFFDEEF4);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color fgLight = Color(0xFF1F1F1F);

  /// A softer near-black for body text / labels that shouldn't read as
  /// pure black (e.g. onboarding field labels) — [fgLight] stays reserved
  /// for headings and other places that want full contrast.
  static const Color fgSoft = Color(0xFF3A3A3A);
  static const Color mutedLight = Color(0xFFF8E8ED);
  static const Color mutedFg = Color(0xFF737373);
  static const Color borderLight = Color(0xFFF2DCE5);

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
