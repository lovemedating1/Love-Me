import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';

/// 21 — DeleteAccountPage. Two-step irreversible deletion: reason + password +
/// type "DELETE". Mock: signs out and returns to /auth.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _reason;
  bool _deleting = false;

  static const _reasons = [
    'Found someone',
    'Taking a break',
    'Not enough matches',
    'Privacy concerns',
    'Other',
  ];

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _confirm.text.trim() == 'DELETE' && _password.text.isNotEmpty;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ref.read(authControllerProvider.notifier).signOut();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Your account has been deleted.'),
      behavior: SnackBarBehavior.floating,
    ));
    // Guard will route to /auth after sign-out.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.destructive),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.triangleAlert, color: AppColors.destructive),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This is permanent. Your profile, matches, messages, and '
                    'photos will be erased and cannot be recovered.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Why are you leaving? (optional)',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Select a reason'),
            items: [
              for (final r in _reasons)
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => setState(() => _reason = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Confirm your password',
                prefixIcon: Icon(LucideIcons.lock)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
                prefixIcon: Icon(LucideIcons.type)),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: (_canDelete && !_deleting) ? _delete : null,
            child: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Delete my account'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _deleting ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
