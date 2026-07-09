import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/call_log.dart';
import '../../shared/models/profile.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/state_views.dart';

/// 08 — MessagesPage (tab body). Chats + Calls tabs, search, conversation list.
///
/// A conversation only appears here once one exists in the live
/// `conversations` table — there is no client-side create yet (no INSERT
/// policy, no auto-create-on-match trigger). See ConversationRepository.
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
                _callsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Calls tab — real `call_logs` across all the user's conversations, newest
  /// first. Placing/answering a call isn't built yet (no WebRTC), so rows are
  /// read-only history.
  Widget _callsTab() {
    final calls = ref.watch(callHistoryProvider);
    final convos = ref.watch(conversationsProvider).valueOrNull ?? const [];
    final partnerByConversation = {
      for (final c in convos) c.conversation.id: c.partner,
    };

    return calls.when(
      loading: () => ListView(
        children: List.generate(
            5,
            (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SkeletonBox(height: 56, radius: 12),
                )),
      ),
      error: (_, _) => ErrorView(
          message: 'Could not load calls.',
          onRetry: () => ref.invalidate(callHistoryProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
              icon: LucideIcons.phone, message: 'No calls yet.');
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(callHistoryProvider);
            await ref.read(callHistoryProvider.future);
          },
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
            itemBuilder: (_, i) => _callTile(
                list[i], partnerByConversation[list[i].conversationId]),
          ),
        );
      },
    );
  }

  Widget _callTile(CallLog call, Profile? partner) {
    final theme = Theme.of(context);
    final myId = ref.watch(currentUserProvider).valueOrNull?.userId;
    final outgoing = myId != null && call.callerId == myId;
    final missed = call.callStatus == CallStatus.missed ||
        call.callStatus == CallStatus.declined;

    final (icon, color) = switch ((missed, outgoing)) {
      (true, _) => (LucideIcons.phoneMissed, AppColors.destructive),
      (false, true) => (LucideIcons.phoneOutgoing, AppColors.success),
      (false, false) => (LucideIcons.phoneIncoming, AppColors.success),
    };

    return ListTile(
      leading: AppAvatar(photoUrl: partner?.photoUrl, size: 44),
      title: Text(partner?.name ?? 'Unknown',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Icon(
              call.callType == CallType.video
                  ? LucideIcons.video
                  : LucideIcons.phone,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_callSubtitle(call, missed),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall),
          ),
        ],
      ),
      trailing: Text(RelativeTime.short(call.startedAt),
          style: theme.textTheme.labelSmall),
    );
  }

  String _callSubtitle(CallLog call, bool missed) {
    if (missed) return call.callStatus.name;
    final secs = call.durationSeconds;
    if (secs == null || secs == 0) return call.callStatus.name;
    final m = secs ~/ 60;
    final s = secs % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
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
                      !_deleted.contains(c.partner.userId) &&
                      c.partner.name.toLowerCase().contains(_query))
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

  Widget _tile(ConversationSummary c) {
    final theme = Theme.of(context);
    final partner = c.partner;
    return Slidable(
      key: ValueKey(partner.userId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => setState(() => _deleted.add(partner.userId)),
            backgroundColor: AppColors.destructive,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        onTap: () => context.push(RoutePaths.chatTo(partner.userId)),
        onLongPress: () => _actionSheet(c),
        leading: AppAvatar(
          photoUrl: partner.photoUrl,
          showOnline: true,
          isOnline: partner.isOnline,
          isVerified: partner.isVerified,
        ),
        title: Text(partner.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(c.lastMessageText ?? 'Say hi 👋',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: c.lastMessageAt == null
            ? null
            : Text(RelativeTime.short(c.lastMessageAt!),
                style: theme.textTheme.labelSmall),
      ),
    );
  }

  void _actionSheet(ConversationSummary c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.destructive),
              title: const Text('Delete conversation'),
              onTap: () {
                setState(() => _deleted.add(c.partner.userId));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
