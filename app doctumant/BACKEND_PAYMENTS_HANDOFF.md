# Love Me International — Subscription/Payments (FINAL TIER) Backend Requirements

**Date:** 2026-07-15
**From:** Flutter (client) team
**Purpose:** Everything Supabase (Postgres + an Edge Function with a Google
service account secret) needs to build so the **already-built** real
Google Play Billing client can actually grant premium. This is the
**FINAL TIER** — the last item on the launch tier list, deliberately
tackled after every other feature (safety, discovery, chat, verification,
etc.) was done. Android-only target confirmed (iOS explicitly out of
scope for the whole project right now).

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## 0. TL;DR — what you need to build

| # | Item | Type | Blocker? |
|---|---|---|---|
| 1 | `profiles.plan_id` column (+ confirm `is_premium`/`premium_until` are already correctly used) | Schema | **Yes** |
| 2 | `verify-purchase` Edge Function (Google Play Developer API, server-side only) | Edge Function + secret | **Yes** |
| 3 | Real-Time Developer Notifications (RTDN) webhook — renewals/cancellations/refunds | Edge Function + Pub/Sub | No (launch without it, but plans will silently go stale without it) |

The client-side purchase flow (query products → launch Play purchase UI →
listen for the result → send the purchase token to `verify-purchase`) is
fully built and merged. Nothing works end-to-end until §1 and §2 exist.

---

## 1. Locked plan tiers → Google Play product IDs

This is the exact, locked pricing the client is built against — please
create these 5 as **subscription products** in the Google Play Console
under this app's listing, with these exact product IDs (the client's
`SubscriptionPlan.googlePlayProductId` values are hardcoded to match):

| `plan_id` (internal) | Google Play product ID | Price (USD) | KES (reference, Paystack-equivalent) | `profiles_limit` | `likes_visible` |
|---|---|---|---|---|---|
| `basic_plus` | `basic_plus_monthly` | $5 | 650 | 500 | 500 |
| `gold` | `gold_monthly` | $10 | 1,300 | 1,000 | 1,000 |
| `platinum` | `platinum_monthly` | $15 | 1,950 | 1,500 | 1,500 |
| `premium_elite` | `premium_elite_monthly` | $20 | 2,600 | 2,500 | 2,500 |
| `vip_elite` | `vip_elite_monthly` | $25 | 3,250 | unlimited | unlimited |

All 5 are monthly auto-renewing subscriptions. The actual price shown to
the user comes from Google Play's own pricing (set per-product in the
Play Console, in whatever currencies you configure) — the USD figures
above are the reference/locked price point, not something the client
sends at purchase time.

**No Paystack/M-PESA product IDs exist in this table on purpose** — those
payment paths stay mock UI for now (kept in the app per an explicit user
decision, not wired to anything real). This doc is Google Play Billing
only.

---

## 2. `profiles.plan_id` column

### 2.1 Why

`profiles.is_premium` (boolean) and `profiles.premium_until` (timestamp)
already exist and are already read by the client — but neither says
**which** of the 5 tiers a premium user is on, and the 5 tiers have
different `profiles_limit`/`likes_visible` caps that matter elsewhere in
the app (Discover's profile cap copy, Likes' blur gate). This is the one
missing piece of schema.

### 2.2 Migration

```sql
alter table public.profiles
  add column if not exists plan_id text
    check (plan_id is null or plan_id in (
      'basic_plus', 'gold', 'platinum', 'premium_elite', 'vip_elite'
    ));
```

No RLS change needed — same owner-scoped UPDATE / open SELECT policy
already covers this column, same as the extended-profile-fields pass. This
column is **never written by the client directly** — only `verify-purchase`
(service role, §3 below) sets it, alongside `is_premium`/`premium_until`
in the same update.

### 2.3 Wire shape

`Profile.fromJson` already reads `json['plan_id']` (client change already
made) — `GET /rest/v1/profiles?select=is_premium,premium_until,plan_id&user_id=eq.<uuid>`.

