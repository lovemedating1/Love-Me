# LoveMe — Remaining FRONT-END Work

> **Generated 2026-07-08** after a full two-pass scan of every `.dart` file in `lib/`
> (68 files), cross-referenced against the 5 migration docs, the full backend API
> spec (`LoveMe-Backend-API-Documentation.docx`), and the product roadmap (`app.docx`).
>
> **Scope of this doc:** everything the FLUTTER CLIENT still needs — missing screens,
> mock UI that must be wired to already-live backend, half-built flows, missing
> device capabilities (image picker, GPS, push, calls), and polish. Backend-side gaps
> (tables/triggers/RPCs/edge functions that don't exist server-side yet) are in the
> companion doc **BACKEND_REMAINING.md** — where a front-end item is blocked by a
> backend gap, it's cross-referenced as **[BE-#]**.
>
> **How to read the status tags:**
> - ✅ **DONE** — built and wired to live Supabase; nothing outstanding.
> - 🟡 **MOCK** — screen exists and looks right, but runs on in-memory `MockData` or
>   local `setState` with **no persistence**; needs wiring.
> - 🟠 **PARTIAL** — partly wired to live backend, but has missing sub-features.
> - 🔴 **MISSING** — no screen/flow exists at all yet.
> - 🔒 **BLOCKED** — can't be finished until a backend gap closes (see [BE-#]).

---

## 0. Current wiring snapshot (what the app actually talks to today)

**Live Supabase tables the client reads/writes right now:**
`profiles`, `profile_photos`, `likes`, `passes`, `matches`, `conversations`,
`messages`, `message_reads`, `message_reactions`, `call_logs`, `notifications`,
`notification_preferences` + the `set_primary_profile_photo` RPC + Supabase Auth
(email/password, Google OAuth call, password reset) + realtime channels on
`matches` and `messages`.

**Still 100% mock / local-only in the client:** Subscription/payments, Explore
(country grid + profiles), Discover candidate feed, Profile stats (views/likes/
matches counts), Safety Reports, Devices, Delete Account, Admin Diagnostics,
Settings (every toggle), Legal copy, the entire Calls tab and call UX.

**Repository capabilities that are CODED but NEVER CALLED from any screen**
(updated 2026-07-09 — most were wired in the Group-A pass):
- ✅ now wired: `MatchRepository.unmatch()`/`.block()`, `CallRepository.getCallHistory()`,
  `NotificationRepository.getPreferences()`/`.updatePreferences()`,
  `ChatRepository.markAsRead()`/`reactionsFor()`/`removeReaction()`.
- 🔴 still unused: `CallRepository.startCall()`/`updateCallStatus()`/`endCall()`
  (no calling UI), `ChatRepository.editMessage()`/`deleteMessage()` (no UI),
  `SwipeRepository.unlikeProfile()` (no rewind UI), profile-view recording.

---

## 1. AUTH & ONBOARDING

### 1.1 Auth screen (`features/auth/auth_screen.dart`) — 🟠 PARTIAL
- ✅ Email/password sign-in & sign-up wired to `supabase.auth`.
- ✅ 18+ DOB gate, gender, country, terms checkbox collected at sign-up.
- 🟠 **Google OAuth** calls `signInWithOAuth(OAuthProvider.google)` but the native
  redirect/deep-link is **not configured** — no `google_sign_in` / `flutter_appauth`,
  no Android `intent-filter`, no Supabase redirect URL. Button will not complete a
  real sign-in on device. **[BE-14]** for the dashboard redirect config.
- 🟠 **"Remember me"** checkbox is decorative — `supabase_flutter` already persists
  the session, but the checkbox toggles nothing. Either wire it to opt out of
  persistence or remove it.
- 🔴 Session is persisted by the SDK's default `SharedPreferences` storage. The
  full spec calls for **`flutter_secure_storage`** for the session/token. Not done.

### 1.2 Email verification (`features/auth/email_verified_screen.dart`) — 🟡 MOCK
- Static "Email verified!" screen that just routes to profile-setup. **Nothing
  reaches it** — there is no deep-link handler for the Supabase confirmation link,
  and "Confirm email" is currently **disabled** in the dashboard (see developer.log
  2026-07-06 bugfix). If email confirmation is re-enabled for production, this needs
  a real deep-link (`loveme://` / app-links) → verify → route flow. **[BE-14]**

### 1.3 Password reset — 🟠 PARTIAL
- ✅ `reset_password_dialog.dart` calls real `supabase.auth.resetPasswordForEmail()`.
- ✅ `reset_password_screen.dart` calls real `supabase.auth.updateUser(password:)`.
- 🔴 The recovery **deep-link** that should open `reset_password_screen` from the
  emailed link is not wired (no deep-link handler in the app). Today the screen is
  only reachable if something navigates to `/reset-password` manually.
- Note: reset currently uses Supabase's built-in email, **not** the branded
  `request-password-reset` edge function from the spec. Decide which to keep.

### 1.4 Onboarding wizard (`features/onboarding/profile_setup_screen.dart`) — 🟠 PARTIAL
- ✅ Steps 1/3/4 (basics, bio+interests+goal, country+city) PATCH the real
  `profiles` row and flip `profile_complete`.
- ✅ Step 2 avatar inserts a **real** `profile_photos` row (primary) — but via a
  **placeholder picsum URL**, not a real image. 🔒 Needs `image_picker` + storage
  upload — **[BE-8]** (no storage bucket exists).
- 🟠 Step 2's **extra gallery slots** are still mock `bool` toggles — only the
  single avatar is real. Multi-photo add during onboarding not wired.
- 🟠 **"Use current location"** is a fake 900ms delay that hardcodes Nairobi. No
  real GPS — needs `geolocator` + `permission_handler`, then PATCH
  `location_lat`/`location_lng`/`location_accuracy_m` (columns already exist).
- 🔴 The roadmap's onboarding collects far more than we do: **Occupation, Education,
  Religion, Languages, Height, Lifestyle, Smoking, Drinking, Children, Pets**. None
  of these have columns yet — **[BE-13]** — nor UI. Decide scope.

---

## 2. DISCOVER (`features/discover/`)

### 2.1 Swipe deck — 🟠 PARTIAL
- ✅ Like / Pass / Super-like write to real `likes`/`passes`, handle duplicate-swipe.
- ✅ Already-swiped profiles excluded from the deck.
- 🟡 **The candidate feed itself is still `MockData.profiles`** (5 hardcoded users).
  Real discovery needs a backend feed (geo + preference ranking, exclude blocked/
  swiped/self) — **[BE-9]**. Until then Discover only ever shows the 5 mock cards.
- 🟠 **Super-like is identical to a like** — it just calls `likeProfile()`. The
  `likes` table has an `is_super_like` column (per full spec) the client never sets.
  **[BE-2]** (the live `likes` migration may not have that column — verify).
- 🟠 **"Message" action** on a card routes to chat, but for a non-match the chat
  screen shows "not available yet". For free users, messaging should be gated to
  matches only — no gate exists here.
- 🔴 No **card swipe gestures/animation** (drag-to-swipe, spring-back) — actions are
  button-only. Roadmap Phase 6 wants a swipe interface.
- 🔴 No **Report / Block** from a Discover card (roadmap Phase 6 lists both).
- 🔴 **No profile-detail view** — you can't tap a card to see full photos/bio/
  interests/lifestyle; only the summary card + action row exists.
- 🔴 **Daily like cap (50/day free)** is not enforced client-side and `can_send_like`
  RPC isn't called — **[BE-10]**.
- 🔴 **Profile-view recording** — opening/viewing a profile should call
  `record_profile_view` for the monthly quota; not wired (RPC missing **[BE-10]**,
  and `profile_views` table write not called).

### 2.2 Filters sheet (`discover_filters_sheet.dart`) — 🟡 MOCK
- ✅ UI is complete (age range, distance, gender, online-only, verified-only).
- 🟡 Filters apply **client-side to the mock list only**. Once the real feed exists,
  filters should be sent to the backend query (server-side filtering + pagination),
  not applied in-memory. Also missing roadmap Phase 13 search facets: religion,
  education, occupation, "recently active".

---

## 3. LIKES (`features/likes/likes_screen.dart`) — 🟠 PARTIAL
- ✅ "Liked You" reads real `likes` (joined to profiles); "Matches" reads real
  `matches` (joined to profiles).
- ✅ Realtime `matches` subscription → "It's a Match!" overlay (future-proofed).
- ✅ Premium blur gate on "Liked You" driven by `isPremiumProvider`.
- 🟡 **`isPremiumProvider` is a mock `StateProvider<bool>`** flipped only by the
  Profile screen's demo toggle. Real premium state must come from
  `profiles.is_premium` / `has_active_premium` RPC — **[BE-4]**.
- 🔴 No **filter / search** within Likes (roadmap Phase 7 lists both).
- ✅ **DONE (2026-07-09):** long-press a match → **Unmatch / Block** action sheet
  with a confirmation dialog, wired to `MatchRepository.unmatch()`/`.block()`.
- 🔴 No **unlike** action (removing a like you sent) from this screen.

---

## 4. MESSAGES + CHAT (`features/messages/`, `features/chat/`)

### 4.1 Messages list (`messages_screen.dart`) — 🟠 PARTIAL
- ✅ Chats tab reads real conversations (via matches → conversations → profiles) with
  a live last-message preview.
- 🟡 **Swipe-to-delete & long-press "Delete conversation"** only add to a local
  `_deleted` set — **no persistence**. Needs `archived_conversations` (spec) or a
  real delete. **[BE-11]**
- 🔴 **Unread badges removed** — the live schema has no unread count; needs a count
  derived from `message_reads` or an RPC (`get_conversations` returns unread per
  spec). **[BE-3]**
- 🔴 **Mute** removed — needs `muted_conversations` table. **[BE-11]**
- 🔴 **Search** filters the loaded list only (fine), but there's no server search.
- ✅ **DONE (2026-07-09): Calls tab now renders real `call_logs`** — direction
  (in/out/missed), audio-vs-video, duration or status, partner avatar/name,
  relative time, pull-to-refresh, loading/empty/error states.
- 🔴 Still **read-only history**: no tap-to-call-back, because placing a call
  needs WebRTC (see §5). 🔒 **[BE-6]**

### 4.2 Chat screen (`chat_screen.dart`) — 🟠 PARTIAL
- ✅ Loads real message history, sends real text messages, realtime insert
  subscription with de-dupe, "not available yet" empty state for no-conversation.
- ✅ Read-receipt **display** (single/double check on own messages by `status`).
- ✅ **DONE (2026-07-09):** incoming messages are now marked read
  (`markManyAsRead()` on load + on each realtime message), so the sender's
  double-check actually updates.
- ✅ **DONE (2026-07-09):** reactions are **fetched and displayed** as grouped
  chips under each bubble (`❤️ 3`), your own chip is outlined, and tapping it
  removes your reaction.
- ✅ **DONE (2026-07-08→09):** attach (image/video), voice messages, and media
  bubbles (image / video thumb+play / voice row). 🔒 needs storage buckets.
- 🔴 **Emoji picker** button is a no-op (`onPressed: () {}`).
- 🔴 **GIF / sticker / file** sending — no picker (enum supported server-side).
- 🔴 **Edit / Delete message** — `ChatRepository.editMessage()`/`deleteMessage()`
  exist but have no UI entry point (roadmap Phase 9 wants both).
- 🔴 **Reply / Forward / Pin / Message search** (roadmap Phase 9) — none built.
  (`reply_to_message_id` is supported by the model/insert but no UI.)
- 🔴 **Typing indicator** & **"delivered" vs "seen"** status — not built (needs
  realtime presence/broadcast). Only sent/read exist.
- 🔴 **Block / Report** in the chat overflow menu are **no-ops** (`Navigator.pop`
  only). Needs `blocked_users` + `reports` wiring. **[BE-11][BE-5]**
- 🔴 **Voice/Video call buttons** show a "coming soon" toast. No calling UX at all —
  see §5.

---

## 5. AUDIO / VIDEO CALLS — 🔴 MISSING (roadmap Phases 10 & 11)
- The **entire calling experience does not exist.** `CallRepository` can log a call
  to `call_logs`, but there is:
  - 🔴 No **WebRTC / Agora / Twilio** integration (no signaling, no media).
  - 🔴 No **incoming-call screen** / ringing UI (needs realtime `call_logs` insert
    subscription filtered to receiver).
  - 🔴 No **in-call screen** (mute, speaker, camera flip, end, duration timer,
    video render, beauty filter, low-data mode per roadmap).
  - 🔴 No **CallKit / ConnectionService** for native call notifications.
  - 🔴 Call buttons in chat are toasts.
- Needs: a real-time media stack decision **[BE-6]**, `flutter_webrtc` (+ TURN),
  `permission_handler` (mic/camera), and a full call-flow feature module.

---

## 6. EXPLORE (`features/explore/explore_screen.dart`) — 🟡 MOCK
- ✅ Country flag chips + 2-col grid UI is complete.
- 🟡 **Countries list is hardcoded `MockData.countries`** (8 countries, fake counts).
  Needs `get_country_counts` RPC — **[BE-9]**.
- 🟡 **Profiles-by-country is `MockData.profiles` filtered locally.** Needs a real
  by-country query — **[BE-9]**.
- 🟠 Tapping a profile routes to `chatTo(userId)` → chat (which will say "not
  available"). Should open a **profile detail**, not chat. (No detail screen exists.)
- 🔴 Roadmap Phase 12 extras: cities, regions, nearby, worldwide, country rankings,
  trending countries, search-countries — none built.

---

## 7. PROFILE (`features/profile/profile_screen.dart`) — 🟠 PARTIAL
- ✅ Reads own live profile; banner, name/age, city/country.
- ✅ **Gallery is live** — reads `profile_photos`, tap-to-set-primary (RPC),
  long-press delete, "+" add (placeholder URL, capped at 4).
- ✅ **DONE (2026-07-09): Likes + Matches stats are real counts.**
- 🔴 **Views stat shows "–"** and cannot be computed: `profile_views` RLS only
  exposes views *you made*, not views *of you*. "Who viewed me" needs a premium
  RPC that doesn't exist. **[BE-10]**
- 🟡 **"Premium (demo toggle)"** flips the mock `isPremiumProvider`. Must be removed
  for production and replaced by real `profiles.is_premium` — **[BE-4]**.
- ✅ **DONE (2026-07-09): Edit Profile persists `name`** (real PATCH, validation,
  saving state, error text). **Bio field was removed** — there is no `bio`
  column, so it silently discarded input; restore when **[BE-13]** ships it.
- 🔴 Still can't edit gender / goal / interests / city / distance-preference
  from this sheet.
- 🟠 **Avatar camera badge** on the banner is decorative — tapping it does nothing
  (real photo change happens only via the gallery grid).
- 🔴 No **"remaining subscription days" / manage-subscription** summary on profile
  (roadmap Phase 5) beyond the row link.
- 🔴 No **profile-completeness meter**, no **incognito toggle**, no **boost** entry
  (roadmap premium features).
- 🔴 `bio` / `interests` are **local-only** on the `Profile` model (no columns) —
  they don't round-trip through the backend. **[BE-13]**

---

## 8. SUBSCRIPTION & PAYMENTS (`features/subscription/subscription_screen.dart`) — 🟡 MOCK
- ✅ UI complete: perks hero, plan cards, pay-method buttons, usage bars.
- 🟡 **Entirely mock.** `_checkout()` waits 900ms and flips `isPremiumProvider`.
  No real payment happens.
- 🔴 **Plan names unresolved** (the long-standing open decision): screen uses
  placeholder **Monthly/Quarterly/Yearly**; backend uses **Premium/VIP/Elite**;
  roadmap uses **Free/Basic+/Gold/Platinum/Premium Elite/VIP Elite**. **Must be
  reconciled before wiring.** **[BE-4]**
- 🔴 **Payment integrations — none built:**
  - Paystack (M-PESA/card) → `paystack-checkout` edge fn + WebView **[BE-4]**
  - PayPal → `paypal-checkout` + WebView **[BE-4]**
  - Wise (bank transfer) → receipt upload screen + `verify-receipt-upload` **[BE-4]**
  - Google Play Billing → `in_app_purchase` + `verify-purchase` **[BE-4]**
  - Needs `webview_flutter`, `in_app_purchase`, deep-link return handling.
- 🔴 **Restore purchases / upgrade / downgrade / cancel / renew / receipts /
  invoices** (roadmap Phase 14) — none built.
- 🔴 **Usage bars are hardcoded** (34/50 likes, 41/50 views) — need real
  quota state **[BE-10]**.
- 🔴 Read own `subscriptions` row for real plan/expiry — not wired **[BE-4]**.

---

## 9. VIRTUAL GIFTS & COIN STORE — 🔴 MISSING (roadmap Phases 17 & 18)
- Entire feature absent: coins wallet, coin packs (100/300/1000/5000), gift catalog
  (flowers/rose/chocolate/ring/diamond/etc.), send-gift-in-chat, gift balance,
  transaction history, Google Play billing for coins. No tables exist either **[BE-12]**.

---

## 10. NOTIFICATIONS (`features/notifications/notifications_screen.dart`) — 🟠 PARTIAL
- ✅ Reads real `notifications`, mark-read, swipe-delete, pull-to-refresh, 11-type
  icon mapping, deep-links by type.
- 🟠 **Deep-links are coarse** — `newMatch`/`newMessage`/`callIncoming`/`callMissed`
  all route to the Messages **list** because their `data` payload carries a
  `conversation_id` (not a partner user id) and the chat route is keyed by partner
  id. Add a `conversation_id → partner` resolve so these open the exact thread.
- 🔴 **No unread badge** on the bell/bottom-nav — the header bell never shows a count.
- 🔴 **No realtime** — the spec's future `public:notifications` channel isn't
  subscribed (doc says manual refresh only for now) **[BE-3]**.
- 🔴 **Push notifications entirely absent** — no `firebase_core`/`firebase_messaging`,
  no FCM token registration into `fcm_tokens`, no foreground/background handlers, no
  notification channels. **[BE-3]**

---

## 11. SETTINGS (`features/settings/settings_screen.dart`) — 🟡 MOCK (almost entirely)
Every control is local `setState` with **zero persistence** except Dark Mode:
- ✅ **Dark Mode** — real (`themeModeProvider`, persisted).
- 🟡 **Discovery** (age range, max distance, show-me) — local only. Should PATCH
  `profiles.distance_preference_km` / preferences.
- ✅ **DONE (2026-07-09): Notifications section is REAL** — all 8
  `notification_preferences` columns (push, email + likes/matches/messages/
  calls/profile-views/marketing). Each flip PATCHes immediately and refetches.
  **Sound/Vibration were removed** (no backing column anywhere).
- 🟡 **Privacy** (hide distance / show online status / screenshot guard) — local only.
  "Show online status" should drive `user_presence`; "screenshot guard" needs a real
  `FLAG_SECURE`/`secure_application` implementation; "hide distance" needs a column.
- 🟡 **Ringtone** picker — local only; `profiles.ringtone` column exists but isn't
  written. (Also no actual ringtone assets/playback.)
- 🔴 **Remember Email** (roadmap Phase 20) — not present.
- 🔴 **Worldwide Discovery** toggle (roadmap) — not present.

---

## 12. DEVICES / SESSIONS (`features/devices/devices_screen.dart`) — 🟡 MOCK
- ✅ UI complete (device cards, current badge, per-device revoke, sign-out-everywhere).
- 🟡 **Entirely mock** (`MockData.devices`, local `_revoked` set). Needs the live
  `active_sessions` table: register a session on login (generate `session_token`,
  device label, user agent), heartbeat `last_seen_at`, list real sessions, revoke by
  deleting rows. 🔒 also the **single-device enforcement** business rule (free tier =
  1 device) isn't implemented anywhere. **[BE-1]**

---

## 13. SAFETY / REPORTS / BLOCK (`features/safety/safety_reports_screen.dart`) — 🟡 MOCK
- ✅ Report-history list UI + status badges + detail sheet.
- 🔒 **BLOCKED — the `reports` table DOES NOT EXIST.** Verified 2026-07-09:
  `GET /rest/v1/reports` → **404**. (An earlier version of this doc wrongly
  called it live, based on the full backend spec rather than the delivered
  migrations.) The screen still reads `MockData.reports` and **cannot** be
  wired until **[BE-5]** ships the table.
- 🔴 **No "submit a report" flow at all** — can't file one anywhere. **[BE-5]**
- 🟠 **Block** — a user can now be blocked from the **Matches tab** (long-press →
  Block, sets `matches.status='blocked'`). Still missing: block from a Discover
  card / chat overflow menu (those remain no-ops), a `blocked_users` list, and
  any unblock/"Blocked users" management screen. **[BE-5]**
- 🔴 **Identity/photo verification** (roadmap Phase 16/21) — no upload-ID/selfie flow,
  no `verify-identity`/`verify-profile-photo` edge calls. **[BE-5]**

---

## 14. DELETE ACCOUNT (`features/delete_account/delete_account_screen.dart`) — 🟡 MOCK
- ✅ UI complete (warning, reason, password + type-"DELETE" gate).
- 🟡 **`_delete()` just waits 900ms and signs out** — **no real deletion.** Needs the
  `delete-account` edge function call (cascade purge). Password is collected but never
  verified. **[BE-7]**

---

## 15. ADMIN DIAGNOSTICS (`features/admin/admin_diagnostics_screen.dart`) — 🟡 MOCK
- ✅ Role-gated tabbed UI (Payments/GPS/Push/Emails) with a 403 view.
- 🟡 **`isAdminProvider` is a mock toggle** ("Preview as admin (demo)"). Real gate
  must read `user_roles` / call `has_role` RPC. **[BE-4]**
- 🟡 **All log entries are hardcoded tuples.** The full admin panel (roadmap Phase 22:
  users, subscriptions, revenue graphs, verification queue, reports triage, Wise
  approvals, feature flags, push composer, banned users, coin/gift purchases) is
  **not built** — this is a large separate surface, likely a web console rather than
  in-app. Decide whether the mobile app carries any admin at all.

---

## 16. LEGAL (`features/legal/legal_screen.dart`) — 🟠 PARTIAL
- ✅ Shared prose scaffold for Privacy / Terms / Refund / Child Safety renders fine.
- 🟠 **All copy is `_lorem` placeholder.** Needs final lawyer-reviewed text (Child
  Safety / CSAE policy is a Play Store compliance requirement — must be real before
  launch). Consider hosting canonical copy remotely so it updates without a release.

---

## 17. CROSS-CUTTING / INFRASTRUCTURE

### 17.1 Device capabilities & packages not yet added
The following are required by unbuilt features and are **absent from `pubspec.yaml`**:
- `image_picker` (+ maybe `image_cropper`) — profile photos, chat images.
- `geolocator` + `permission_handler` — real GPS onboarding + distance.
- `firebase_core` + `firebase_messaging` — push (also `google-services.json`, iOS
  APNs later).
- `flutter_secure_storage` — secure session/token storage (spec requirement).
- `webview_flutter` — Paystack/PayPal checkout.
- `in_app_purchase` — Google Play Billing (subscriptions + coins).
- `google_sign_in` / `flutter_appauth` — native Google OAuth callback.
- `flutter_webrtc` (+ TURN) or Agora/Twilio SDK — calls.
- `record` / `flutter_sound` + `audioplayers` — voice messages + ringtones.
- Screenshot-guard plugin (e.g. `secure_application` / `no_screenshot`) — privacy.

### 17.2 Real-vs-mock data model gaps (`Profile`)
- `bio`, `gallery`, `interests`, `isPremium`, `isOnline` are **local-only** fields on
  `Profile` (no backing columns) — they never round-trip. Wire once columns exist
  **[BE-13]**. `distanceKm` is never populated (needs geo math from lat/lng).

### 17.3 State & session robustness
- **No global error/toast/retry convention** beyond per-screen `SnackBar`s. Consider a
  central failure→message mapper (the Rebuild doc §15 `Failure` hierarchy was never
  built).
- **No offline handling / connectivity awareness** (`connectivity_plus`).
- **No token-refresh / session-expiry UX** — if a refresh fails the app has no
  explicit "signed out, please log in again" path beyond the guard.
- **Presence**: the app never writes `user_presence` (online/last-seen) and never
  reads others' real presence — `isOnline` is always mock. **[BE-1]**

### 17.4 Testing
- Only **2 unit tests** exist (`AuthState` shape). There are **no** widget tests for
  the real screens (they hit live Supabase and can't run headlessly), **no**
  repository tests (would need a mock Supabase client / fake), **no** integration
  tests. Add a test seam (inject a fake `SupabaseClient` or repository fakes) so
  screens/repos are testable without a live backend.

### 17.5 Dead / leftover code to clean
- `lib/shared/widgets/placeholder_screen.dart` — unused since Phase 4; remove.
- `MockProfileRepository` in `repositories.dart` — unused; keep as the swap-back
  reference or delete. Same for the `me`/`likedYou`/`matches`/`gallery` bits of
  `MockData` that only real-vs-mock screens still read.
- `AppConstants.maxGalleryPhotos = 6` conflicts with the real 4-photo DB cap — the
  photo flow now hardcodes 4. Reconcile or remove the constant.
- `Profile.toInsertJson()` is defined but never used (onboarding builds its own map).

### 17.6 Accessibility, i18n, polish
- **Single locale** (`en`) only; roadmap is a *global* app — no i18n/l10n framework,
  no RTL, no multi-language (roadmap onboarding even collects "Languages").
- No **font bundling** — Roboto is fetched at runtime via `google_fonts` (offline
  reliability risk; the UI doc prefers bundled `.ttf`).
- Limited **semantics/screen-reader** labels beyond icon tooltips.
- No **app icon / splash / store assets** review noted.

---

## 18. Suggested build order (front-end)

1. ~~**Unblock the seams already coded**~~ ✅ **DONE 2026-07-09** — `markAsRead`,
   reactions render, `unmatch`/`block` UI, Calls-tab history, real
   `notification_preferences` toggles, real profile stats, Edit-Profile save.
   *(Safety `reports` was in this list but is **blocked** — the table doesn't
   exist; see §13.)*
2. **Device capabilities**: ✅ `image_picker` + storage upload **built** (blocked
   only on the buckets, **[BE-8]**); ⬜ `geolocator` → real GPS still to do.
3. **Push**: Firebase + `fcm_tokens` registration (needs **[BE-3]** for delivery).
4. **Payments**: reconcile plan names **[BE-4]**, then WebView + IAP flows.
5. **Report/Block flows** + verification (**[BE-5]**).
6. **Calls** (**[BE-6]**) — largest single module.
7. **Real discovery feed + Explore** (**[BE-9]**), profile-detail screen.
8. **Delete-account** real cascade (**[BE-7]**), devices/sessions (**[BE-1]**).
9. **Gifts/coins** (**[BE-12]**), incognito/boost, advanced search.
10. **Polish**: i18n, secure storage, offline, tests, legal copy, dead-code cleanup.
