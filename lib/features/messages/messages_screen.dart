import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/conversation.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';

/// 08 — MessagesPage (tab body). Chats + Calls tabs, search, conversation list.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String _query = '';
  final Set<String> _deleted = {};

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Chats'), Tab(text: 'Calls')]),
          Expanded(
            child: TabBarView(
              children: [
                _chatsTab(),
                const EmptyView(
                    icon: LucideIcons.phone, message: 'No calls yet.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatsTab() {
    final convos = ref.watch(conversationsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search chats',
              prefixIcon: Icon(LucideIcons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: convos.when(
            loading: () => ListView(
              children: List.generate(
                  6,
                  (_) => const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: SkeletonBox(height: 56, radius: 12),
                      )),
            ),
            error: (_, _) => ErrorView(
                message: 'Could not load chats.',
                onRetry: () => ref.invalidate(conversationsProvider)),
            data: (all) {
              final list = all
                  .where((c) =>
                      !_deleted.contains(c.partnerId) &&
                      c.partnerName.toLowerCase().contains(_query))
                  .toList();
              if (list.isEmpty) {
                return const EmptyView(
                    icon: LucideIcons.messageCircle,
                    message: 'No conversations yet — start chatting from Discover.');
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
                itemBuilder: (_, i) => _tile(list[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(Conversation c) {
    final theme = Theme.of(context);
    return Slidable(
      key: ValueKey(c.partnerId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => setState(() => _deleted.add(c.partnerId)),
            backgroundColor: AppColors.destructive,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        onTap: () => context.push(RoutePaths.chatTo(c.partnerId)),
        onLongPress: () => _actionSheet(c),
        leading: AppAvatar(
          photoUrl: c.partnerPhotoUrl,
          showOnline: true,
          isOnline: c.isOnline,
          isVerified: c.isVerified,
        ),
        title: Row(
          children: [
            Text(c.partnerName,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (c.isMuted) ...[
              const SizedBox(width: 6),
              Icon(LucideIcons.bellOff,
                  size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ],
          ],
        ),
        subtitle: Text(c.lastMessage,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(RelativeTime.short(c.lastAt),
                style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            if (c.unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 20),
                decoration: const BoxDecoration(
                    color: AppColors.pink, shape: BoxShape.circle),
                child: Text('${c.unreadCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  void _actionSheet(Conversation c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.checkCheck),
              title: const Text('Mark as read'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(LucideIcons.bellOff),
              title: const Text('Mute'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.destructive),
              title: const Text('Delete conversation'),
              onTap: () {
                setState(() => _deleted.add(c.partnerId));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
