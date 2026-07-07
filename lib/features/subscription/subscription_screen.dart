import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../shared/data/mock_data.dart';
import '../../shared/data/repositories.dart';
import '../../shared/models/subscription_plan.dart';

/// 15 — SubscriptionPage. Perks, plan cards (duration tiers — PLACEHOLDER names,
/// see SubscriptionPlan doc note), payment-method buttons (UI only), trial usage.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _selectedPlan = 'quarterly';
  bool _processing = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium'),
        leading: IconButton(
            icon: const Icon(LucideIcons.x), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hero(theme),
          const SizedBox(height: 20),
          Text('Choose your plan', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final plan in MockData.plans) _planCard(theme, plan),
          const SizedBox(height: 20),
          Text('Payment method', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _payButton('Pay with M-PESA / Card', LucideIcons.smartphone, 'Paystack'),
          _payButton('PayPal', LucideIcons.wallet, 'PayPal'),
          _payButton('Wise (bank transfer)', LucideIcons.landmark, 'Wise'),
          _payButton('Google Play Billing', LucideIcons.play, 'Google Play'),
          const SizedBox(height: 20),
          Text('Your free usage', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _usage(theme, 'Likes today', 34, 50),
          _usage(theme, 'Profile views this month', 41, 50),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Cancel anytime · Terms & Refund policy apply',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(ThemeData theme) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: AppGradients.premium,
            borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.crown, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text('Love Me Premium',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            for (final perk in MockData.premiumPerks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(LucideIcons.check, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(perk, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _planCard(ThemeData theme, SubscriptionPlan plan) {
    final selected = _selectedPlan == plan.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.pink : theme.colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              color: selected ? AppColors.pink : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.name, style: theme.textTheme.titleMedium),
                      if (plan.popular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              gradient: AppGradients.gold,
                              borderRadius: BorderRadius.circular(999)),
                          child: const Text('Most Popular',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  if (plan.savingsLabel != null)
                    Text(plan.savingsLabel!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.success)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${plan.priceUsd.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge),
                Text('/ ${plan.period}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _payButton(String label, IconData icon, String method) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton.icon(
          onPressed: _processing ? null : () => _checkout(method),
          icon: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon),
          label: Align(
              alignment: Alignment.centerLeft, child: Text(label)),
          style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(52)),
        ),
      );

  Widget _usage(ThemeData theme, String label, int used, int cap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                Text('$used / $cap', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: used / cap,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: AppColors.pink,
              ),
            ),
          ],
        ),
      );
}
