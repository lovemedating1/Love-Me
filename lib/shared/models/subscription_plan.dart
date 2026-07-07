import 'package:equatable/equatable.dart';

/// A premium plan tier.
///
/// NOTE: the docs conflict on plan naming (Backend: Premium/VIP/Elite; roadmap:
/// Free/Basic+/Gold/... ; screen JSON: duration-based Monthly/Quarterly/Yearly).
/// Phase 3 uses the screen-JSON duration model with a single "Premium" product
/// as PLACEHOLDER tiers — to be reconciled with the user before backend wiring.
class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceUsd,
    required this.period,
    this.popular = false,
    this.savingsLabel,
  });

  final String id;
  final String name;
  final double priceUsd;
  final String period; // 'month' | '3 months' | 'year'
  final bool popular;
  final String? savingsLabel;

  @override
  List<Object?> get props => [id, name, priceUsd, period];
}
