import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/app_notification.dart';
import '../../shared/widgets/state_views.dart';

/// 12 — NotificationsPage. Activity feed with typed rows, unread dots.
///
/// No realtime yet (per migration_004.md) — the feed is refreshed manually
/// (pull-to-refresh / provider invalidation), not push-updated. The client
/// can mark-read/delete but never creates notifications.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(WidgetRef ref, List<AppNotification> all) async {
    final repo = ref.read(notificationRepositoryProvider);
    for (final n in all.where((n) => !n.isRead)) {
      await repo.markAsRead(n.id);
    }
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              final data = notifs.valueOrNull ?? const [];
              _markAllRead(ref, data);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: notifs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorView(
              message: 'Could not load notifications.',
              onRetry: () => ref.invalidate(notificationsProvider)),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 160),
                EmptyView(
                    icon: LucideIcons.bell, message: 'No notifications yet.'),
              ]);
            }
            return ListView.separated(
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
    return Dismissible(
      key: ValueKey(n.id),
      background: Container(
        color: AppColors.destructive,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await ref.read(notificationRepositoryProvider).delete(n.id);
        ref.invalidate(notificationsProvider);
      },
      child: ListTile(
        onTap: () async {
          if (!n.isRead) {
            await ref.read(notificationRepositoryProvider).markAsRead(n.id);
            ref.invalidate(notificationsProvider);
          }
          if (context.mounted) _deepLink(context, n);
        },
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(n.title,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
        subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(RelativeTime.short(n.createdAt),
                style: theme.textTheme.labelSmall),
            const SizedBox(height: 6),
            if (!n.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.pink, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(NotificationType t) => switch (t) {
        NotificationType.newLike => (LucideIcons.heart, AppColors.pink),
        NotificationType.newMatch => (LucideIcons.sparkles, AppColors.pink),
        NotificationType.newMessage => (LucideIcons.messageCircle, AppColors.purple),
        NotificationType.callIncoming => (LucideIcons.phoneIncoming, AppColors.purple),
        NotificationType.callMissed => (LucideIcons.phoneMissed, AppColors.destructive),
        NotificationType.profileView => (LucideIcons.eye, AppColors.gold),
        NotificationType.profileVerified => (LucideIcons.badgeCheck, AppColors.success),
        NotificationType.subscriptionExpiring => (LucideIcons.clock, AppColors.gold),
        NotificationType.subscriptionActive => (LucideIcons.crown, AppColors.gold),
        NotificationType.reportUpdate => (LucideIcons.shield, AppColors.destructive),
        NotificationType.system => (LucideIcons.info, AppColors.mutedFg),
      };

  /// Uses [AppNotification.data] for deep-link targets per migration_004.md.
  /// `newMessage`/`newMatch` carry a `conversation_id`, not a partner user id
  /// — the chat route is keyed by partner id, so those go to the Messages
  /// list rather than guessing at a conversion.
  void _deepLink(BuildContext context, AppNotification n) {
    switch (n.type) {
      case NotificationType.newLike:
        context.push(RoutePaths.likes);
      case NotificationType.newMatch:
      case NotificationType.newMessage:
      case NotificationType.callIncoming:
      case NotificationType.callMissed:
        context.push(RoutePaths.messages);
      case NotificationType.profileView:
      case NotificationType.profileVerified:
        context.push(RoutePaths.profile);
      case NotificationType.subscriptionExpiring:
      case NotificationType.subscriptionActive:
        context.push(RoutePaths.subscription);
      case NotificationType.reportUpdate:
        context.push(RoutePaths.safetyReports);
      case NotificationType.system:
        break;
    }
  }
}
