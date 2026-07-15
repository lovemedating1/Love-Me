import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/sub_page_header.dart';
import '../auth/auth_controller.dart';

/// 21 — DeleteAccountPage.
///
/// Rebuilt for UI parity (Phase 5, `WA0062`) — see UI_REBUILD_PLAN.md §5.3:
/// white header + a single "Danger Zone" card with the 5-bullet consequence
/// list + a solid-red "Delete My Account" button. Per Phase 0 §0.4 #11 the
/// password field, type-"DELETE" confirmation, and reason dropdown are all
/// REMOVED (the old app has none of them) — a plain confirm dialog stands
/// in as the only "are you sure" gate.
///
/// Calls [AuthController.deleteAccount], which invokes the proposed
/// `delete-account` Edge Function (see `BACKEND_ATIER_HANDOFF.md` §3). That
/// function doesn't exist server-side yet ([BE-7]) — a 404 is caught and
/// shown as "not available yet" rather than a raw error, so the screen is
/// honest about today's state while still being fully wired for when
/// backend ships it.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _deleting = false;

  static const _consequences = [
    'Your profile and photos will be permanently removed',
    'All your matches and conversations will be erased',
    'Your likes and interactions will be permanently deleted',
    'This action cannot be undone',
    'You will need to create a new account to use Love Me again',
  ];

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This is permanent and cannot be undone. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Guard will route to /auth after sign-out.
    } on FunctionException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final notFound = e.status == 404;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notFound
                ? 'Account deletion isn\'t available yet — please contact support.'
                : 'Could not delete your account — try again.',
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your account — try again.'),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SubPageHeader(title: 'Delete Account', actions: const []),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.destructive.withValues(alpha: 0.3),
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      color: AppColors.destructive,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        color: AppColors.destructive,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final c in _consequences)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '•  ',
                          style: TextStyle(color: AppColors.destructive),
                        ),
                        Expanded(child: Text(c)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.destructive,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _deleting ? null : _confirmAndDelete,
                    child: _deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Delete My Account'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
