import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/blocked_user.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/sub_page_header.dart';

/// Blocked-users list — reachable from Profile → "Blocked Users". Reads/
/// writes the (not-yet-live) `blocked_users` table (see
/// `BACKEND_ATIER_HANDOFF.md` §2); shows the normal empty state rather than
/// an error while backend ships it ([SafetyFeatureUnavailableException]).
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  String? _unblockingId;

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? AppColors.destructive : AppColors.pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _unblock(BlockedUser u) async {
    setState(() => _unblockingId = u.id);
    try {
      await ref.read(safetyRepositoryProvider).unblockUser(u.blockedUserId);
      ref.invalidate(blockedUsersProvider);
      _toast('${u.blockedName} has been unblocked.');
    } catch (_) {
      if (mounted) _toast('Could not unblock — try again.', error: true);
    } finally {
      if (mounted) setState(() => _unblockingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: const SubPageHeader(title: 'Blocked Users'),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView(
          message: 'Could not load blocked users.',
          onRetry: () => ref.invalidate(blockedUsersProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: LucideIcons.userX,
              message: 'You haven\'t blocked anyone.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => _tile(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, BlockedUser u) {
    final busy = _unblockingId == u.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.userX, color: AppColors.mutedFg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.blockedName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Blocked ${RelativeTime.short(u.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.mutedFg,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => _unblock(u),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unblock'),
          ),
        ],
      ),
    );
  }
}
