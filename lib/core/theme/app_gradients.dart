import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand gradients mirroring the reference CSS (UI doc §2.3).
class AppGradients {
  AppGradients._();

  /// AppHeader background — pink → soft pink, 135°.
  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.pink, AppColors.pinkSoft],
  );

  /// Upgrade buttons / premium banners — pink → mid → gold.
  static const LinearGradient premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.pink, Color(0xFFFF7AA8), AppColors.gold],
  );

  /// VIP badges — gold → warm gold.
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.goldWarm],
  );

  

  /// Animated VIP tier label (use with a shimmer/animation later).
  static const LinearGradient vip = LinearGradient(
    begin: Alignment(-1, 0),
    end: Alignment(1, 0),
    colors: [
      Color(0xFF0B2A6B),
      AppColors.purple,
      Color(0xFFFFD54D),
      AppColors.purple,
      Color(0xFF0B2A6B),
    ],
  );
}
