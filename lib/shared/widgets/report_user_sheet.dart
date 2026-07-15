import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../data/repositories.dart';
import '../models/safety_report.dart';

/// Shared "Report user" bottom sheet — reason picker + optional description
/// + an "also block" checkbox. Used from Discover's report chip, the chat
/// safety modal, and the profile-detail preview modal, so there is exactly
/// one report-submission surface in the app.
///
/// Calls [SafetyRepository.submitReport] (see `BACKEND_ATIER_HANDOFF.md` §1)
/// — shows "not available yet" if the `reports` table doesn't exist server
/// side yet, rather than a raw error.
class ReportUserSheet extends ConsumerStatefulWidget {
  const ReportUserSheet({
    super.key,
    required this.reportedUserId,
    required this.reportedName,
    this.preselectBlock = false,
  });

  final String reportedUserId;
  final String reportedName;

  /// Pre-checks "Also block this user" — used by the chat safety modal's
  /// "Report & Block" entry point.
  final bool preselectBlock;

  /// Shows the sheet; returns `true` if a report was submitted.
  static Future<bool?> show(
    BuildContext context, {
    required String reportedUserId,
    required String reportedName,
    bool preselectBlock = false,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReportUserSheet(
      reportedUserId: reportedUserId,
      reportedName: reportedName,
      preselectBlock: preselectBlock,
    ),
  );

  @override
  ConsumerState<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends ConsumerState<ReportUserSheet> {
  ReportReason? _reason;
  late bool _alsoBlock = widget.preselectBlock;
  final _description = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Please choose a reason.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(safetyRepositoryProvider)
          .submitReport(
            reportedUserId: widget.reportedUserId,
            reportedName: widget.reportedName,
            reason: reason,
            description: _description.text,
            alsoBlock: _alsoBlock,
          );
      ref.invalidate(safetyReportsProvider);
      if (_alsoBlock) ref.invalidate(blockedUsersProvider);
      if (mounted) Navigator.pop(context, true);
    } on SafetyFeatureUnavailableException {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Reporting isn\'t available yet — please try again soon.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Could not submit — try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldAlert, color: AppColors.destructive),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report ${widget.reportedName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Reason', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in ReportReason.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: _reason == r,
                  onSelected: _submitting
                      ? null
                      : (sel) => setState(() => _reason = sel ? r : null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              alignLabelWithHint: true,
            ),
          ),
          CheckboxListTile(
            value: _alsoBlock,
            onChanged: _submitting
                ? null
                : (v) => setState(() => _alsoBlock = v ?? false),
            title: const Text('Also block this user'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }
}
