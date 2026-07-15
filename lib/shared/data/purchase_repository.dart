import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Server-side verification result for a submitted purchase.
class VerifiedPurchase {
  const VerifiedPurchase({required this.planId, required this.premiumUntil});
  final String planId;
  final DateTime premiumUntil;
}

/// Thrown when the `verify-purchase` Edge Function rejects a purchase
/// (invalid/already-used token, product/plan mismatch, Google Play
/// Developer API error, etc.) — the message is safe to show the user
/// as-is (backend is expected to return a user-facing reason).
class PurchaseVerificationException implements Exception {
  const PurchaseVerificationException(this.message);
  final String message;
}

/// Sends a completed Google Play purchase to the backend for verification
/// — this client NEVER grants premium itself. See
/// `BACKEND_PAYMENTS_HANDOFF.md` §2: the Edge Function calls the Google
/// Play Developer API server-side (requires a service account credential
/// that must never exist client-side) to confirm the purchase token is
/// genuine, not already consumed by another account, and matches the
/// claimed product id — only then does it update `profiles.plan_id`/
/// `is_premium`/`premium_until`.
abstract interface class PurchaseRepository {
  Future<VerifiedPurchase> verifyPurchase({
    required String planId,
    required String productId,
    required String purchaseToken,
  });
}

/// Thrown when `verify-purchase` doesn't exist yet (404) — lets the UI
/// show "not available yet" instead of a raw error while backend ships it.
class PurchaseFeatureUnavailableException implements Exception {
  const PurchaseFeatureUnavailableException();
}

class SupabasePurchaseRepository implements PurchaseRepository {
  const SupabasePurchaseRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<VerifiedPurchase> verifyPurchase({
    required String planId,
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'verify-purchase',
        body: {
          'plan_id': planId,
          'product_id': productId,
          'purchase_token': purchaseToken,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic> &&
          data['plan_id'] != null &&
          data['premium_until'] != null) {
        return VerifiedPurchase(
          planId: data['plan_id'] as String,
          premiumUntil: DateTime.parse(data['premium_until'] as String),
        );
      }
      throw const PurchaseVerificationException(
        'Malformed verification response.',
      );
    } on sb.FunctionException catch (e) {
      if (e.status == 404) throw const PurchaseFeatureUnavailableException();
      final message =
          (e.details is Map && (e.details as Map)['message'] != null)
          ? (e.details as Map)['message'] as String
          : 'Could not verify your purchase — please contact support.';
      throw PurchaseVerificationException(message);
    }
  }
}