---

## 3. `verify-purchase` Edge Function

### 3.1 Why this must be server-side, not client-side

A client can never be trusted to say "I paid, please believe me" — anyone
could fake that call. The Google Play Developer API is the only
authoritative way to confirm a purchase token is real, unconsumed by
another account, and matches the claimed product — and calling it requires
a **Google Cloud service account JSON key with the "View financial data"
role on this app's Play Console listing**, which must never exist
client-side (same category of secret as the Agora App Certificate,
already handled correctly elsewhere in this app — server-only, no
exceptions).

### 3.2 What the client sends

```dart
await Supabase.instance.client.functions.invoke('verify-purchase', body: {
  'plan_id': 'gold',                 // one of the 5 locked ids, client-supplied
  'product_id': 'gold_monthly',       // the Google Play product id
  'purchase_token': '<opaque token from Play, ~100-500 chars>',
});
```

### 3.3 What the function must do

1. Resolve the caller's `user_id` from the request's JWT.
2. Call the **Google Play Developer API**
   (`purchases.subscriptions.get`, or `purchases.subscriptionsv2.get` for
   the newer API — either is fine, `subscriptionsv2` is the
   forward-looking choice) with the service account credential, passing
   the package name (`com.loveme.international`), `product_id`, and
   `purchase_token` from the request body.
