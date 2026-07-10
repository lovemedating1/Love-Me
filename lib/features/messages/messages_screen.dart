import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/call_log.dart';
import '../../shared/models/profile.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/segmented_tabs.dart';
import '../../shared/widgets/state_views.dart';

/// 08 — MessagesPage (tab body).
///
/// Rebuilt for UI parity (Phase 4, `WA0031`) — see UI_REBUILD_PLAN.md §4.3:
/// a segmented pill switcher instead of a `TabBar`, elevated white card rows,
/// and an inline expanding Mute/Archive/Delete action row instead of swipe.
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final convos = ref.watch(conversationsProvider).valueOrNull ?? const [];
    final chatCount = convos.where((c) => !_deleted.contains(c.partner.userId)).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Messages and Calls',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedTabs(
            tabs: [
              SegmentedTab(label: 'Chats', badgeCount: chatCount),
              const SegmentedTab(label: 'Calls'),
            ],
            selectedIndex: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(child: _tab == 0 ? _chatsTab() : _callsTab()),
      ],
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
        padding: const EdgeInsets.all(16),
        children: List.generate(
            5, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SkeletonBox(height: 66, radius: 16),
                )),
      ),
      error: (_, _) => ErrorView(
          message: 'Could not load calls.',
          onRetry: () => ref.invalidate(callHistoryProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Column(
              children: [
                Text('📞', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('No calls yet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 4),
                Text('Start a voice or video call from any chat',
                    style: TextStyle(color: AppColors.mutedFg)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(callHistoryProvider);
            await ref.read(callHistoryProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _callCard(
                  list[i], partnerByConversation[list[i].conversationId]),
            ),
          ),
        );
      },
    );
  }

  Widget _callCard(CallLog call, Profile? partner) {
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        leading: AppAvatar(photoUrl: partner?.photoUrl, size: 46),
        title: Text(partner?.name ?? 'Unknown',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Icon(
                call.callType == CallType.video ? LucideIcons.video : LucideIcons.phone,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_callSubtitle(call, missed),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall),
            ),
          ],
        ),
        trailing: Text(RelativeTime.short(call.startedAt),
            style: theme.textTheme.labelSmall),
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: List.generate(
                  6, (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: SkeletonBox(height: 74, radius: 16),
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
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChatRow(
                    summary: list[i],
                    onDeleted: () =>
                        setState(() => _deleted.add(list[i].partner.userId)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single conversation row with an inline expanding
/// Mute 🔕 · Archive 🗄 · Delete 🗑 action strip, replacing swipe-to-delete.
class _ChatRow extends StatefulWidget {
  const _ChatRow({required this.summary, required this.onDeleted});

  final ConversationSummary summary;
  final VoidCallback onDeleted;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _expanded = false;

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = widget.summary.partner;
    final c = widget.summary;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            minVerticalPadding: 12,
            onTap: () => context.push(RoutePaths.chatTo(partner.userId)),
            onLongPress: () => setState(() => _expanded = !_expanded),
            leading: AppAvatar(
              photoUrl: partner.photoUrl,
              showOnline: true,
              isOnline: partner.isOnline,
              isVerified: partner.isVerified,
            ),
            title: Text(partner.name,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            subtitle: Text(c.lastMessageText ?? 'Say hi 👋',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (c.lastMessageAt != null)
                  Text(RelativeTime.short(c.lastMessageAt!),
                      style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Icon(
                      _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 16),
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _actionChip(
                      icon: LucideIcons.bellOff,
                      label: 'Mute',
                      // No `muted` column on `conversations` yet — [BE-11].
                      onTap: () => _toast(context, 'Mute isn\'t available yet.'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionChip(
                      icon: LucideIcons.archive,
                      label: 'Archive',
                      // No `archived` column on `conversations` yet — [BE-11].
                      onTap: () => _toast(context, 'Archive isn\'t available yet.'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionChip(
                      icon: LucideIcons.trash2,
                      label: 'Delete',
                      color: AppColors.destructive,
                      onTap: widget.onDeleted,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () => setState(() => _expanded = false),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.mutedFg,
  }) =>
      Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
        ),
      );
}
