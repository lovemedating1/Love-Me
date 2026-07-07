package com.loveme.intldating

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import org.json.JSONArray
import org.json.JSONObject

/**
 * Wraps Google Play Billing for LoveMe's premium subscriptions.
 *
 * The web app (loveme-app.com, running in the WebView) is the source of truth for the UI.
 * It talks to this manager through the AndroidNotifier JS bridge in MainActivity, and gets
 * results back via the [callback] which forwards them into the WebView as
 *   window._loveme_onPurchaseResult(json)
 *   window._loveme_onProducts(json)
 *
 * Server-side verification happens in Supabase: on a successful purchase we hand the
 * purchaseToken + productId to the web app, which posts it to the verify-purchase Edge Function.
 * We only acknowledge the purchase locally so Play does not auto-refund after 3 days; the
 * authoritative "is this user premium" decision is made by the backend, never by this client.
 */
class BillingManager(
    private val context: Context,
    private val callback: Listener
) : PurchasesUpdatedListener, BillingClientStateListener {

    interface Listener {
        /** Forward a JSON event into the WebView. eventName is the JS function to call. */
        fun onBillingEvent(eventName: String, json: String)
    }

    companion object {
        private const val TAG = "BillingManager"

        /**
         * The Play Console subscription product IDs.
         * THESE MUST EXACTLY MATCH the product IDs you create in Play Console → Subscriptions.
         * The web app passes one of these strings to purchaseSubscription().
         */
        val SUBSCRIPTION_PRODUCT_IDS = listOf(
            "basic_plus_monthly",
            "gold_monthly",
            "platinum_monthly",
            "premium_elite_monthly",
            "vip_elite_monthly"
        )
    }

    private var billingClient: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases()
        .build()

    // Cache of ProductDetails keyed by productId, filled after queryProductDetails().
    private val productDetailsMap = mutableMapOf<String, ProductDetails>()

    @Volatile
    private var isReady = false

    // A purchase requested before the client finished connecting — replayed once connected.
    private var pendingProductId: String? = null
    private var pendingActivity: Activity? = null

    fun startConnection() {
        if (billingClient.isReady) {
            isReady = true
            queryProductDetails()
            return
        }
        billingClient.startConnection(this)
    }

    fun endConnection() {
        try {
            billingClient.endConnection()
        } catch (e: Exception) {
            Log.e(TAG, "endConnection failed", e)
        }
        isReady = false
    }

    fun isBillingReady(): Boolean = isReady && billingClient.isReady

    // region BillingClientStateListener

    override fun onBillingSetupFinished(result: BillingResult) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK) {
            isReady = true
            queryProductDetails()
            // Reconcile any subscriptions the user already owns (e.g. reinstall, new device).
            queryExistingPurchases()
            // Replay a purchase the user kicked off before we were ready.
            val productId = pendingProductId
            val activity = pendingActivity
            pendingProductId = null
            pendingActivity = null
            if (productId != null && activity != null) {
                launchPurchaseFlow(activity, productId)
            }
        } else {
            isReady = false
            Log.e(TAG, "Billing setup failed: ${result.debugMessage}")
        }
    }

    override fun onBillingServiceDisconnected() {
        isReady = false
        // Try to reconnect on next interaction.
    }

    // endregion

    // region Product details

    private fun queryProductDetails() {
        val products = SUBSCRIPTION_PRODUCT_IDS.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(products)
            .build()

        billingClient.queryProductDetailsAsync(params) { result, productDetailsList ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                productDetailsMap.clear()
                for (details in productDetailsList) {
                    productDetailsMap[details.productId] = details
                }
                callback.onBillingEvent("_loveme_onProducts", buildProductsJson())
            } else {
                Log.e(TAG, "queryProductDetails failed: ${result.debugMessage}")
            }
        }
    }

    /** JSON array of available products with their localized prices, for the web UI. */
    private fun buildProductsJson(): String {
        val arr = JSONArray()
        for (details in productDetailsMap.values) {
            val offer = details.subscriptionOfferDetails?.firstOrNull()
            val phase = offer?.pricingPhases?.pricingPhaseList?.firstOrNull()
            val obj = JSONObject().apply {
                put("productId", details.productId)
                put("title", details.title)
                put("name", details.name)
                put("description", details.description)
                put("formattedPrice", phase?.formattedPrice ?: "")
                put("priceCurrencyCode", phase?.priceCurrencyCode ?: "")
                put("priceAmountMicros", phase?.priceAmountMicros ?: 0L)
                put("billingPeriod", phase?.billingPeriod ?: "")
                put("offerToken", offer?.offerToken ?: "")
            }
            arr.put(obj)
        }
        return arr.toString()
    }

    /** Synchronous getter the JS bridge can return immediately if products are already loaded. */
    fun getProductsJson(): String = buildProductsJson()

    // endregion

    // region Purchase flow

    fun launchPurchaseFlow(activity: Activity, productId: String) {
        if (!isBillingReady()) {
            // Queue it and connect; onBillingSetupFinished will replay it.
            pendingProductId = productId
            pendingActivity = activity
            startConnection()
            return
        }

        val details = productDetailsMap[productId]
        if (details == null) {
            // Details not cached yet — refresh, then ask the user to retry.
            queryProductDetails()
            emitPurchaseResult("error", productId, null, null, "Product not available yet. Please try again.")
            return
        }

        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken
        if (offerToken == null) {
            emitPurchaseResult("error", productId, null, null, "No subscription offer found for this plan.")
            return
        }

        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .setOfferToken(offerToken)
            .build()

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams))
            .build()

        val result = billingClient.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            emitPurchaseResult("error", productId, null, null, result.debugMessage)
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                if (purchases != null) {
                    for (purchase in purchases) handlePurchase(purchase)
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                emitPurchaseResult("cancelled", null, null, null, "Purchase cancelled.")
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                // User already owns it — reconcile so the backend/UI catch up.
                queryExistingPurchases()
                emitPurchaseResult("already_owned", null, null, null, "You already own this subscription.")
            }
            else -> {
                emitPurchaseResult("error", null, null, null, result.debugMessage)
            }
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) {
            // PENDING (e.g. cash/voucher) — do not grant yet; backend will hear via RTDN.
            if (purchase.purchaseState == Purchase.PurchaseState.PENDING) {
                val productId = purchase.products.firstOrNull()
                emitPurchaseResult("pending", productId, purchase.purchaseToken, purchase.orderId, "Payment pending.")
            }
            return
        }

        val productId = purchase.products.firstOrNull()

        // Tell the web app immediately so it can POST the token to verify-purchase (Supabase).
        // The backend is the source of truth; we only acknowledge below so Play doesn't refund.
        emitPurchaseResult("success", productId, purchase.purchaseToken, purchase.orderId, null)

        if (!purchase.isAcknowledged) {
            val ackParams = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            billingClient.acknowledgePurchase(ackParams) { ackResult ->
                if (ackResult.responseCode != BillingClient.BillingResponseCode.OK) {
                    Log.e(TAG, "acknowledgePurchase failed: ${ackResult.debugMessage}")
                }
            }
        }
    }

    // endregion

    // region Restore / reconcile

    /** Re-emit all subscriptions the user currently owns (used by restorePurchases and on connect). */
    fun queryExistingPurchases() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()
        billingClient.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                if (purchases.isEmpty()) {
                    emitPurchaseResult("none", null, null, null, "No active subscriptions found.")
                }
                for (purchase in purchases) {
                    if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                        val productId = purchase.products.firstOrNull()
                        emitPurchaseResult("restored", productId, purchase.purchaseToken, purchase.orderId, null)
                        // Ensure older purchases are acknowledged too.
                        if (!purchase.isAcknowledged) {
                            val ackParams = AcknowledgePurchaseParams.newBuilder()
                                .setPurchaseToken(purchase.purchaseToken)
                                .build()
                            billingClient.acknowledgePurchase(ackParams) {}
                        }
                    }
                }
            } else {
                Log.e(TAG, "queryExistingPurchases failed: ${result.debugMessage}")
            }
        }
    }

    // endregion

    private fun emitPurchaseResult(
        status: String,
        productId: String?,
        purchaseToken: String?,
        orderId: String?,
        message: String?
    ) {
        val obj = JSONObject().apply {
            put("status", status)                       // success | restored | pending | cancelled | already_owned | none | error
            put("productId", productId ?: JSONObject.NULL)
            put("purchaseToken", purchaseToken ?: JSONObject.NULL)
            put("orderId", orderId ?: JSONObject.NULL)
            put("message", message ?: JSONObject.NULL)
        }
        callback.onBillingEvent("_loveme_onPurchaseResult", obj.toString())
    }
}
