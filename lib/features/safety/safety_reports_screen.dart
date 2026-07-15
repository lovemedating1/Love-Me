import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/safety_report.dart';
import '../../shared/widgets/state_views.dart';

/// 20 — SafetyReportsPage. History of the user's submitted reports + statuses.
class SafetyReportsScreen extends ConsumerWidget {
  const SafetyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(safetyReportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorView(
          message: 'Could not load reports.',
          onRetry: () => ref.invalidate(safetyReportsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: LucideIcons.shield,
              message: 'No reports submitted.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => _card(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, SafetyReport r) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: () => _detail(context, r),
        leading: const Icon(LucideIcons.flag),
        title: Text(
          r.reason,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Reported ${r.reportedName} · ${RelativeTime.short(r.createdAt)}',
        ),
        trailing: _statusBadge(r.status),
      ),
    );
  }

  Widget _statusBadge(ReportStatus s) {
    final (label, color) = switch (s) {
      ReportStatus.pending => ('Pending', AppColors.gold),
      ReportStatus.resolved => ('Resolved', AppColors.success),
      ReportStatus.dismissed => ('Dismissed', AppColors.mutedFg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _detail(BuildContext context, SafetyReport r) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.reason, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            _statusBadge(r.status),
            const SizedBox(height: 16),
            if (r.description != null) ...[
              const Text(
                'Your report',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(r.description!),
              const SizedBox(height: 16),
            ],
            if (r.adminResponse != null) ...[
              const Text(
                'Trust & Safety response',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(r.adminResponse!),
            ],
          ],
        ),
      ),
    );
  }
}
