import 'package:equatable/equatable.dart';

/// A premium plan tier.
///
/// Real 5-tier data, LOCKED by the user against the old app screenshots
/// (UI_REBUILD_PLAN.md §0.2) — supersedes the earlier duration-based
/// Monthly/Quarterly/Yearly placeholder. Free tier's profile limit is still
/// unknown (flagged, not guessed).
class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceUsd,
    required this.period,
    required this.badge,
    this.profileLimit,
    this.popular = false,
    this.savingsLabel,
  });

  final String id;
  final String name;
  final double priceUsd;
  final String period; // 'month' | '3 months' | 'year'

  /// Tier badge shown next to the plan name (Silver/Gold/Diamond/Crown/VIP).
  /// `null` for the Free tier, which has no badge in the old app.
  final String? badge;

  /// Profiles/month this plan unlocks. `null` = unlimited (VIP Elite) or
  /// unknown (Free — not yet confirmed with the user).
  final int? profileLimit;

  final bool popular;
  final String? savingsLabel;

  @override
  List<Object?> get props => [id, name, priceUsd, period, badge, profileLimit];
}
