import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/data/repositories.dart';

/// 22 — AdminDiagnosticsPage. Admin-only tabbed diagnostics. Non-admins get a
/// 403 view. Mock: toggle isAdminProvider to preview the admin content.
class AdminDiagnosticsScreen extends ConsumerWidget {
  const AdminDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) return _forbidden(context, ref);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Diagnostics'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Payments'),
              Tab(text: 'GPS'),
              Tab(text: 'Push'),
              Tab(text: 'Emails'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LogList(entries: [
              ('OK', 'paystack-checkout · LM-20260704-0007 · \$24.99'),
              ('OK', 'paypal-webhook · CAPTURE.COMPLETED'),
              ('WARN', 'wise-verify-ai · low confidence 0.62'),
            ]),
            _LogList(entries: [
              ('OK', 'gps_telemetry · accuracy 8m · Nairobi'),
              ('OK', 'gps_telemetry · accuracy 22m · Lagos'),
            ]),
            _LogList(entries: [
              ('OK', 'push-notifications · sent 2 · failed 0'),
              ('ERR', 'fcm token UNREGISTERED · pruned'),
            ]),
            _LogList(entries: [
              ('OK', 'process-email-queue · drained 5'),
              ('OK', 'send-transactional-email · welcome'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _forbidden(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Admin Diagnostics')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.lock, size: 56, color: AppColors.destructive),
                const SizedBox(height: 16),
                Text('403 — Admins only',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('You need the admin role to view diagnostics.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 20),
                // Demo aid so the admin UI is reviewable without a backend.
                OutlinedButton(
                  onPressed: () =>
                      ref.read(isAdminProvider.notifier).state = true,
                  child: const Text('Preview as admin (demo)'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _LogList extends StatelessWidget {
  const _LogList({required this.entries});
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) => ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final (level, msg) = entries[i];
          final color = switch (level) {
            'OK' => AppColors.success,
            'WARN' => AppColors.gold,
            _ => AppColors.destructive,
          };
          return ListTile(
            dense: true,
            leading: Text(level,
                style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            title: Text(msg, style: const TextStyle(fontFamily: 'monospace')),
          );
        },
      );
}
