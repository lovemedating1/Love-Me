import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/billing/billing_service.dart';
import '../../core/constants/app_constants.dart';
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
/// tier badges, a green "CURRENT" ribbon on the active plan.
///
/// Real Google Play Billing added 2026-07-15 (FINAL TIER — see
/// `BACKEND_PAYMENTS_HANDOFF.md`): each plan card now has a real
/// "Subscribe" button launching the actual Play purchase flow, alongside
/// the pre-existing mock M-PESA button and the still-non-functional Wise
/// receipt-upload button (both kept per an explicit user decision — not
/// replaced, since those payment paths may still be wanted later; neither
/// is wired to anything real).
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _billingExpanded = false;
  bool _processing = false;

  /// Which plan a real purchase is currently in flight for, so only that
  /// plan's Subscribe button shows a spinner (not every button at once).
  String? _purchasingPlanId;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Map<String, ProductDetails> _products = {};
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _purchaseSub = ref
        .read(billingServiceProvider)
        .purchaseStream
        .listen(_onPurchaseUpdates, onError: (_) {});
    _loadProducts();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final billing = ref.read(billingServiceProvider);
      if (!await billing.isAvailable()) {
        if (mounted) setState(() => _loadingProducts = false);
        return;
      }
      final ids = MockData.plans.map((p) => p.googlePlayProductId).toSet();
      final products = await billing.queryProducts(ids);
      if (!mounted) return;
      setState(() {
        _products = {for (final p in products) p.id: p};
        _loadingProducts = false;
      });
    } catch (_) {
      // Play Store unavailable/misconfigured products — real Subscribe
      // buttons just won't render for the affected plans; the mock
      // M-PESA/receipt paths remain usable regardless.
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          _toast(
            'Purchase failed: ${purchase.error?.message ?? 'unknown error'}',
            error: true,
          );
        }
        setState(() => _purchasingPlanId = null);
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final plan = MockData.plans
            .where((p) => p.googlePlayProductId == purchase.productID)
            .firstOrNull;
        if (plan == null) continue;
        try {
          await ref
              .read(purchaseRepositoryProvider)
              .verifyPurchase(
                planId: plan.id,
                productId: purchase.productID,
                purchaseToken: purchase.verificationData.serverVerificationData,
              );
          ref.invalidate(currentUserProvider);
          if (mounted) {
            _toast('${plan.name} activated!');
          }
        } on PurchaseFeatureUnavailableException {
          if (mounted) {
            _toast(
              'Subscriptions aren\'t available yet — please try again soon.',
              error: true,
            );
          }
        } on PurchaseVerificationException catch (e) {
          if (mounted) _toast(e.message, error: true);
        } finally {
          // Always complete the purchase once we've attempted verification —
          // an un-completed purchase is re-delivered on every app start,
          // which would otherwise retry a permanently-rejected purchase
          // forever.
          await ref.read(billingServiceProvider).completePurchase(purchase);
          if (mounted) setState(() => _purchasingPlanId = null);
        }
      }
    }
  }

  Future<void> _subscribe(SubscriptionPlan plan) async {
    final product = _products[plan.googlePlayProductId];
    if (product == null) {
      _toast('This plan isn\'t available for purchase right now.', error: true);
      return;
    }
    setState(() => _purchasingPlanId = plan.id);
    try {
      final started = await ref
          .read(billingServiceProvider)
          .buySubscription(product);
      if (!started) {
        setState(() => _purchasingPlanId = null);
      }
      // On success, the result arrives asynchronously via purchaseStream
      // (_onPurchaseUpdates) — _purchasingPlanId is cleared there.
    } catch (_) {
      if (mounted) {
        setState(() => _purchasingPlanId = null);
        _toast('Could not start checkout — try again.', error: true);
      }
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? AppColors.destructive : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _checkout(String method) async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$method isn\'t available yet — use Subscribe on a plan above.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _receiptToast() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Receipt upload isn\'t available yet — coming soon.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final currentPlan = me?.planId == null
        ? null
        : MockData.plans.where((p) => p.id == me!.planId).firstOrNull;
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
                  child: Text(
                    'Unlock Premium',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isPremium) _renewalBanner(theme, currentPlan, me?.premiumUntil),
          if (isPremium) const SizedBox(height: 16),
          if (!isPremium) ...[_usageCard(theme), const SizedBox(height: 16)],
          for (final plan in MockData.plans)
            _planCard(theme, plan, currentPlanId: currentPlan?.id),
          const SizedBox(height: 8),
          _billingExpander(theme),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Pay with M-PESA / Airtel Money',
            icon: LucideIcons.smartphone,
            onPressed: _processing
                ? null
                : () => _checkout('M-PESA / Airtel Money'),
            loading: _processing,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _receiptToast,
            icon: const Icon(LucideIcons.upload),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Upload Order Receipt Screenshot'),
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(52),
            ),
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
            child: Text(
              'Made with ♥ By Randy',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renewalBanner(
    ThemeData theme,
    SubscriptionPlan? currentPlan,
    DateTime? premiumUntil,
  ) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.circleCheck, color: AppColors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentPlan == null
                    ? "You're currently on a premium plan"
                    : "You're currently on the ${currentPlan.name} Plan",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                premiumUntil == null
                    ? 'Renews monthly'
                    : 'Renews ${_formatDate(premiumUntil)}',
                style: const TextStyle(color: AppColors.mutedFg, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Real free-tier usage — likes remaining today / views remaining this
  /// month, from the proposed `get_like_quota`/`get_view_quota` RPCs (see
  /// `BACKEND_ATIER_HANDOFF.md` §4). Both providers resolve to `null` until
  /// those RPCs ship ([BE-10]) — in that case this card hides the numeric
  /// bars and just shows the plan's static free-tier caps, rather than the
  /// old fabricated "34/50" hardcoded numbers.
  Widget _usageCard(ThemeData theme) {
    final remainingLikes = ref.watch(remainingLikesTodayProvider).valueOrNull;
    final remainingViews = ref
        .watch(remainingViewsThisMonthProvider)
        .valueOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Free Plan Usage',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _usageRow(
            theme,
            'Likes today',
            remainingLikes,
            AppConstants.dailyLikeCap,
          ),
          const SizedBox(height: 10),
          _usageRow(
            theme,
            'Profile views this month',
            remainingViews,
            AppConstants.monthlyFreeViewCap,
          ),
        ],
      ),
    );
  }

  Widget _usageRow(ThemeData theme, String label, int? remaining, int cap) {
    final used = remaining == null ? null : (cap - remaining).clamp(0, cap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              used == null ? 'Up to $cap/period' : '$used / $cap',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedFg),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: used == null ? 0 : used / cap,
            minHeight: 6,
            backgroundColor: AppColors.mutedLight,
            color: AppColors.pink,
          ),
        ),
      ],
    );
  }

  Color _badgeColor(String? badge) => switch (badge) {
    'Silver' => AppColors.tierSilver,
    'Gold' => AppColors.tierGold,
    'Diamond' => AppColors.tierDiamond,
    'Crown' => AppColors.tierCrown,
    'VIP' => AppColors.tierVip,
    _ => AppColors.mutedFg,
  };

  Widget _planCard(
    ThemeData theme,
    SubscriptionPlan plan, {
    String? currentPlanId,
  }) {
    final isCurrent = plan.id == currentPlanId;
    final product = _products[plan.googlePlayProductId];
    final purchasing = _purchasingPlanId == plan.id;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (plan.badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _badgeColor(plan.badge),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  plan.badge!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.profileLimit == null
                              ? 'Unlimited profiles'
                              : '${plan.profileLimit} profiles',
                          style: const TextStyle(
                            color: AppColors.mutedFg,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.info, size: 18),
                    tooltip:
                        '${plan.name}: ${plan.profileLimit?.toString() ?? "Unlimited"} profiles/month',
                    onPressed: () => _planInfo(context, plan),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        product != null
                            ? product.price
                            : '\$${plan.priceUsd.toStringAsFixed(0)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('/mo', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
              if (!isCurrent && !_loadingProducts && product != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: purchasing ? null : () => _subscribe(plan),
                    child: purchasing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Subscribe'),
                  ),
                ),
              ],
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
              child: const Text(
                '✓ CURRENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
            Text(
              '${plan.name} — \$${plan.priceUsd.toStringAsFixed(0)}/mo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              plan.profileLimit == null
                  ? 'Unlimited profile views per month.'
                  : '${plan.profileLimit} profile views per month.',
            ),
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
                child: Text(
                  'Checkout Section/Billing',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                _billingExpanded
                    ? LucideIcons.chevronUp
                    : LucideIcons.chevronDown,
              ),
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedFg,
            ),
          ),
        ),
    ],
  );
}
