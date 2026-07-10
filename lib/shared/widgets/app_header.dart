import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../data/repositories.dart';
import '../models/profile.dart';
import 'app_avatar.dart';
import 'sub_page_header.dart' show CircleIconButton;

/// The old app's personalised tab header (see `old app ss/IMG-…-WA0034.jpg`):
///
/// ```
/// [avatar]  Hi, {name}            [📅 36d] [🕐 22d]   (🔔)
///           📍 {city}, {country}
/// ```
///
/// Shown on all 5 tabs. Replaces the old static "Love Me" wordmark.
///
/// **Data honesty:** each countdown pill is **hidden** when its value is
/// unknown rather than showing a fabricated number.
/// - `🕐 22d` (subscription renewal) reads `profiles.premium_until`.
/// - `📅 36d` (account expiry) has **no backing field anywhere** in the live
///   schema, so it never renders today. See [accountDaysLeft].
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.onNotificationsTap,
    this.onAccountPillTap,
    this.onSubscriptionPillTap,
    this.actions = const [],
    this.notificationCount = 0,
  });

  /// Bell → Notifications.
  final VoidCallback onNotificationsTap;

  /// 📅 pill → the "36 days left" modal (Phase 5).
  final VoidCallback? onAccountPillTap;

  /// 🕐 pill → the "22 days left" modal (Phase 5).
  final VoidCallback? onSubscriptionPillTap;

  /// Extra trailing actions (e.g. Discover's filter button).
  final List<Widget> actions;

  final int notificationCount;

  /// Days until the account itself expires.
  ///
  /// ⚠️ **Always null.** The old app shows `36d` here, but **no such column
  /// exists** in `profiles` (or anywhere else in the delivered migrations).
  /// Returning null hides the pill. Backend must add the field — tracked in
  /// `BACKEND_REMAINING.md`. Do **not** fake this value.
  int? get accountDaysLeft => null;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final subDaysLeft = me?.premiumDaysLeft;

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.header),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                AppAvatar(photoUrl: me?.photoUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(child: _greeting(me)),
                if (accountDaysLeft != null) ...[
                  _CountdownPill(
                    icon: LucideIcons.calendar,
                    days: accountDaysLeft!,
                    onTap: onAccountPillTap,
                  ),
                  const SizedBox(width: 6),
                ],
                if (subDaysLeft != null) ...[
                  _CountdownPill(
                    icon: LucideIcons.clock,
                    days: subDaysLeft,
                    warm: true,
                    onTap: onSubscriptionPillTap,
                  ),
                  const SizedBox(width: 6),
                ],
                ...actions,
                _bell(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _greeting(Profile? me) {
    final name = me?.name;
    final location = me == null
        ? null
        : [me.city, me.country].where((s) => s.isNotEmpty).join(', ');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name.isEmpty ? 'Hi there' : 'Hi, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (location != null && location.isNotEmpty)
          Row(
            children: [
              const Icon(LucideIcons.mapPin, color: Colors.white70, size: 13),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _bell() {
    final bell = CircleIconButton(
      icon: LucideIcons.bell,
      onTap: onNotificationsTap,
      tooltip: 'Notifications',
    );
    if (notificationCount <= 0) return bell;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bell,
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration:
                const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
            child: Text(
              notificationCount > 99 ? '99+' : '$notificationCount',
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

/// The translucent `📅 36d` / `🕐 22d` countdown pills in the header.
class _CountdownPill extends StatelessWidget {
  const _CountdownPill({
    required this.icon,
    required this.days,
    this.warm = false,
    this.onTap,
  });

  final IconData icon;
  final int days;

  /// The subscription pill is tinted warm/orange in the old app.
  final bool warm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: warm
              ? AppColors.orange.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              '${days}d',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header icon action with an optional badge count.
///
/// Kept for callers that add extra trailing actions (e.g. Discover's filter
/// button). The bell is now built into [AppHeader] itself.
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
        CircleIconButton(icon: icon, onTap: onTap, tooltip: tooltip),
        if (badgeCount > 0)
          Positioned(
            right: 0,
            top: 0,
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
