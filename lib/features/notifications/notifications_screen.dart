import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/notifications/notification_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/app_notification.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/sub_page_header.dart';

/// 12 — NotificationsPage.
///
/// Rebuilt for UI parity (Phase 5, `WA0037`) — see UI_REBUILD_PLAN.md §5.3:
/// absolute dates instead of relative ("6/19/2026"), pale-pink circular
/// icons, and the unread dots / "Mark all read" / swipe-delete all removed
/// (the old app has none of them — it's a plain read-only activity feed;
/// rows still tap through to their deep link).
///
/// No realtime yet (per migration_004.md) — the feed is refreshed manually
/// (pull-to-refresh / provider invalidation), not push-updated. The client
/// can mark-read but never creates notifications.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: const SubPageHeader(title: 'Notifications'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: notifs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorView(
            message: 'Could not load notifications.',
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  EmptyView(
                    icon: LucideIcons.bell,
                    message: 'No notifications yet.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) => _row(context, ref, list[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, AppNotification n) {
    final theme = Theme.of(context);
    final (icon, color) = _iconFor(n.type);
    return ListTile(
      onTap: () async {
        if (!n.isRead) {
          await ref.read(notificationRepositoryProvider).markAsRead(n.id);
          ref.invalidate(notificationsProvider);
        }
        if (context.mounted) _deepLink(context, n);
      },
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.secondary.withValues(alpha: 0.35),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        n.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        RelativeTime.absolute(n.createdAt),
        style: theme.textTheme.labelSmall,
      ),
    );
  }

  (IconData, Color) _iconFor(NotificationType t) => switch (t) {
    NotificationType.newLike => (LucideIcons.heart, AppColors.pink),
    NotificationType.newMatch => (LucideIcons.sparkles, AppColors.pink),
    NotificationType.newMessage => (
      LucideIcons.messageCircle,
      AppColors.purple,
    ),
    NotificationType.callIncoming => (
      LucideIcons.phoneIncoming,
      AppColors.purple,
    ),
    NotificationType.callMissed => (
      LucideIcons.phoneMissed,
      AppColors.destructive,
    ),
    NotificationType.profileView => (LucideIcons.eye, AppColors.gold),
    NotificationType.profileVerified => (
      LucideIcons.badgeCheck,
      AppColors.success,
    ),
    NotificationType.subscriptionExpiring => (
      LucideIcons.clock,
      AppColors.gold,
    ),
    NotificationType.subscriptionActive => (LucideIcons.crown, AppColors.gold),
    NotificationType.reportUpdate => (
      LucideIcons.shield,
      AppColors.destructive,
    ),
    NotificationType.system => (LucideIcons.info, AppColors.mutedFg),
  };

  void _deepLink(BuildContext context, AppNotification n) {
    navigateForNotificationType(GoRouter.of(context), n.type);
  }
}
