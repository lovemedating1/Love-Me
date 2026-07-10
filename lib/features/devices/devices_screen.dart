import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/device_session.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/sub_page_header.dart';

/// 14 — DevicesPage.
///
/// Rebuilt for UI parity (Phase 5, `WA0056`) — see UI_REBUILD_PLAN.md §5.3:
/// "Active devices" title, raw user-agent per row, "Last active … · Signed
/// in N days ago", and a single solid-red "Sign out of other devices"
/// button (per-device sign-out link dropped).
///
/// Note: [DeviceSession] has no separate sign-in timestamp — "Signed in N
/// days ago" uses `lastActive` for both, which is the closest honest value
/// available rather than a fabricated second timestamp.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final Set<String> _revoked = {};

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    return Scaffold(
      appBar: const SubPageHeader(title: 'Active devices'),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView(
            message: 'Could not load devices.',
            onRetry: () => ref.invalidate(devicesProvider)),
        data: (list) {
          final active = list.where((d) => !_revoked.contains(d.id)).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'This is a single-device account. Signing in elsewhere signs '
                'out the older session.',
                style: TextStyle(color: AppColors.mutedFg, fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (final d in active) _tile(context, d),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Sign out of other devices',
                icon: LucideIcons.logOut,
                gradient: const LinearGradient(
                    colors: [AppColors.destructive, AppColors.destructive]),
                onPressed: () => setState(() => _revoked
                    .addAll(list.where((d) => !d.isCurrent).map((d) => d.id))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, DeviceSession d) {
    final daysAgo = DateTime.now().difference(d.lastActive).inDays;
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
          Icon(
            d.label.contains('Chrome') ? LucideIcons.monitor : LucideIcons.smartphone,
            color: d.isCurrent ? AppColors.pink : AppColors.mutedFg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(d.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (d.isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.online.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999)),
                        child: const Text('This device',
                            style: TextStyle(fontSize: 10, color: AppColors.online)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Last active ${daysAgo <= 0 ? "today" : "${daysAgo}d ago"} · '
                  'Signed in ${daysAgo}d ago',
                  style: const TextStyle(color: AppColors.mutedFg, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
