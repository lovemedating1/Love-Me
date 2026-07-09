# LoveMe — Remaining BACK-END Work

> **Generated 2026-07-08** after a full two-pass scan of the Flutter client
> cross-referenced against the 5 delivered migration docs (`migration_001`…`005,006,007`),
> the full backend API spec (`LoveMe-Backend-API-Documentation.docx` — the target end
> state: 30 tables, 9 RPCs, 29 edge functions, 7 storage buckets, 4 realtime channels,
> 4 cron jobs), and the product roadmap (`app.docx`, 28 phases).
>
> **IMPORTANT — the Flutter team does NOT build this.** Per the project's standing rule,
> the backend is Supabase (Lovable Cloud) and is owned by the backend track. This doc is
> the **hand-off list**: everything the server side still owes before the client can
> finish the features in **FRONTEND_REMAINING.md**. Each item has a **[BE-#]** id that
> the front-end doc references.
>
> **Legend:**
> - ✅ **LIVE** — shipped in a migration and the client already uses it.
> - 🟠 **PARTIAL** — table/policy exists but a trigger/RPC/index that makes it usable
>   is missing.
> - 🔴 **MISSING** — not built server-side at all.
> - ⚠️ **SPEC-DRIFT** — the delivered migrations differ from the original API-doc spec;
>   needs a decision on which is canonical.

---

## 0. What's LIVE today (delivered migrations 001–007)

| Migration | Objects delivered | Client uses it? |
|---|---|---|
| 001 auth/profiles | `profiles`, `user_roles`, `active_sessions`, `fcm_tokens`, `push_tokens`, `user_presence` | `profiles` ✅ · the other 4 tables **not used by client yet** |
| 002 matching | `likes`, `passes`, `matches`, `profile_views` | `likes`/`passes`/`matches` ✅ · `profile_views` **unused** |
| 003 chat | `conversations`, `messages`, `message_reads`, `message_reactions`, `call_logs` | all read/written ✅ (calls logged, not called) |
| 004 notifications | `notifications`, `notification_preferences`, `notification_queue` | first two ✅ · `notification_queue` correctly untouched |
| 005/006/007 photos | `profile_photos` + `sync_primary_profile_photo` trigger + `set_primary_profile_photo` RPC | ✅ |

**Delivered = 13 tables + 1 RPC + 2 triggers.** The full spec envisions **30 tables,
9 RPCs, 29 edge functions, 7 buckets, 4 realtime channels, 4 cron jobs.** The gap below
is what's left.

---

## [BE-1] Sessions, presence & single-device enforcement — 🟠 PARTIAL

Tables `active_sessions` and `user_presence` are **LIVE (migration 001)** with full
CRUD RLS, but **nothing server-side enforces the business rules** and the client
doesn't use them yet.

Still needed server-side:
- 🔴 **Single-device enforcement** (free tier = 1 concurrent session; premium = more).
  A trigger/edge function that, on new `active_sessions` insert, revokes older sessions
  for free users (and signals the old device to sign out). The cap-by-plan logic lives
  server-side; the client can't be trusted to self-limit.
- 🔴 **Presence maintenance** — decide how `user_presence.is_online` gets set to
  `false` when a client disconnects (heartbeat + stale-sweep cron, or realtime presence).
  Without it, "online" status is unreliable.
- ✅ No schema change strictly required — but confirm whether presence should be driven
  by a cron that flips stale `last_seen` rows offline.

Unblocks front-end: §12 (Devices), §17.3 (presence), the `isOnline` field everywhere.

---

## [BE-2] `likes.is_super_like` — ⚠️ SPEC-DRIFT / verify

The full spec's `likes` table has an **`is_super_like boolean`** column and a
`check_for_match` trigger. The migration-002 integration guide's `likes` shape only
showed `id / from_user_id / to_user_id / created_at` — **no super-like column and no
match trigger** (see [BE-9]).

Needed:
- 🔴 Confirm whether the live `likes` table has `is_super_like`. If not, add it so the
  client can distinguish super-likes (Discover has the UI; it currently can't persist
  the distinction).
- Reconcile column names: spec uses `liker_id`/`liked_id`; migration 002 uses
  `from_user_id`/`to_user_id`. **The client is built against `from_/to_`.** Lock one.

Unblocks front-end: §2.1 (super-like).

---

## [BE-3] Notifications delivery, realtime & push — 🔴 MISSING

Tables `notifications` + `notification_preferences` are **LIVE**, but per
`migration_004.md`'s own checklist, the delivery machinery is not:
- 🔴 **Triggers that CREATE notifications** — `notify_on_like`, `check_for_match`
  (→ new_match), `notify_on_message`, `notify_on_missed_call`,
  `notify_on_report_status_change`, subscription events, `profile_verified`. **Right
  now nothing inserts notification rows**, so the client's feed is always empty for a
  real account. This is the single biggest notifications blocker.
- 🔴 **`send_push_on_notification` trigger** → **`push-notifications` edge function**
  → FCM HTTP v1 (uses `fcm_tokens`). None of this exists.
- 🔴 **Realtime** on `public:notifications` (spec §10.3) — not enabled; doc says
  "manual refresh only" for now.
- 🔴 **`get_conversations` RPC** (returns partner, last message, **unread count**,
  presence, mute/archive flags) — the client's chat list rebuilds this by hand and has
  no unread count without it.
- ⚠️ **SPEC-DRIFT**: migration-004 `notifications` uses `actor_user_id` + a `data`
  jsonb + an 11-value enum; the API-doc spec uses `related_user_id` + a 6-value type
  list. **The client is built against the migration-004 shape.** Lock it, and make the
  creating-triggers emit that exact shape (esp. the `data` payload keys the client
  deep-links on: `conversation_id`, `match_id`, `viewer_id`).

Unblocks front-end: §10 (Notifications feed/badge/push), §4.1 (unread counts).

---

## [BE-4] Subscriptions, payments & premium state — 🔴 MISSING

Nothing subscription-related is delivered. The full spec needs all of:
- 🔴 **`subscriptions` table** (plan, price, limits, expiry, is_active, store tokens) +
  RLS (user reads own, service-role manages, `prevent_subscription_tampering` trigger).
- 🔴 **`payment_events`** (idempotent webhook log) + **`wise_payment_requests`** +
  `generate_receipt_number` RPC.
- 🔴 **Payment edge functions**: `paystack-checkout` + `paystack-webhook`,
  `paypal-checkout` + `paypal-webhook`, `checkout-com(+webhook)`,
  `verify-flutterwave-payment`, `verify-purchase` (Google Play), `verify-receipt-upload`
  + `wise-verify-ai` + `wise-admin` (Wise flow).
- 🔴 **`has_active_premium` RPC** + keeping `profiles.is_premium`/`premium_until` in
  sync — the client's entire premium gate (`isPremiumProvider`) is mock until this
  exists.
- 🔴 **`expire-subscriptions` cron** (hourly) to deactivate lapsed plans.
- 🔴 **`has_role` RPC** for the admin gate (table `user_roles` is live but the client
  needs `has_role` / a role read to un-mock `isAdminProvider`).
- 🔴🔴 **PLAN-NAME RECONCILIATION (product decision, blocks everything here):**
  Backend spec = **Premium / VIP / Elite**; roadmap = **Free / Basic+ / Gold /
  Platinum / Premium Elite / VIP Elite**; client placeholder = **Monthly / Quarterly /
  Yearly**. Pick the canonical set + prices + per-plan limits (daily profiles, likes
  visible, etc.) before any of the above is built.

Unblocks front-end: §7 (premium state, stats), §8 (all payments), §15 (admin gate),
§3 (real premium gate on Likes).

---

## [BE-5] Safety: reports, blocking & verification — 🔴 MISSING

- 🔴 **`reports` table** (reporter/reported/reason/description/status workflow) +
  `notify-safety-report` / `resend-safety-notification` edge functions +
  `notify_on_report_status_change` trigger. Client can't file or truly list reports.
- 🔴 **`blocked_users` table** (one-way block; blocked user can't see profile/message)
  + RLS + the filtering so blocked users drop out of discovery/chat. Client block
  buttons are no-ops today.
- 🔴 **`content_flags`** + **`moderate-image` edge function** (mandatory NSFW check
  before ANY image commit — profile photos, chat images, gallery). This is a **launch
  blocker** for the photo-upload feature and a Play Store policy requirement.
- 🔴 **`verify-profile-photo`** (AI face check) + **`verify-identity`** (ID + selfie
  liveness → sets `profiles.is_verified`) edge functions for the verification flow.

Unblocks front-end: §13 (reports/block/verification), §4.2 (chat block/report),
§7 (photo moderation on upload).

---

## [BE-6] Calls — 🟠 PARTIAL / needs a media stack decision

- ✅ `call_logs` table is **LIVE** (migration 003) — start/update/end/history work.
- ⚠️ **SPEC-DRIFT**: the API-doc spec has a `calls` table (`caller_id`/`callee_id`/
  `hidden_by_*`) plus "insert requires an existing match" and a `notify_on_missed_call`
  trigger; migration-003 delivered `call_logs` instead. **The client uses `call_logs`.**
  Confirm `call_logs` is canonical and add the missing bits:
- 🔴 **No signaling / media server** — WebRTC needs a signaling channel (realtime
  broadcast or a dedicated service) + **TURN/STUN** servers, or an Agora/Twilio account.
  This is an infra decision, not just SQL.
- 🔴 **Realtime `public:calls`** (or equivalent on `call_logs`) filtered to the receiver
  for incoming-ring delivery — not enabled.
- 🔴 **`notify_on_missed_call`** (creates a `call_missed` notification) — depends on [BE-3].

Unblocks front-end: §5 (entire calling UX), §4.1 (Calls tab).

---

## [BE-7] Account deletion — 🔴 MISSING

- 🔴 **`delete-account` edge function** — cascade purge of messages/matches/likes/
  subscriptions/profile/avatars → `auth.users`, with the spec's 30-day soft-delete grace
  (`profiles.pending_delete_at`) + `retention-purge` daily cron. Client's delete screen
  is fully mock until this exists (and password re-auth should be verified server-side).

Unblocks front-end: §14 (Delete Account).

---

## [BE-8] Storage buckets & media pipeline — 🔴 MISSING (broad blocker)

**No storage buckets exist in any delivered migration.** The full spec needs 7:
`avatars` (public), `email-assets` (public), `chat-files`, `chat-images`,
`chat-file-thumbs`, `voice-messages`, `wise-proofs` (all private w/ signed URLs).

Needed:
- 🔴 Create the buckets + per-bucket RLS/path policies (`<user_id>/…`, `<match_id>/…`).
- 🔴 Wire `moderate-image` ([BE-5]) to run before any image commit.
- 🔴 `generate-pdf-thumbnail` edge fn for `chat-files` previews.

**This blocks every real image/voice/file feature:** profile photos & gallery (they use
placeholder URLs today), chat media, voice messages, Wise receipts. Highest-leverage
backend item after notifications.

Unblocks front-end: §1.4 & §7 (real photos), §4.2 (chat media/voice), §8 (Wise receipts).

---

## [BE-9] Discovery feed, match trigger & country counts — 🟠 PARTIAL

- ✅ `likes`/`passes`/`matches` tables LIVE.
- 🔴🔴 **The mutual-like → match trigger does NOT exist** (`check_for_match` /
  `create_match_on_mutual_like`). Right now **nothing creates `matches` rows** — the
  app can only show a match if one is inserted out-of-band. This is why Discover has no
  "It's a Match!" feedback and the Likes realtime overlay can never fire. **Top matching
  blocker.**
- 🔴 **No discovery/candidate-feed RPC** — the client shows 5 mock profiles. Needs a
  server-side feed: exclude self/blocked/already-swiped, apply gender/age/distance
  preferences, geo-rank by `location_lat/lng` + `distance_preference_km`, paginate,
  respect daily profile cap by plan.
- 🔴 **`get_country_counts` RPC** + a real by-country profile query for Explore.
- 🔴 **`distanceKm`** — needs server-side geo distance (or PostGIS) so the client can
  show real distances instead of null.

Unblocks front-end: §2.1 (real feed + match feedback), §3 (match creation), §6 (Explore).

---

## [BE-10] Quota RPCs (free-tier caps) — 🔴 MISSING

- ✅ `profile_views` table LIVE (migration 002) but **the client never records views**
  and there's no enforcement.
- 🔴 **`record_profile_view` RPC** — enforce 50 views/month free tier (window reset via
  `profiles.profiles_viewed_count`/`profiles_viewed_reset_at`, which exist).
- 🔴 **`can_send_like` RPC** — enforce 50 likes/24h free tier.
- 🔴 **`can_send_message` RPC** — gate the chat composer (matches-only for free tier).
  Per-plan limits depend on [BE-4]'s plan definitions.

Unblocks front-end: §2.1 (like cap, view recording), §8 (usage bars), §4.2 (message gate).

---

## [BE-11] Conversation state: last-message, archive, mute — 🟠 PARTIAL

- ✅ `conversations` table LIVE, but:
- 🔴🔴 **No INSERT policy + no auto-create trigger** on `conversations` — a new match
  gets **no conversation**, so chat is unusable end-to-end for real matches until
  backend adds a trigger that creates a `conversations` row when a `matches` row is
  created (or a service-role/RPC path). **Top chat blocker** (documented in
  migration_003.md §1/§9).
- 🔴 **`conversations.last_message_id` / `last_message_at` are never populated** — needs
  a trigger on `messages` insert to update them (client currently queries `messages`
  directly to build previews).
- 🔴 **`archived_conversations`** + **`muted_conversations`** tables (spec) — not
  delivered; client's delete/mute are local-only.

Unblocks front-end: §4.1 (delete/mute/preview), §4.2 (usable chat for new matches).

---

## [BE-12] Virtual gifts & coin store — 🔴 MISSING (roadmap Phases 17–18)

- 🔴 No tables for coins wallet, coin-pack purchases, gift catalog, gift transactions,
  or gift-balance. No Google-Play-billing verification path for coins. Entire economy is
  greenfield server-side.

Unblocks front-end: §9 (gifts/coins).

---

## [BE-13] Extended profile columns — 🔴 MISSING

The client's `Profile` model carries `bio`, `interests`, `gallery`, plus the roadmap's
onboarding wants **occupation, education, religion, languages, height, lifestyle,
smoking, drinking, children, pets** — **none of these have columns** in the live
`profiles` table (migration 001). The client keeps `bio`/`interests`/`gallery` as
**local-only** fields that never round-trip.

Needed:
- 🔴 Add the columns (or a `profile_details` side table) so the extended onboarding +
  Edit Profile + profile-detail view can persist. Confirm which roadmap fields are
  actually in scope for v1.
- Note: `gallery` is effectively superseded by the live `profile_photos` table — decide
  whether `bio`/`interests` go on `profiles` or elsewhere.

Unblocks front-end: §1.4 (extended onboarding), §7 (edit profile, bio/interests).

---

## [BE-14] Auth hardening: OAuth redirect, email confirmation, branded emails — 🟠 PARTIAL

- 🟠 **Google OAuth redirect** not configured in the Supabase dashboard (redirect URL +
  Android/iOS deep-link scheme) — the client button can't complete a real sign-in.
- 🟠 **"Confirm email" is currently OFF** in the dashboard (disabled to unblock the
  sign-up→profiles-insert RLS path, see developer.log 2026-07-06). For production, decide:
  re-enable confirmation (then the client's `profiles`/`notification_preferences` insert
  must move to post-confirmation) **or** keep it off. Either way the **email deep-link**
  (verify + recovery) must be wired [FE §1.2/§1.3].
- 🔴 **Branded transactional email pipeline** (spec): `auth-email-hook`,
  `request-password-reset`, `send-transactional-email`, `process-email-queue` cron,
  `email_send_log`/`email_send_state`/`suppressed_emails`/`email_unsubscribe_tokens`
  tables, `handle-email-unsubscribe`/`handle-email-suppression`. The client currently
  uses Supabase's built-in (unbranded) auth emails.

Unblocks front-end: §1.1 (Google), §1.2/§1.3 (email deep-links).

---

## [BE-15] Admin panel backend — 🔴 MISSING (roadmap Phase 22)

If any admin lives in the mobile app (or a separate web console), the server side needs:
users/subscriptions/revenue queries, verification queue, reports triage, Wise approval
(`wise-admin`), feature flags, push composer, banned-users, coin/gift purchase views,
`preview-transactional-email`. `user_roles` + `has_role` ([BE-4]) is the prerequisite
gate. Largely out of scope for the mobile client — flag for a product decision.

---

## 16. Priority hand-off order (backend)

**Tier 1 — unblocks the most already-built client code, smallest server effort:**
1. **[BE-11]** `conversations` auto-create trigger on match + last-message trigger →
   makes chat actually usable end-to-end.
2. **[BE-9]** mutual-like → `matches` trigger → makes matching real (unblocks Discover
   feedback + Likes overlay).
3. **[BE-3]** notification-creating triggers (like/match/message) + lock the enum/`data`
   shape → makes the notifications feed non-empty.

**Tier 2 — unblocks whole feature areas:**
4. **[BE-8]** storage buckets + **[BE-5]** `moderate-image` → real photos/media
   (also a Play Store compliance gate).
5. **[BE-3]** FCM push (`push-notifications` fn + `send_push_on_notification` trigger).
6. **[BE-4]** subscriptions + one payment provider + `has_active_premium`/`has_role`
   (after the **plan-name decision**).
7. **[BE-10]** quota RPCs (`can_send_like`, `record_profile_view`, `can_send_message`).

**Tier 3 — larger / independent:**
8. **[BE-9]** real discovery feed + `get_country_counts`; **[BE-1]** single-device +
   presence.
9. **[BE-5]** reports/blocking/verification; **[BE-7]** delete-account cascade.
10. **[BE-6]** calls media stack; **[BE-13]** extended profile columns; **[BE-14]**
    branded email + OAuth config; **[BE-12]** gifts/coins; **[BE-15]** admin.

**Cross-cutting decisions to lock first (they gate multiple items):**
- **Plan names/prices/limits** (blocks [BE-4], [BE-10], discovery caps).
- **`likes` column names** (`from_/to_` vs `liker_/liked_`) + `is_super_like` ([BE-2]).
- **`call_logs` vs `calls`**, **`conversations`-based chat vs flat `messages`** — confirm
  the delivered migrations (003) are canonical over the older API-doc spec where they drift.
- **Media/calls infra** (Supabase Storage ✓; TURN/Agora/Twilio for calls — TBD).
