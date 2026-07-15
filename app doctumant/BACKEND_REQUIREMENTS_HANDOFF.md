# Love Me International — Backend Requirements Handoff

**Date:** 2026-07-11
**From:** Flutter client team
**Purpose:** Consolidated list of everything the backend (Supabase) side needs to
build so the client can stop working around missing pieces. This supersedes
piecemeal asks — it's the full picture in one place.

**Ground rules for the client team (context for you, the backend team, too):**
the Flutter app is a pure client over Supabase. It never touches SQL, RLS, Edge
Functions, or schema directly — everything below has to be built and deployed
on your side before the corresponding client code can go live. Where the client
already has code written and waiting (a "seam"), that's called out explicitly.

Project ref: `tamlbnmihdcjiptbezjm`. Existing live tables (13, per migrations
001-019): `profiles`, `active_sessions`, `user_presence`, `likes`, `passes`,
`matches`, `profile_views`, `conversations`, `messages`, `message_reads`,
`message_reactions`, `call_logs`, `profile_photos`, `notifications`,
`notification_preferences`. Two triggers already live and working:
`create_match_on_mutual_like`, `create_conversation_on_match`. Five storage
buckets live: `avatars` (public), `chat-images`, `chat-files`,
`chat-file-thumbs`, `voice-messages` (private, signed URLs).

---

## Priority 1 — Launch blockers

### 1.1 Image moderation (`moderate-image`)

**Why it's P1:** Google Play policy requires content moderation on a dating
app with user-uploaded photos. Nothing currently scans uploads server-side —
the client only does an on-device "is there a face" check, which is trivial
to bypass and not a real safety control.

**Need:** An Edge Function (webhook on storage upload is the recommended
trigger — no client change required) that runs an NSFW/inappropriate-content
classifier against new uploads to `avatars`, `chat-images`, `chat-file-thumbs`
before they're visible to other users, and flags/quarantines failures into a
`content_flags` table for admin review.

### 1.2 Payments / subscriptions

**Why it's P1:** There is currently no revenue mechanism at all — the
"Subscribe" button just flips a local boolean after a fake delay. The app has
zero way to actually charge anyone or verify a real purchase.

