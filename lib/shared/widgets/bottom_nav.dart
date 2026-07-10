import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';

/// A single bottom-navigation destination.
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    required this.route,
    this.activeIcon,
    this.badgeCount = 0,
    this.showDot = false,
  });

  /// Outline icon, shown when the tab is not selected.
  final IconData icon;

  /// Solid icon, shown when the tab **is** selected (old app fills the active
  /// tab's glyph). Falls back to [icon] when null.
  final IconData? activeIcon;

  final String label;
  final String route;
  final int badgeCount;
  final bool showDot;
}

/// The 5-tab bottom navigation shared by all AppShell screens.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentRoute,
    required this.onTap,
  });

  final String currentRoute;
  final void Function(String route) onTap;

  /// Matches the old app: sparkles for Discover, and a solid glyph on the
  /// active tab. Lucide ships outline-only, so the filled states use Material
  /// icons — visually equivalent to the screenshots.
  static const List<NavDestination> destinations = [
    NavDestination(
      icon: LucideIcons.sparkles,
      activeIcon: Icons.auto_awesome,
      label: 'Discover',
      route: RoutePaths.discover,
    ),
    NavDestination(
      icon: LucideIcons.heart,
      activeIcon: Icons.favorite,
      label: 'Likes',
      route: RoutePaths.likes,
    ),
    NavDestination(
      icon: LucideIcons.messageCircle,
      activeIcon: Icons.chat_bubble,
      label: 'Messages',
      route: RoutePaths.messages,
    ),
    NavDestination(
      icon: LucideIcons.globe,
      activeIcon: Icons.public,
      label: 'Explore',
      route: RoutePaths.explore,
    ),
    NavDestination(
      icon: LucideIcons.user,
      activeIcon: Icons.person,
      label: 'Profile',
      route: RoutePaths.profile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (final d in destinations)
                Expanded(
                  child: _NavItem(
                    destination: d,
                    selected: currentRoute == d.route,
                    onTap: () => onTap(d.route),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.55);
    final icon = selected
        ? (destination.activeIcon ?? destination.icon)
        : destination.icon;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 24),
              if (destination.badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration:
                        BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                    child: Text(
                      '${destination.badgeCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else if (destination.showDot)
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFFB800), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            destination.label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ),
          const SizedBox(height: 3),
          // The small pink dot under the active tab (old app).
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
