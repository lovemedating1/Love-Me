import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Colour variants for [AppChip], mirroring the old app's multi-colour pills
/// (e.g. `✨ Straight` yellow, `👁 Likes men` pink, `Music 🎵` grey).
enum AppChipTone { yellow, pink, grey, dark, outlinePink }

/// A rounded pill with optional leading icon and a trailing emoji, as used
/// across Discover cards, the Profile card, and the preview modal.
///
/// Example: `AppChip(label: 'Straight', emoji: '✨', tone: AppChipTone.yellow)`
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.emoji,
    this.icon,
    this.tone = AppChipTone.grey,
    this.onTap,
    this.dense = false,
  });

  final String label;

  /// Rendered after the label, e.g. `✈️`.
  final String? emoji;

  /// Rendered before the label.
  final IconData? icon;

  final AppChipTone tone;
  final VoidCallback? onTap;
  final bool dense;

  (Color bg, Color fg, Color? border) get _colors => switch (tone) {
        AppChipTone.yellow => (AppColors.chipYellowBg, AppColors.chipYellowFg, null),
        AppChipTone.pink => (AppColors.chipPinkBg, AppColors.chipPinkFg, null),
        AppChipTone.grey => (AppColors.chipGreyBg, AppColors.chipGreyFg, null),
        AppChipTone.dark => (const Color(0xCC1F1F1F), AppColors.white, null),
        AppChipTone.outlinePink => (Colors.transparent, AppColors.pink, AppColors.pink),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors;
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 14,
        vertical: dense ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: dense ? 12 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (emoji != null) ...[
            const SizedBox(width: 4),
            Text(emoji!, style: TextStyle(fontSize: dense ? 12 : 14)),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}
