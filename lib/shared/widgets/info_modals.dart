import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/route_paths.dart';
import '../../core/theme/app_colors.dart';
import 'gradient_button.dart';

/// The remaining old-app modals (Phase 5 §5.2): location permission,
/// "Get Verified" promo, and the two header-pill expiry explainers.
class InfoModals {
  InfoModals._();

  /// "Find people nearby" location-permission modal (old app: `3`).
  static Future<void> locationPermission(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.chipPinkBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.mapPin,
                  color: AppColors.pink,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Find people nearby',
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Turn on location so we can show you matches close to you and '
                'let others discover you nearby.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedFg),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Enable Now',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );

  /// "Get Verified" promo modal (old app: `WA0041`).
  static Future<void> getVerified(BuildContext context) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.chipYellowBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              color: AppColors.pink,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Get Verified',
            style: Theme.of(
              ctx,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verified profiles get more matches and appear higher in '
            'Discover. It only takes a couple of minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedFg),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Verify Now',
            icon: LucideIcons.shield,
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(RoutePaths.settings);
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    ),
  );

  /// Account-expiry modal (old app: `WA0046`) — explains the header's 📅
  /// pill. The pill itself never renders yet (no backing field), but the
  /// explainer is built so the pill can wire straight to it once it does.
  static Future<void> accountExpiry(BuildContext context, {int? daysLeft}) =>
      showDialog(
        context: context,
        builder: (ctx) => _ExpiryDialog(
          icon: LucideIcons.calendar,
          title: daysLeft == null
              ? 'Your account is expiring soon'
              : '$daysLeft days until your account expires',
          body:
              'Inactive accounts are removed after 90 days. Sign in '
              'again before then to keep your profile, matches, and '
              'messages.',
        ),
      );

  /// Subscription-expiry modal (old app: `WA0054`) — explains the header's
  /// 🕐 pill, driven by the real `profiles.premium_until` field.
  static Future<void> subscriptionExpiry(
    BuildContext context, {
    required DateTime expiresAt,
  }) => showDialog(
    context: context,
    builder: (ctx) => _ExpiryDialog(
      icon: LucideIcons.clock,
      title: 'Your plan renews on ${_formatDateTime(expiresAt)}',
      body:
          'Your subscription will automatically renew unless you '
          'cancel from Manage Subscription.',
      showClose: true,
    ),
  );

  static String _formatDateTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day}/${d.year}, $h:$m $ampm';
  }

  /// "90-Day Data Policy" modal — shown once over the Auth screen (old app:
  /// pops up over Login on first view). Explains that inactive accounts are
  /// purged after 90 days and can re-signup with the same email.
  static Future<void> dataPolicy(BuildContext context) => showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '📌 90-Day Data Policy',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const Icon(Icons.close, color: AppColors.mutedFg),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Your account data is automatically deleted after 90 '
                'days from signup. You\'ll be notified daily of your '
                'remaining days. After expiry, you can sign up again '
                'with a fresh account — even using the same email '
                'address you used before.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedFg, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'I Understand',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExpiryDialog extends StatelessWidget {
  const _ExpiryDialog({
    required this.icon,
    required this.title,
    required this.body,
    this.showClose = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.chipPinkBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.pink, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedFg),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (showClose) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: GradientButton(
                    label: 'Got it',
                    height: 46,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
