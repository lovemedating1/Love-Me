import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_gradients.dart';

/// The old app's second-level page header: a pink gradient bar with a circular
/// translucent back button and a bold white title.
///
/// Used by Settings, Notifications, Devices, Legal, Choose Your Plan, etc.
class SubPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const SubPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.header),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                CircleIconButton(
                  icon: LucideIcons.arrowLeft,
                  onTap: onBack ?? () => context.pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular translucent icon button, as used in the old app's headers
/// (back arrow, bell, phone/video/shield in chat).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.52),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
