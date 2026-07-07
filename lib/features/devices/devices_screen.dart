import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/device_session.dart';
import '../../shared/widgets/state_views.dart';

/// 14 — DevicesPage. Active sessions with revoke + sign-out-everywhere.
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
      appBar: AppBar(title: const Text('Devices')),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView(
            message: 'Could not load devices.',
            onRetry: () => ref.invalidate(devicesProvider)),
        data: (list) {
          final active =
              list.where((d) => !_revoked.contains(d.id)).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('This is a single-device account. Signing in elsewhere '
                  'signs out the older session.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              for (final d in active) _tile(d),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive),
                icon: const Icon(LucideIcons.logOut),
                label: const Text('Sign out everywhere else'),
                onPressed: () => setState(() => _revoked
                    .addAll(list.where((d) => !d.isCurrent).map((d) => d.id))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(DeviceSession d) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
            d.label.contains('Chrome') ? LucideIcons.monitor : LucideIcons.smartphone,
            color: d.isCurrent ? AppColors.pink : null),
        title: Row(
          children: [
            Flexible(child: Text(d.label, overflow: TextOverflow.ellipsis)),
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
        subtitle: Text('${d.os} · active ${RelativeTime.short(d.lastActive)}',
            style: theme.textTheme.labelSmall),
        trailing: d.isCurrent
            ? null
            : TextButton(
                onPressed: () => setState(() => _revoked.add(d.id)),
                child: const Text('Sign out',
                    style: TextStyle(color: AppColors.destructive)),
              ),
      ),
    );
  }
}