**The 5 plan tiers are locked client-side** (do not change these — they're
already shown to users and match the old app's screenshots):

| id | name | price/mo | badge | profile-view limit |
|---|---|---|---|---|
| `basic_plus` | Basic+ | $5 | Silver | 500 |
| `gold` | Gold | $10 | Gold | 1000 |
| `platinum` | Platinum | $15 | Diamond | 1500 |
| `premium_elite` | Premium Elite | $20 | Crown | 2000 |
| `vip_elite` | VIP Elite | $25 | VIP | Unlimited |

A **Free tier also exists** but its exact profile-view cap was never
confirmed with the product owner — please confirm before enforcing it.

**Need:**
- `subscriptions` table: user_id, plan_id, status (active/expired/cancelled),
  started_at, expires_at, store (paystack/paypal/google_play/wise/etc.),
  store_reference/token.
- `payment_events` table for webhook/audit trail.
- Payment provider integration(s) — decide which of Paystack / PayPal /
  Checkout.com / Flutterwave / Google Play Billing you're actually
  supporting at launch (the original spec lists all of them; the client
  doesn't need all of them day one — tell us which ones so we can build the
  matching checkout UI).
- `has_active_premium` RPC the client can call to gate premium features
  server-side (not just trust a local boolean).
- A cron/scheduled function to expire subscriptions past `expires_at`.
- If Google Play Billing is included: a `verify-purchase` Edge Function.
- If Wise (bank transfer) is included: `wise_payment_requests` table +
  manual verification flow (client already has an "Upload Order Receipt"
  button stubbed with a "coming soon" toast, waiting on this).

### 1.3 Free-tier quota enforcement

**Why it's P1:** Right now free users have **unlimited likes and profile
views** — there's no enforcement anywhere, client or server. The UI displays
"50/day" and "50/month" as static text only.

**Need — these exact numbers, already shown to users, must match:**
- `can_send_like` RPC — 50 likes per rolling 24h for free tier.
- `record_profile_view` RPC — 50 profile views per month for free tier
  (the `profile_views` table already exists and is populated with columns
  ready for this: `profiles.profiles_viewed_count` /
  `profiles_viewed_reset_at` already exist on the live `profiles` table —
  just need the RPC to use them).
- `can_send_message` RPC — free tier should only be able to message mutual
  matches (already true structurally since conversations only exist for
  matches), but confirm no other messaging gate is expected per plan tier.

---

## Priority 2 — Core safety & account features

### 2.1 Safety reports

**Why:** The Reports screen is fully built in the app but is reading fake
data — there is no way for a user to actually submit a report today.

**Client already expects this exact shape** (from `SafetyReport` model):
- `reports` table: `id`, `reporter_id`, `reported_user_id`, `reason` (text),
  `description` (text, nullable), `status` (enum: `pending` / `resolved` /
  `dismissed`), `admin_response` (text, nullable), `created_at`.
- RLS: a user can insert their own report and read only their own reports.
- A trigger/notification (`notify_on_report_status_change`) so the user gets
  a `report_update` notification when an admin resolves/dismisses their report
  (the `notifications` table + this notification type already exist — see 2.3).

### 2.2 Blocking

**Why:** Blocking exists in a limited, incomplete form today — it only
flips `matches.status = 'blocked'` when you long-press an existing match.
Blocking from a chat screen or a Discover card does nothing, and a blocked
user is **not** filtered out of Discover/feeds at all.

**Need:**
- A dedicated `blocked_users` table (`blocker_id`, `blocked_id`, `created_at`)
  — decoupled from `matches`, since you should be able to block someone you
  haven't matched with yet (e.g. from a Discover card).
- Discovery feed / candidate queries must exclude anyone in either direction
  of a block relationship (blocker sees neither blocked user, and vice versa).
- Chat/message sending should be blocked in both directions once blocked.

### 2.3 Notification delivery & push

**Why:** In-app notifications currently only display rows that already exist
in the `notifications` table — but **nothing ever inserts a row**. A user
gets a notification only if you manually insert one; the app cannot trigger
its own notifications (by design — RLS blocks client INSERT on
`notifications`, which is correct and should stay that way).

**Need — trigger functions that insert a `notifications` row on each event:**
- `notify_on_like` → `new_like`
- (match creation already triggers via `create_match_on_mutual_like` — just
  confirm it also inserts a `new_match` notification row)
- `notify_on_message` → `new_message`
- `notify_on_missed_call` → `call_missed`
- `notify_on_report_status_change` → `report_update` (see 2.1)
- Subscription lifecycle → `subscription_expiring` / `subscription_active`

**Need — push delivery (client side is now ready and waiting for this):**
- `fcm_tokens` table: `user_id`, `token`, `platform` (android/ios/web),
  `updated_at`. RLS: user can only read/write their own rows.
  *(The Flutter client already has a Firebase Cloud Messaging project set
  up and a `FcmService.deviceToken` value ready to be persisted here the
  moment this table exists — see developer.log 2026-07-11.)*
- A dispatcher (Edge Function, triggered on `notifications` insert, or
  called directly by the trigger functions above) that calls the Firebase
  Cloud Messaging v1 API using a Firebase service-account key (generate
  this from the Firebase console → Project Settings → Service accounts;
  **never share this key with the Flutter client** — it's server-only).
- Optional but recommended: realtime on `public:notifications` so the
  in-app list updates live instead of requiring pull-to-refresh.

### 2.4 Account deletion

**Why:** The Delete Account screen is fully built in the UI, collects a
password and a typed "DELETE" confirmation — but currently does nothing
except sign the user out. No data is actually deleted, and the password is
never checked.

**Need:**
- A `delete-account` Edge Function that: (1) verifies the submitted password
  server-side, (2) cascades a delete across all of the user's data —
  `messages`, `message_reads`, `message_reactions`, `conversations` (where
  they're the sole/last participant), `call_logs`, `matches`, `likes`,
  `passes`, `profile_views`, `profile_photos` (+ their actual files in the
  `avatars`/chat storage buckets), `notifications`,
  `notification_preferences`, `fcm_tokens`, `active_sessions`,
  `user_presence`, `profiles`, and finally the `auth.users` row itself.
- Recommend a 30-day soft-delete grace period (flag the account instead of
  immediately purging, via e.g. `profiles.pending_delete_at`) with a daily
  cron to hard-delete once the grace period passes — gives you a recovery
  window if a deletion is triggered by mistake or fraud.

### 2.5 Device sessions / single-device enforcement

**Why:** The Devices screen (sign out other sessions) is fully built but is
entirely local/fake — "revoking" a device just removes it from an in-memory
list, and nothing prevents a free-tier user from being logged in on multiple
devices simultaneously (a stated business rule).

**The `active_sessions` and `user_presence` tables already exist** (migration
001) with RLS in place — they're just unused by the client so far.

**Need:**
- Confirm/finalize the exact columns on `active_sessions` the client should
  populate on login (device label, OS, last-active timestamp) — client's
  `DeviceSession` model expects: `id`, `label`, `os`, `last_active`,
  `is_current`.
- A trigger or Edge Function that enforces single-device-per-free-tier-user:
  when a new session is created for a free user, revoke/invalidate the
  previous one.
- A presence heartbeat mechanism (or confirm the client should just PATCH
  `user_presence` periodically) so "last active" / online status is real.

---

## Priority 3 — Important but not blocking launch

### 3.1 Real discovery feed

The Discover tab currently shows a handful of hardcoded mock profiles — there
is no real candidate-matching query yet. Need a `discover_feed` RPC that:
excludes the current user, already-swiped users, and blocked users (see
2.2); applies the user's gender/age/distance preferences; ranks by
distance using `profiles.location_lat/lng` (PostGIS or equivalent — distance
is currently always null on the client because there's no real geo query);
paginates; and respects the plan-based daily like cap (see 1.3).

### 3.2 Country counts (Explore tab)

Explore's country flag chips currently show no real counts. Need a
`get_country_counts` RPC (profile count per country, likely respecting
basic visibility/active-account filters).

### 3.3 Conversation metadata

`conversations.last_message_id` / `last_message_at` are not populated
server-side, so the client currently queries `messages` directly to build
previews — works, but is less efficient. A trigger that keeps these two
columns in sync on new message insert would let the client simplify this.
No `archived_conversations` / `muted_conversations` tables exist — mute/
archive in the Messages screen is local-only today; low priority unless you
want that to persist across devices.

### 3.4 Calling (voice/video)

`call_logs` exists and is used for logging call metadata only (columns in
use: `id`, `conversation_id`, `caller_id`, `receiver_id`, `call_type`,
`call_status`, `started_at`, `ended_at`, `ended_by`, `duration_seconds`).
**There is no actual calling infrastructure** — no WebRTC signaling channel,
no TURN/STUN servers, no Agora/Twilio integration. Tapping a call button in
the app currently just shows a "coming soon" toast. This is a bigger
infra decision (self-hosted WebRTC signaling vs. a third-party SDK like
Agora/Twilio) — flag for a scoping conversation before committing to an
approach.

### 3.5 Identity/photo verification

No `verify-profile-photo` or `verify-identity` Edge Functions exist. There's
no ID/selfie upload flow on the client yet either — this is a paired
frontend+backend feature to scope together when you're ready to prioritize it.

### 3.6 Extended profile fields

The live `profiles` table only has the fields from the original auth/profile
migration (name, birthday, city/country, photo_url, etc.). Fields like
`bio`, `interests`, occupation, education, religion, languages, height,
smoking/drinking/children/pets preferences are all **local-only on the
client today** — they're collected in onboarding but never actually saved to
the backend. If/when these matter for real matching, they need columns
added to `profiles` (or a linked table) and the client will wire the
round-trip.

### 3.7 Auth hardening

- Google Sign-In: the button exists on the client but has no working OAuth
  redirect configured — needs the Google OAuth client + redirect URL set up
  in the Supabase Auth dashboard.
- "Confirm email" is currently **disabled** in the Supabase dashboard (this
  was a deliberate temporary fix — see developer.log 2026-07-06 — because
  enabling it breaks the sign-up flow's `profiles` insert, since there's no
  `auth.uid()` until the user confirms). **Before production launch**,
  re-enable "Confirm email" and let us know — the client's sign-up flow will
  need to move the `profiles` insert to happen post-confirmation instead of
  immediately after `signUp()`.
- Currently using unbranded default Supabase auth emails — if branded
  transactional email (custom templates, unsubscribe handling, etc.) is
  wanted, that's a separate email-pipeline build (auth email hook, send
  queue, suppression list) — flag if this matters for launch.

### 3.8 Admin panel backend

Out of scope for now — the admin screen was actually removed from the
Flutter client entirely during the UI-parity pass (to match the old app,
which has no in-app admin UI). If an admin panel is still wanted, it would
likely be a separate internal tool, not part of this Flutter app — worth
clarifying whether that's still in scope at all.

### 3.9 Virtual gifts / coin store

Not started on either side — greenfield feature from a later phase of the
product roadmap, not urgent.

---

## Reference: things already working, no action needed

Auth (email/password), profile CRUD, onboarding, real GPS capture, swipe/
like/pass, mutual-match creation (trigger live), chat with realtime +
reactions + read receipts, all 5 media storage buckets with signed URLs,
in-app notification read/mark-read/delete + preferences (8 toggles),
dark mode. These are solid — no backend changes needed for any of them.

---

## Suggested order of operations for your team

1. Image moderation (**P1**, launch blocker) — independent of everything else.
2. Payments/subscriptions (**P1**) — needs a decision on which provider(s)
   to support first.
3. Quota RPCs (**P1**) — small, self-contained, high business impact
   (currently zero enforcement = zero monetization pressure on free users).
4. Safety reports + blocking (**P2**) — safety/liability risk if launched
   without this.
5. Notification triggers + push dispatcher (**P2**) — client is fully ready
   for this the moment `fcm_tokens` exists.
6. Everything else in P2/P3, roughly in the order listed.

Happy to hop on a call to walk through any of this, or split it into
separate tickets per item if that's easier for your tracking system.
