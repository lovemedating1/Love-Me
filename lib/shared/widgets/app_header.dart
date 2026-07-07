import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

/// Gradient app header with the Love Me wordmark and optional actions.
/// Port of the reference `AppHeader`.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.title = 'Love Me',
    this.showLogo = true,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final bool showLogo;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.header),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(LucideIcons.arrowLeft,
                        color: AppColors.white),
                    tooltip: 'Back',
                  )
                else if (showLogo)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(LucideIcons.heart,
                        color: AppColors.white, size: 24),
                  ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.white),
                ),
                const Spacer(),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header icon action with an optional badge count.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          icon: Icon(icon, color: AppColors.white),
        ),
        if (badgeCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF2B2B2B),
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
