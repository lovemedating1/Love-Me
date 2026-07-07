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

/// 12 — NotificationsPage. Activity feed with typed rows, unread dots, mark-all.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _read = {};

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              final data = notifs.valueOrNull ?? const [];
              _read.addAll(data.map((n) => n.id));
            }),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView(
            message: 'Could not load notifications.',
            onRetry: () => ref.invalidate(notificationsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
                icon: LucideIcons.bell, message: 'No notifications yet.');
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (_, i) => _row(list[i]),
          );
        },
      ),
    );
  }

  Widget _row(AppNotification n) {
    final theme = Theme.of(context);
    final read = n.isRead || _read.contains(n.id);
    final (icon, color) = _iconFor(n.type);
    return ListTile(
      onTap: () {
        setState(() => _read.add(n.id));
        _deepLink(n);
      },
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(n.title,
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: read ? FontWeight.w500 : FontWeight.w700)),
      subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(RelativeTime.short(n.createdAt),
              style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          if (!read)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: AppColors.pink, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  (IconData, Color) _iconFor(NotificationType t) => switch (t) {
        NotificationType.like => (LucideIcons.heart, AppColors.pink),
        NotificationType.superLike => (LucideIcons.star, AppColors.gold),
        NotificationType.match => (LucideIcons.sparkles, AppColors.pink),
        NotificationType.message => (LucideIcons.messageCircle, AppColors.purple),
        NotificationType.missedCall => (LucideIcons.phoneMissed, AppColors.destructive),
        NotificationType.safety => (LucideIcons.shield, AppColors.destructive),
        NotificationType.system => (LucideIcons.info, AppColors.mutedFg),
      };

  void _deepLink(AppNotification n) {
    switch (n.type) {
      case NotificationType.like:
      case NotificationType.superLike:
        context.push(RoutePaths.likes);
      case NotificationType.match:
      case NotificationType.message:
        if (n.relatedUserId != null) {
          context.push(RoutePaths.chatTo(n.relatedUserId!));
        }
      case NotificationType.missedCall:
        context.push(RoutePaths.messages);
      case NotificationType.safety:
        context.push(RoutePaths.safetyReports);
      case NotificationType.system:
        break;
    }
  }
}
