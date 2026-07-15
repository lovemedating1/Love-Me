import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Thrown when the device's Play Store connection isn't available (no
/// Play Store app, not signed in, etc.) — surfaced as a specific message
/// rather than a generic failure.
class BillingUnavailableException implements Exception {
  const BillingUnavailableException();
}

/// Thrown when a requested product id has no matching Google Play Console
/// listing — either a real misconfiguration, or (very likely during
/// development) the Play Console listing simply isn't live/propagated yet.
class ProductNotFoundException implements Exception {
  const ProductNotFoundException(this.productId);
  final String productId;
}

/// Thin wrapper around `in_app_purchase` — real Google Play Billing.
///
/// This client never verifies a purchase itself (that requires the Google
/// Play Developer API + a service account, which must live server-side
/// only — see `BACKEND_PAYMENTS_HANDOFF.md` §2). This class's job stops at:
/// query product prices, launch the purchase UI, and hand the resulting
/// [PurchaseDetails] (with its server-verifiable purchase token) to
/// whoever calls [purchaseStream] — `SubscriptionScreen` sends that token
/// to the `verify-purchase` Edge Function, which is the only thing
/// actually allowed to grant premium.
class BillingService {
  BillingService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  /// Real-time purchase status updates — subscribe once at app start (or
  /// screen-open) and keep the subscription for the lifetime of the
  /// listener, per the package's own guidance (a dropped subscription can
  /// miss a purchase completed outside the app, e.g. via the Play Store).
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Looks up live prices/titles for the given Google Play product ids.
  /// Throws [ProductNotFoundException] (for the first missing id) if any
  /// requested id has no matching Play Console listing.
  Future<List<ProductDetails>> queryProducts(Set<String> productIds) async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.notFoundIDs.isNotEmpty) {
      throw ProductNotFoundException(response.notFoundIDs.first);
    }
    return response.productDetails;
  }

  /// Launches the Google Play purchase sheet for a subscription. Does NOT
  /// return the purchase result directly — per the package's design,
  /// results (including this one) arrive via [purchaseStream]. Returns
  /// whether the purchase request was successfully *initiated*, not
  /// whether it succeeded.
  Future<bool> buySubscription(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Must be called once a purchase has been delivered (i.e. verified +
  /// premium granted server-side) — an un-completed purchase is
  /// re-delivered via [purchaseStream] on every app start.
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  /// Restores prior purchases (e.g. after a reinstall) — results also
  /// arrive via [purchaseStream] with [PurchaseStatus.restored].
  Future<void> restorePurchases() => _iap.restorePurchases();
}

final billingServiceProvider = Provider<BillingService>(
  (ref) => BillingService(),
);