3. Verify:
   - The response's subscription state is active (not expired/cancelled/
     on hold — Google's API returns an explicit state for this).
   - The `product_id` in the response matches what the client claimed
     (don't trust the client's `plan_id`/`product_id` pairing blindly —
     look up the plan_id from your own `product_id → plan_id` mapping
     server-side, in case a modified client tried to claim a cheaper
     product bought a more expensive plan).
   - This exact `purchase_token` hasn't already been consumed by a
     **different** `user_id` (store a unique constraint on the token so a
     replayed/shared token can't grant premium to two accounts).
4. On success: `UPDATE profiles SET is_premium = true, premium_until = <subscription's expiry from the API response>, plan_id = <resolved plan_id> WHERE user_id = <caller>`.
5. **Acknowledge the purchase with Google** (`purchases.subscriptions.acknowledge`)
   if not already acknowledged — Google auto-refunds unacknowledged
   subscriptions after ~3 days, so this step is not optional.
6. Return `{"plan_id": "gold", "premium_until": "2026-08-15T00:00:00Z"}` on
   success (exact shape the client expects — see `PurchaseVerificationRepository`
   below), or a non-2xx with a JSON body `{"message": "<user-facing reason>"}`
   on rejection (invalid token, already-used token, product/plan mismatch,
   Google API error).

### 3.4 Recommended: a `purchases` table for auditing/idempotency

Not strictly required for the client to function, but strongly
recommended so step 3's "already consumed by a different user" check has
somewhere to look:

```sql
create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  plan_id text not null,
  product_id text not null,
  purchase_token text not null unique,
  verified_at timestamptz not null default now(),
  premium_until timestamptz not null
);
```

No client access needed — this table is purely for `verify-purchase`'s
own bookkeeping (service role only), so RLS can just be `enable row level
security` with no policies (deny-all to `authenticated`/`anon`).

### 3.5 Client code already wired

- `lib/core/billing/billing_service.dart` (NEW) — thin wrapper around
  `in_app_purchase`: `isAvailable()`, `queryProducts()` (throws
  `ProductNotFoundException` if a product id has no Play Console listing),
  `buySubscription()`, `completePurchase()`, `restorePurchases()`,
  `purchaseStream`.
- `lib/shared/data/purchase_repository.dart` (NEW) —
  `SupabasePurchaseRepository.verifyPurchase()` invokes `verify-purchase`
  with the exact body shape in §3.2, expects the exact response shape in
  §3.3 step 6. Maps a 404 to `PurchaseFeatureUnavailableException` ("not
  available yet" UI) and any other non-2xx to `PurchaseVerificationException`
  (shows the backend's `message` directly).
- `lib/features/subscription/subscription_screen.dart` — REWRITTEN:
  queries real Play prices per plan (falls back to the static USD price if
  the Play listing isn't live/found), each non-current plan gets a real
  "Subscribe" button, listens to `purchaseStream` for the async result,
  calls `verifyPurchase()` on a completed purchase, invalidates
  `currentUserProvider` on success so the real `is_premium`/`plan_id`
  show immediately, and always calls `completePurchase()` regardless of
  verification outcome (an un-acknowledged purchase is re-delivered by the
  Play Billing Library on every app start otherwise). The pre-existing
  mock M-PESA button and dead-end Wise receipt-upload button are
  **unchanged** — kept per an explicit user decision, still fully mock,
  not part of this doc's scope.
- `lib/shared/models/profile.dart` — new `planId` field (read-only,
  `profiles.plan_id`), reads via `fromJson`, never written by
  `toInsertJson`/`updateMyProfile` (matches §2.2's "client never writes
  this column directly").
- `lib/shared/data/repositories.dart` — `isPremiumProvider` is no longer a
  local mock `StateProvider<bool>` that a screen could just flip — it's
  now derived from the real `profiles.is_premium` via `currentUserProvider`.
  This was a real gap found while wiring real billing: the old mock
  toggle had no connection to the real column at all.
- Android: `com.android.vending.BILLING` permission added to
  `AndroidManifest.xml` (required for `BillingClient` to connect at all).

**Until §2/§3 exist**, the Subscribe buttons either don't render (if
`queryProducts()` fails entirely) or render but end in "Subscriptions
aren't available yet — please try again soon." on purchase completion —
no crash, no silently-granted premium, no charge without a working
verification path (Google still processes the payment even if
verification fails, so this failure mode does mean a real charge with no
premium granted — see §4 for why the RTDN webhook matters for cleaning
this up if it happens during a gap in service).

---

## 4. Real-Time Developer Notifications (RTDN) — recommended, not a launch blocker

### 4.1 Why

`verify-purchase` only runs once, at the moment of purchase. A
subscription can later renew, get cancelled, go on a payment-failure
grace period, or get refunded — none of which re-invokes the client. Without
RTDN, a user who cancels via the Play Store (not through the app) keeps
`is_premium = true` in your database until their `premium_until` timestamp
naturally passes, and a renewal doesn't extend `premium_until` at all
(the client only reads it, never re-verifies on a schedule).

### 4.2 What this needs

1. A Cloud Pub/Sub topic configured in the Play Console (Monetization
   setup → Real-time developer notifications) for this app.
2. A Supabase Edge Function subscribed to that topic (or a small relay —
   Pub/Sub push subscriptions can call an HTTPS endpoint directly, which an
   Edge Function URL satisfies) that parses the notification type
   (`SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_CANCELED`, `SUBSCRIPTION_ON_HOLD`,
   `SUBSCRIPTION_REVOKED`, etc.) and updates `profiles.is_premium`/
   `premium_until`/`plan_id` accordingly — e.g. `SUBSCRIPTION_REVOKED` →
   `is_premium = false` immediately, `SUBSCRIPTION_RENEWED` → extend
   `premium_until` to the new expiry.

### 4.3 Recommendation

Launch without this (every other A/B/C-tier feature followed the same
"ship the blocking piece first, iterate" pattern) — but flag it as the
very next payments-related priority once §2/§3 are live, since without it
plan status will silently drift from reality over time (mostly in the
"user cancelled but still shows premium" direction, which is a revenue/
trust risk, not just a display bug).

---

## 5. Summary for planning

§1 (schema) and §2 (Edge Function) together are the launch-blocking pair —
neither is useful alone (a purchase with nowhere to verify, or a column
nothing ever writes to). §3 (RTDN) is real but can follow once the core
loop works. No changes needed to any other already-shipped feature —
billing was built as its own vertical slice on top of the existing
`profiles` table and Edge Function pattern already used for
`get-agora-token`/`delete-account`.
