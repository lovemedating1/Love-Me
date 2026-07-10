import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/subscription_plan.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/sub_page_header.dart';

/// 15 — SubscriptionPage.
///
/// Rebuilt for UI parity (Phase 4, `WA0038`/`WA0039`) — see
/// UI_REBUILD_PLAN.md §4.2. Real 5-tier plans (locked in Phase 0 §0.2),
/// tier badges, a green "CURRENT" ribbon on the active plan, the M-PESA
/// payment button, and the Wise receipt-upload button (kept per Phase 0
/// §0.1 — not deleted, but not functional: no `verify-receipt-upload`
/// backend exists yet, see BACKEND_REMAINING.md [BE-4]).
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _billingExpanded = false;
  bool _processing = false;

  /// Placeholder "current plan" — same assumption the Profile card makes
  /// (Gold) until real subscription-tier tracking exists on `profiles`.
  static const _currentPlanId = 'gold';

  Future<void> _checkout(String method) async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _processing = false);
    ref.read(isPremiumProvider.notifier).state = true; // mock activation
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Payment via $method successful — Premium activated (mock).'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    context.pop();
  }

  void _receiptToast() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Receipt upload isn\'t available yet — coming soon.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    return Scaffold(
      appBar: SubPageHeader(
        title: 'Choose Your Plan',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(LucideIcons.crown, color: Colors.white, size: 18),
                SizedBox(width: 4),
                Flexible(
                  child: Text('Unlock Premium',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isPremium) _renewalBanner(theme),
          if (isPremium) const SizedBox(height: 16),
          for (final plan in MockData.plans) _planCard(theme, plan),
          const SizedBox(height: 8),
          _billingExpander(theme),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Pay with M-PESA / Airtel Money',
            icon: LucideIcons.smartphone,
            onPressed: _processing ? null : () => _checkout('M-PESA / Airtel Money'),
            loading: _processing,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _receiptToast,
            icon: const Icon(LucideIcons.upload),
            label: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Upload Order Receipt Screenshot')),
            style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Cancel anytime · Terms & Refund policy apply',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Made with ♥ By Randy',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.mutedFg)),
          ),
        ],
      ),
    );
  }

  Widget _renewalBanner(ThemeData theme) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.circleCheck, color: AppColors.success),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You're Currently on this Gold Plan",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Renews monthly',
                      style: TextStyle(color: AppColors.mutedFg, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Color _badgeColor(String? badge) => switch (badge) {
        'Silver' => AppColors.tierSilver,
        'Gold' => AppColors.tierGold,
        'Diamond' => AppColors.tierDiamond,
        'Crown' => AppColors.tierCrown,
        'VIP' => AppColors.tierVip,
        _ => AppColors.mutedFg,
      };

  Widget _planCard(ThemeData theme, SubscriptionPlan plan) {
    final isCurrent = plan.id == _currentPlanId;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16, top: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFFFFF3E8)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrent ? AppColors.success : theme.colorScheme.outline,
              width: isCurrent ? 2 : 1,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(plan.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (plan.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _badgeColor(plan.badge),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(plan.badge!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.profileLimit == null
                          ? 'Unlimited profiles'
                          : '${plan.profileLimit} profiles',
                      style: const TextStyle(color: AppColors.mutedFg, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.info, size: 18),
                tooltip: '${plan.name}: ${plan.profileLimit?.toString() ?? "Unlimited"} profiles/month',
                onPressed: () => _planInfo(context, plan),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${plan.priceUsd.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('/mo', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        if (isCurrent)
          Positioned(
            top: -6,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('✓ CURRENT',
                  style: TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }

  void _planInfo(BuildContext context, SubscriptionPlan plan) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${plan.name} — \$${plan.priceUsd.toStringAsFixed(0)}/mo',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(plan.profileLimit == null
                ? 'Unlimited profile views per month.'
                : '${plan.profileLimit} profile views per month.'),
          ],
        ),
      ),
    );
  }

  Widget _billingExpander(ThemeData theme) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _billingExpanded = !_billingExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Checkout Section/Billing',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Icon(_billingExpanded
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown),
                ],
              ),
            ),
          ),
          if (_billingExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Billed monthly. Cancel anytime from Settings → Subscription. '
                'Prices shown in USD; local currency conversion applied at checkout.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.mutedFg),
              ),
            ),
        ],
      );
}
