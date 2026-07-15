# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Love Me International (Flutter)

Read this first every session. It tells you what this project is, where the truth
lives, and the rules for working on it.

## Commands

All commands need `C:\flutter\bin\flutter.bat` (the SDK is **not on PATH**) and
git on PATH first — run them as one PowerShell command, from the repo root:

```powershell
$env:PATH="C:\Program Files\Git\cmd;"+$env:PATH; Set-Location "d:\app dev paid pro\loveme\love_me"; & "C:\flutter\bin\flutter.bat" <cmd>
```

- **Analyze (lint/typecheck):** `flutter analyze`
- **Run all tests:** `flutter test`
- **Run a single test file:** `flutter test test/widget_test.dart`
- **Run app (dev, needs Supabase + Agora defines):**
  `flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key> --dart-define=AGORA_APP_ID=<id>`
  (see `.vscode/launch.json` for the actual dev project values / the "love_me (dev)" launch config)
- **Build debug APK:** `flutter build apk --debug` (same `--dart-define`s as run)
- **Build release APK:** `flutter build apk --release` — currently **debug-signed**
  (`android/app/build.gradle.kts` has a `// TODO: Add your own signing config`); fine
  for side-loading, not for Play Store upload.
- **Regenerate freezed/json_serializable/riverpod_generator code:**
  `flutter pub run build_runner build --delete-conflicting-outputs`

There is no CI config in this repo — `flutter analyze` + `flutter test` are the
whole verification loop today; both must be clean before calling work done.

## What this is

A **Flutter rebuild** of "Love Me International", a mobile-first global dating app
(adults 18+). It is a **client only** — the backend is Supabase (Lovable Cloud) and
is **already built and must NOT be re-implemented**. The Flutter app consumes the
same tables, RLS policies, RPCs, Edge Functions, storage buckets, and realtime
channels as the original React web app.

- Target: Flutter 3.24+ / Dart 3.5+, Android (min SDK 24) then iOS 13+.
- Architecture: feature-first Clean Architecture (Presentation → Domain → Data → Core),
  Riverpod 2 for state, go_router for routing, supabase_flutter for backend.

## Current state (keep this updated)

**PHASE 1 (Foundation & Design System) — built (2026-07-03).** The default scaffold
has been replaced with the app foundation. `lib/` now contains:
- `main.dart` → `bootstrap.dart` (ProviderScope) → `app.dart` (`MaterialApp.router`).
- `core/theme/` — `AppColors` (#E6287A / #FFB800), `AppTextStyles` (Roboto via
  google_fonts), `AppGradients`, light+dark `AppTheme`.
- `core/constants/` — `AppConstants`, `RoutePaths` (all 23 routes).
- `core/router/` — `go_router` with a ShellRoute for the 5 tabs + `router_guards.dart`
  (permissive STUB during mock phase).
- `shared/models/` — `Profile`, `Conversation`, `AppNotification` (plain immutable Dart).
- `shared/data/` — `mock_data.dart` (sample profiles/convos/notifications) +
  `repositories.dart` (repo interfaces + Mock impls + Riverpod providers — **the seam
  the backend track swaps**).
- `shared/widgets/` — `AppShell`, `AppHeader`+`HeaderAction`, `BottomNav`, `AppAvatar`,
  `state_views.dart` (Skeleton/Empty/Error), `PlaceholderScreen`.
- `pubspec.yaml` — front-end deps only (Riverpod, go_router, google_fonts, lucide,
  cached_network_image, shimmer, form_builder, freezed/json annotations, etc.). Backend
  SDKs intentionally absent.
- Every route resolves; the 5-tab shell renders with themed header/nav; non-built
  screens show `PlaceholderScreen` tagged with their target phase.

**PHASE 2 (Auth, Onboarding & Discover) — built (2026-07-04).** Real screens now
replace the Phase-1 placeholders for the entry funnel + Discover tab:
- `features/auth/` — `auth_controller.dart` (mock `AuthController`/`MockSession` —
  the seam the backend swaps), `auth_screen.dart` (01, Sign In/Up tabs, 18+ gate,
  Google btn, reset dialog), `email_verified_screen.dart` (02), `reset_password_screen.dart` (03).
- `features/onboarding/profile_setup_screen.dart` (04) — 4-step wizard.
- `features/discover/` — `discover_providers.dart` (filters + feed), `discover_filters_sheet.dart`,
  `discover_screen.dart` (06, card + actions + match overlay + states).
- `core/utils/validators.dart` — email/password/dob(18+)/name/bio/interests.
- `core/router/router_guards.dart` — real auth+profile-complete redirects (mock session).
- `app_router.dart` — routes 01-06 wired; refreshes on auth changes; Discover Filters action.

**PHASE 3 (Likes, Messages, Chat, Explore, Profile & Subscription) — built (2026-07-04).**
Real screens replace the placeholders for all 4 remaining tabs + chat + subscription:
- `features/likes/likes_screen.dart` (07) — Liked You / Matches tabs, premium blur + Unlock.
- `features/messages/messages_screen.dart` (08) — Chats/Calls tabs, search, swipe-delete, long-press.
- `features/chat/chat_screen.dart` (11) — bubbles, read receipts, reactions, composer, call icons (UI only).
- `features/explore/explore_screen.dart` (09) — country flag chips + profile grid.
- `features/profile/profile_screen.dart` (10) — banner, stats, edit sheet, setting rows, **Premium demo toggle**, sign out.
- `features/subscription/subscription_screen.dart` (15) — perks, plan cards, payment buttons (mock), usage bars.
- `shared/models/` +`Message`,`SubscriptionPlan`; `shared/data/` extended (likes/matches/messages/plans/countries/stats);
  `shared/widgets/profile_tile.dart`; `core/utils/date_format.dart`; `isPremiumProvider` gates free/premium.
- `app_router.dart` — all these routes now real.

Plan-name conflict is now materialized as **placeholder duration tiers** (Monthly/
Quarterly/Yearly, single "Premium") in `SubscriptionPlan` — still to reconcile with
the user before backend wiring.

**PHASE 4 (Settings, Safety, Legal, Admin & Polish) — built (2026-07-04).** The final
front-end phase; every remaining placeholder is now a real screen:
- `features/notifications/` (12) — typed feed, unread dots, mark-all, deep links.
- `features/settings/` (13) — sectioned prefs (discovery/notif/privacy/ringtone/account/legal).
- `features/devices/` (14) — active sessions, revoke, sign out everywhere.
- `features/safety/` (20) — report cards + status badges + detail sheet.
- `features/delete_account/` (21) — warning + type-"DELETE" + password gate.
- `features/legal/legal_screen.dart` (16-19) — shared prose scaffold (privacy/terms/refund/child-safety).
- `features/admin/` (22) — role-gated tabbed diagnostics (403 for non-admins; `isAdminProvider`).
- `features/misc/not_found_screen.dart` (23) — 404.
- `shared/models/` +`SafetyReport`,`DeviceSession`; providers for notifications/reports/devices/admin.
- `app_router.dart` — all routes real; `_FullScreen`/PlaceholderScreen no longer used.

**Verification (all green):** `flutter analyze` → **No issues found.**; `flutter test`
→ **All tests passed** (3). Not driven on an emulator this session — recommend a
`flutter run` walkthrough + a fresh `flutter build apk --release` as the checkpoint.

**Next:** BACKEND INTEGRATION (separate track) — see the milestone note above.

**Active plan (2026-07-03):** Build the **complete front end first with mock/in-memory
data only** (no Supabase calls); backend integration is a separate track afterward.
The work is divided into 4 phases in `FRONTEND_PLAN.md` — execute **one phase at a
time**, and wait for the user's "go" before starting the next.
- Phase 1: Foundation & Design System ✅ done
- Phase 2: Auth, Onboarding & Discover ✅ done
- Phase 3: Likes, Messages, Chat, Explore, Profile & Subscription ✅ done
- Phase 4: Settings, Safety, Legal, Admin & Polish ✅ done

**ALL 4 FRONT-END PHASES COMPLETE (2026-07-04).** All 23 screens built on mock data.

**BACKEND INTEGRATION — Auth & Profile layer (built, 2026-07-04 session 2).** Wired
against the 6 live tables from `app doctumant/migration_001.md` (migrations
`001_auth_profiles.sql` + `002_auth_profiles_rls.sql`; project ref
`tamlbnmihdcjiptbezjm`). Everything else in the full backend spec (matches, likes,
messages, payments, etc.) is still **not built server-side** — do not integrate
against those tables until a migration doc for them exists.
- `supabase_flutter` added; `Supabase.initialize()` runs in `bootstrap.dart` using
  `SUPABASE_URL`/`SUPABASE_ANON_KEY` from `--dart-define` (see
  `lib/core/config/supabase_config.dart` + `.vscode/launch.json`) — never hardcoded.
- `shared/models/profile.dart` rewritten to mirror the live `profiles` table
  (`birthday` instead of `age`; `age`/`ageLabel` are computed). Fields not yet
  backed by a column/table (`bio`, `gallery`, `interests`, `isPremium`, `isOnline`)
  stay **local-only** defaults until their schema ships.
- `features/auth/auth_controller.dart` now drives real `supabase.auth`
  (signUp/signIn/signInWithGoogle/requestPasswordReset/signOut), listens to
  `onAuthStateChange`, and inserts the minimal `profiles` row right after sign-up.
- `shared/data/repositories.dart`: `SupabaseProfileRepository` covers `me()`/
  `byId()` against `profiles`. `MockProfileRepository` kept in tree, unused, as
  the swap-back reference.
- `features/onboarding/profile_setup_screen.dart` PATCHes `profiles` on Finish and
  flips `profile_complete`.
- Verified: `flutter analyze` clean, `flutter test` green (2 unit tests — the old
  mock-driven auth tests can no longer run headlessly against a live network
  call, so they were replaced; full flow needs a manual `flutter run` walkthrough
  — not done this session).
- Deferred: `active_sessions` (single-device enforcement), `fcm_tokens`,
  `user_presence`, Google OAuth redirect config, plan-name reconciliation.
- **Bugfix (2026-07-06):** sign-up hit RLS 42501 on the `profiles` insert because
  the Supabase project has "Confirm email" ON (signUp() returns no session until
  confirmed, so the insert has no `auth.uid()`). Fixed by disabling "Confirm
  email" in the Supabase dashboard (user action, no code change). Re-enable
  before production launch — if you do, the profiles-insert-on-signUp flow in
  `auth_controller.dart` needs to move to post-confirmation instead.

**BACKEND INTEGRATION — Matching module (built, 2026-07-06).** Wired against
`003_matching.sql` + `004_matching_rls.sql` from `app doctumant/migration_002.md`:
`likes`, `passes`, `matches`, `profile_views`. **No mutual-like trigger exists
yet** — `matches` rows are not created by the app or currently by anything else;
the table is read/update-only from the client (unmatch/block).
- `shared/models/like.dart`, `match.dart` (NEW) — mirror the live wire shape.
- `shared/data/swipe_repository.dart` (NEW) — `SupabaseSwipeRepository`:
  like/pass/unlike + `getSwipedUserIds()`; maps Postgres `23505` (duplicate
  swipe) to a typed `AlreadySwipedException` instead of a raw Postgrest error.
- `shared/data/match_repository.dart` (NEW) — `SupabaseMatchRepository`:
  `myMatches()`/`unmatch()`/`block()` + `subscribeToNewMatches()` (realtime).
- `shared/data/repositories.dart`: `SupabaseProfileRepository.discoverFeed()`
  now excludes already-swiped profiles (mock candidate deck otherwise);
  `likedYou()`/`matches()` are real — joined against `profiles` via `.inFilter()`.
- `features/discover/discover_screen.dart`: like/pass/super-like call the real
  repository; the old "every 2nd like is a match" mock popup is **gone** — no
  immediate match feedback since the backend can't yet confirm mutuality.
- `features/likes/likes_screen.dart`: now a `ConsumerStatefulWidget` holding a
  live `RealtimeChannel` subscription on `matches` inserts — pops the "It's a
  Match!" dialog if/when a match row actually appears (future-proofed for the
  trigger).
- Verified: `flutter analyze` clean, `flutter test` green (no new tests — needs
  a live Supabase connection to exercise meaningfully). Not run on-device this
  session.
- Deferred: `profile_views`/`recordView()` (no quota UI consumes it yet);
  unmatch/block have no UI entry point yet (repository methods exist, unused).

**BACKEND INTEGRATION — Chat & Calls module (built, 2026-07-08).** Wired against
`005_chat.sql` + `006_chat_rls.sql` from `app doctumant/migration_003.md`:
`conversations`, `messages`, `message_reads`, `message_reactions`, `call_logs`.
**Chat is blocked for brand-new matches**: `conversations` has no INSERT policy
and no trigger yet auto-creates one when a match forms — the client can only
use a conversation backend has already inserted out-of-band. The Chat screen
shows an explicit "not available yet" empty state instead of erroring.
- `shared/models/conversation.dart` + `message.dart` (REWRITTEN) to mirror the
  live schema exactly (was a flat partnerId-keyed mock shape before). Added
  `message_read.dart`, `message_reaction.dart`, `call_log.dart` (NEW).
- `shared/data/chat_repository.dart` (NEW) — `SupabaseChatRepository`:
  message history/send/edit/soft-delete/markAsRead/reactions +
  `subscribeToMessages()` (realtime). Maps Postgres `23514` (message-shape
  constraint violation) to a typed `MessageConstraintException`.
- `shared/data/call_repository.dart` (NEW) — `SupabaseCallRepository`:
  start/updateStatus/end (`ended_at`+`ended_by` always sent together per the
  DB constraint)/history against `call_logs`. Wired but no screen calls it yet
  — no calling UI/WebRTC in this pass.
- `shared/data/conversation_repository.dart` (NEW) — `SupabaseConversationRepository`:
  joins active matches → conversations → the other participant's profile, and
  previews the latest message by querying `messages` directly (
  `conversations.last_message_id`/`last_message_at` aren't populated
  server-side yet). `forPartner(userId)` returns `null` when no conversation
  exists — the seam the Chat screen uses to detect "not available yet".
- `shared/data/repositories.dart`: old mock `ConversationRepository`/
  `MessageRepository` interfaces dropped entirely (shape changed too much to
  adapt at the boundary); `conversationsProvider` now returns
  `List<ConversationSummary>`; `messagesProvider` re-keyed from `partnerId` to
  `conversationId`.
- `features/messages/messages_screen.dart` + `features/chat/chat_screen.dart`
  rewritten for the live schema; Discover/Explore/Likes/Notifications chat
  call sites untouched — they still just `context.push(RoutePaths.chatTo(userId))`
  and the Chat screen itself resolves/handles the missing-conversation case.
- Verified: `flutter analyze` clean, `flutter test` green (2, unchanged). Not
  run on-device — needs backend to manually insert a `conversations` row for
  a real match to test end-to-end.
- Deferred: conversation auto-create trigger (the hard blocker), last-message
  populate trigger, media storage buckets, location coordinates, call UX/WebRTC,
  "seen by" read-receipt UI beyond the sender's own single/double-check.

**BACKEND INTEGRATION — Notifications module (built, 2026-07-08).** Wired
against `notifications` + `notification_preferences` from
`app doctumant/migration_004.md`. **`notification_queue` is off-limits to
Flutter entirely** — service-role/Edge Function only, never queried. Backend
status per the doc: schema + RLS complete; push dispatch/Edge Functions/
Firebase delivery/realtime are **not built yet**.
- `shared/models/app_notification.dart` (REWRITTEN) — real 11-value
  `NotificationType` enum (was a 7-value mock enum), `actorUserId` +
  `data` (jsonb) for deep-linking, replacing the old `relatedUserId` shortcut.
- `shared/models/notification_preferences.dart` (NEW) — mirrors the live
  8-column preferences row.
- `shared/data/notification_repository.dart` (NEW) — `SupabaseNotificationRepository`:
  fetch/markAsRead/delete on `notifications`; get/update/create-once on
  `notification_preferences`. **No client INSERT on `notifications`** — the
  client cannot create them, only read/update/delete its own.
- `features/auth/auth_controller.dart`: `signUp()` now also inserts the
  default `notification_preferences` row (per the doc's "run only once after
  signup").
- `features/notifications/notifications_screen.dart` (REWORKED) — icon
  mapping for the 11 real types; swipe-to-delete + tap-to-mark-read now call
  the real repository; pull-to-refresh added since there's **no realtime**
  (doc is explicit: refresh manually). Deep-links by `type`: `newLike` →
  Likes; `newMatch`/`newMessage`/`callIncoming`/`callMissed` → Messages list
  (their `data` carries a `conversation_id`, not a partner user id, and the
  chat route is keyed by partner id, so this avoids guessing a lookup that
  doesn't exist); `profileView`/`profileVerified` → Profile;
  `subscription*` → Subscription; `reportUpdate` → Safety Reports.
- Verified: `flutter analyze` clean, `flutter test` green (2, unchanged). Not
  run on-device — client can't create notifications, so testing needs
  backend to have inserted at least one row for a test account.
- Deferred (explicit user decision): Settings screen's Notifications section
  (Push/Email/Sound/Vibration) left as mock UI — Sound/Vibration have no
  backing column anywhere; wiring the real 8-toggle preferences UI is a
  separate pass.

**BACKEND INTEGRATION — Profile Photos module (built, 2026-07-08).** Wired
against `009_profile_photos.sql`/`010_profile_photos_rls.sql`, the
`sync_primary_profile_photo` trigger, and the `set_primary_profile_photo` RPC
from `app doctumant/migration_005,006,007.md`. **This doc was verified by
static trace through the migration SQL, not against a live database** — smoke
test the upload → set-primary → discover-feed flow for real before shipping.
**No storage bucket/upload pipeline exists** — `photo_url` has no real image
source yet, so writes use clearly-labeled placeholder `picsum.photos` URLs as
a stand-in (user decision) while the full read/write/set-primary/delete flow
runs for real against Supabase.
- `shared/models/profile_photo.dart` (NEW) — mirrors `profile_photos` exactly.
- `shared/data/profile_photo_repository.dart` (NEW) — `SupabaseProfilePhotoRepository`:
  `myPhotos()`/`addPhoto()`/`setPrimary()` (via the RPC)/`deletePhoto()`. Maps
  `23505` (display_order slot taken) → `ProfilePhotoSlotTakenException`,
  `23514` (constraint violation) → `ProfilePhotoConstraintException`.
- `features/profile/profile_screen.dart` — gallery is now a live grid: tap a
  non-primary photo to make it primary (RPC), long-press to delete, "+" tile
  (shown under the 4-photo cap) adds a placeholder photo at the next free
  `display_order`. Primary-photo changes invalidate `currentUserProvider` too,
  since `profiles.photo_url` is kept in sync by the DB trigger.
- `features/onboarding/profile_setup_screen.dart` — the avatar step now
  inserts a real `profile_photos` row (`display_order: 1, is_primary: true`)
  instead of flipping a local bool; the trigger mirrors it onto
  `profiles.photo_url` automatically, so Discover/Likes/Matches (which all
  read that column) pick it up with no extra wiring.
- Local `_maxProfilePhotos = 4` constant used instead of
  `AppConstants.maxGalleryPhotos` (=6) for this flow's slot math, since 4 is
  the real DB constraint. **Flagged, not resolved:** that mismatch — the
  `maxGalleryPhotos` constant may be intentional scope for a future
  non-`profile_photos` feature, or just stale; reconcile if it turns out unused.
- Verified: `flutter analyze` clean, `flutter test` green (2, unchanged). Not
  run on-device — this module specifically deserves a live walkthrough given
  the doc's own "static trace only" caveat.
- Deferred: no RPC for adding a photo or reordering (direct table access under
  RLS is the only path today), no auto-promotion of a new primary when the
  current one is deleted (`profiles.photo_url` just keeps its last-synced value).

**FRONT-END — Media upload feature (built, 2026-07-08→09).** Real photo/video/
voice capture + upload replaces every placeholder-URL / no-op media spot that
has a screen today. `image_picker` + `google_mlkit_face_detection` +
`record` + `video_thumbnail` + `path_provider` added.
- `core/media/photo_picker_service.dart` (NEW) — `pickProfilePhoto` (with
  ML-Kit **face-check** — rejects non-person photos), `pickChatImage`/
  `pickChatVideo` (no face-check; video generates a thumbnail).
- `core/media/photo_source_sheet.dart` (NEW) — shared "Take Photo / Choose
  from Gallery" sheet. `core/media/voice_recorder_service.dart` (NEW) —
  `record`-based voice notes.
- `shared/data/profile_photo_repository.dart`: `uploadPhoto()` → **public
  `avatars`** bucket. `shared/data/chat_repository.dart`: `uploadChatImage`/
  `uploadChatVideo`/`uploadVoice` → **private** `chat-images`/`chat-files`/
  `chat-file-thumbs`/`voice-messages` buckets (7-day signed URLs).
- Wired: onboarding avatar + gallery (real photos, face-checked); Profile
  gallery "+"/avatar badge (face-checked); Chat attach (image/video) + voice
  message; chat bubbles now render image/video(thumb+play)/audio.
- Android manifest: CAMERA + RECORD_AUDIO perms + ML-Kit face model metadata.
- Face-check is **profile photos only** (chat media unrestricted); the
  authoritative human/NSFW gate is still the server `moderate-image` fn — not
  built (**[BE-5]** in `app doctumant/BACKEND_REMAINING.md`).
- **⚠️ REQUIRES the user to create 5 Storage buckets:** public `avatars`;
  private `chat-images`, `chat-files`, `chat-file-thumbs`, `voice-messages`.
  Uploads fail until they exist. Verified `flutter analyze`/`test` green; NOT
  run on-device (needs camera/mic + the buckets).
- Deferred media spots (need new screens/backend): video profile, ID/selfie
  verification, Wise receipt; chat emoji picker; iOS Info.plist usage strings.

**MEDIA / MATCHING BACKEND WENT LIVE — client reconciled (2026-07-10).** The
backend team deployed & verified migrations 009-019 (see their deploy memo). This
closed three things the client had been coding around as "not built yet":
- **5 Storage buckets + 16 RLS policies are LIVE** — photo/gallery/chat-media/voice
  uploads now work for real (the client's real `uploadBinary` path was always there;
  it just 404'd at the storage layer before). No more placeholder URLs.
- **Mutual-like → match → conversation triggers are LIVE** (`create_match_on_mutual_like`
  + `create_conversation_on_match`, `SECURITY DEFINER`). A mutual like now creates the
  match + conversation automatically; the Likes realtime "It's a Match!" overlay fires
  for real, and every match immediately has a working chat.
- Client changes made this session: removed the stale "trigger hasn't shipped / chat
  not available yet" scaffolding across `swipe_repository`/`match_repository`/
  `conversation_repository`/`chat_repository`/`chat_screen`/`discover_screen`; the
  Chat screen's null-conversation state is now a transient "Setting up your chat… /
  Retry", not a permanent wall. **Chat media now stores object PATHS** (not 7-day
  signed URLs) in `messages.media_url`/`thumbnail_url` and mints a fresh 1-hour signed
  URL at render time (`ChatRepository.signedUrlFor` + the `_MediaThumb` widget) — fixes
  the "media 403s after 7 days" problem (deploy memo open Q1, option a). A legacy
  http(s) value in those columns is passed through unchanged for back-compat.
- **Still the one media launch blocker:** `moderate-image` (server NSFW/human gate) is
  **not built** — uploads aren't scanned server-side. See `BACKEND_REMAINING.md` [BE-5].

**UI PARITY TRACK WITH THE OLD APP — COMPLETE (2026-07-10, Phases 0-5).** The old
app's screenshots live in `app doctumant/old app ss/`. Two docs drove this work:
- **`app doctumant/UI_GAP_ANALYSIS.md`** — full screen-by-screen diff (old vs ours).
- **`app doctumant/UI_REBUILD_PLAN.md`** — the 5-phase executable plan + Progress
  Tracker, now showing **Phase 0-4 fully done, Phase 5 done except §5.1**.
- ✅ **The plan-name conflict is RESOLVED:** `SubscriptionPlan`/`MockData.plans` now
  carry the real 5 tiers — Basic+ $5/500/Silver, Gold $10/1000/Gold, Platinum
  $15/1500/Diamond, Premium Elite $20/2000/Crown, VIP Elite $25/Unlimited/VIP.
- ✅ **RESOLVED 2026-07-11: legal copy is real.** User supplied the old app's actual
  published Terms & Conditions / Privacy & Terms hub / Child Safety Standards
  screenshots (incl. the Google Play CSAE compliance statement); transcribed
  verbatim into `features/legal/legal_screen.dart` (`LegalScreen.terms()`,
  `LegalHubScreen`, `ChildSafetyScreen`). **Refund Policy is the one exception** —
  no old-app screenshot was provided for it, so it follows the same real-content
  pattern but wasn't directly transcribed; swap it if/when the real screenshots
  arrive. See developer.log 2026-07-11.
- Every screen in `lib/features/` was rebuilt or restructured to match the
  screenshots: design tokens/header/nav/auth (Phase 1), Discover (Phase 2),
  Profile/Likes/Explore (Phase 3), Settings/Subscription/Messages/Chat (Phase 4),
  the 4 remaining modals (`shared/widgets/info_modals.dart`) + Delete
  Account/Devices/Notifications simplification + dead-code cleanup (removed the
  Admin screen, `placeholder_screen.dart`, `maxGalleryPhotos`) + a dark-mode
  hardcoded-color audit/fix across 11 screens (Phase 5).
- **Standing rule that shaped every phase:** when data doesn't exist yet, **hide the
  UI element** — never fake a number. Several elements (the header's 📅 account-
  expiry pill, Discover's "last active"/"Approx" GPS badge, Explore's country RPC
  counts, chat block/report) still render nothing or a "coming soon" toast for
  exactly this reason — see `BACKEND_REMAINING.md` for what unblocks each one.
- **Not yet done:** a live `flutter run` walkthrough — this whole 5-phase effort was
  verified via `flutter analyze`/`test`/`build apk --debug` only, never on a real
  emulator/device. Do that pass (incl. toggling Dark Mode) before considering the
  UI track fully signed off.

Other gap docs: `app doctumant/FRONTEND_REMAINING.md` + `BACKEND_REMAINING.md`
(backend hand-off for media/storage: `BACKEND_MEDIA_REQUIREMENTS.md`).

**PUSH NOTIFICATIONS — Firebase project + client-side FCM, Android (built
2026-07-11; backend delivered 2026-07-13).** Real Firebase project created
(`love-me-international`); Android `applicationId`/namespace changed from the
`com.example.love_me` placeholder to the real `com.loveme.international`
**before** registering with Firebase (iOS bundle id left as-is, Android-first).
`firebase_core`/`firebase_messaging` added; `lib/core/notifications/fcm_service.dart`
handles permission request, device token capture (+ refresh), persists the
token to the live `fcm_tokens` table, and handles foreground/background/
terminated message tap-to-navigate via the same routing table the in-app
notifications list uses (`lib/core/notifications/notification_router.dart` —
extracted so the two never drift). **Backend side is now live too**: trigger
functions insert a `notifications` row on new_like/new_match/new_message/
call_missed/profile_view, and a `send-fcm-push` Edge Function (triggered on
every `notifications` insert) checks preferences and calls the FCM v1 API,
pruning invalid tokens automatically. `fcm_tokens`' unique constraint is
`(user_id, token)` — the client's upsert `onConflict` was updated to match.
`report_update`/`subscription_expiring`/`subscription_active` notification
types remain unavailable — blocked on `reports`/`subscriptions` tables that
don't exist yet (tracked in `BACKEND_REQUIREMENTS_HANDOFF.md`). See
developer.log 2026-07-11 and 2026-07-13 for the full history.
**Still not run on a real device/emulator** — the next concrete step is
signing in on a physical device or emulator with Play services, confirming a
row lands in `fcm_tokens`, then triggering each event type and confirming a
push arrives in foreground/background/killed-app states.

**VOICE/VIDEO CALLING — full Agora client built, FRONTEND ONLY (2026-07-13).**
The entire calling experience is now built client-side against Agora RTC.
**Media = Agora; signaling = the existing `call_logs` table + Supabase
Realtime** (ring/accept/decline/end are status transitions on the call row,
observed live; Agora carries audio/video once both sides join the channel = the
call's UUID). Packages: `agora_rtc_engine` + `permission_handler`.
- `core/config/agora_config.dart` (NEW) — `AGORA_APP_ID` via `--dart-define`
  (public; the Agora **App Certificate stays server-only**).
- `shared/models/call_log.dart` EXTENDED — `channelName`/`callerAgoraUid`/
  `receiverAgoraUid` (nullable/defensive, works against today's schema).
- `shared/data/call_repository.dart` REWRITTEN — `startCall` writes
  `ringing`; `answer/decline/cancel/markMissed/endCall`; `getAgoraToken` (Edge
  Function `get-agora-token`); `subscribeToIncomingCalls`/`subscribeToCall`
  (realtime). `AgoraToken`/`AgoraTokenException` added.
- `core/calls/agora_call_service.dart` (NEW) — one `RtcEngine` per call;
  permissions, join/leave, mute/camera/speaker/flip.
- `features/calls/` (NEW) — `call_state.dart` (CallPhase machine),
  `call_controller.dart` (StateNotifier driving the lifecycle + 35s ring
  timeout + duration), `call_screen.dart` (single full-screen surface for all
  phases, audio + video PiP), `call_overlay.dart` (mounted above the router via
  MaterialApp.router `builder` — rings on ANY screen).
- Wired: chat header phone/video buttons (was "coming soon" toast) + Messages
  "Calls" tab tap-to-call-back. Android manifest: added INTERNET/
  ACCESS_NETWORK_STATE/MODIFY_AUDIO_SETTINGS/WAKE_LOCK/BLUETOOTH(_CONNECT).
- **Backend contract:** `app doctumant/BACKEND_CALLS_HANDOFF.md` (NEW) — the
  server side owed: 3 `call_logs` columns + channel-name trigger, INSERT/UPDATE
  RLS, the `get-agora-token` Edge Function, Realtime on `call_logs`, optional
  `notify_on_missed_call` trigger. **ALL DELIVERED & LIVE (backend confirmed
  2026-07-13)** — columns + channel-name trigger, `get-agora-token` deployed
  with secrets set, Realtime on `call_logs`, and the `call_missed` push. RLS
  already existed from 006_chat_rls.sql (no helper fn needed).
  `caller_/receiver_agora_uid` are deliberately left null server-side — the
  client's deterministic local uid stays authoritative.
- Client reconciled to the backend's exact `get-agora-token` status-code
  contract (401/403/404/500 → specific messages) and now requires a non-null
  token (production always returns one).
- Verified: `flutter analyze` clean (same 4 pre-existing infos, zero in call
  files), `flutter build apk --debug` BUILT (Agora native SDK compiled),
  `flutter test` green (2). **NOT yet run on a device — this is now the ONLY
  remaining step**: real `AGORA_APP_ID` via `--dart-define` + two signed-in
  matched devices → place/ring/answer/connect/end. Out of scope for v1
  (flagged in the doc): native ringing on a killed app (FCM/CallKit), group
  calls, recording.
- **Debug + release APKs built (2026-07-13)** with the real Agora App ID
  (`4874bd18…7637`, from the Agora Console — the App Certificate stays
  backend-only and was NOT put in the client). Release build is currently
  **debug-signed** (`android/app/build.gradle.kts` — `// TODO: Add your own
  signing config`), fine for side-loading test devices, NOT for Play upload.

**PRESENCE, DEVICE SESSIONS, PROFILE VIEWS, PROFILE-DETAIL VIEW (built
2026-07-13).** Four items wired against tables that were already live but
unused — no backend work needed. (3 related items were considered and
dropped: Settings has no discovery/privacy toggles left to persist post-UI-
parity-rewrite; onboarding's photo gallery was already fully real, not mock;
ringtone stays device-local per an earlier deliberate design decision,
confirmed with the user rather than reversed.)
- **Presence** — `shared/data/presence_repository.dart` (`user_presence`
  upsert) + `core/presence/presence_service.dart` (app-lifecycle-driven:
  online on resume, offline on pause/detached, 2-min heartbeat since there's
  no server staleness sweep). Started/stopped around sign-in/sign-up/
  restore/sign-out in `auth_controller.dart`. Wired into the chat header's
  real online dot via the new `presenceForProvider(userId)` — `Profile.
  isOnline` itself stays local-only/false by design (matches `bio`/
  `interests`); `ProfileTile` (Likes/Explore grids) is NOT yet wired
  (plain `StatelessWidget`, needs a `ConsumerWidget` conversion — deferred).
- **Device sessions** — `shared/data/device_session_repository.dart`
  (`active_sessions` CRUD) + `core/devices/device_session_registrar.dart`
  (registers a session row per sign-in, device label from
  `Platform.operatingSystem`). `devices_screen.dart` now reads real rows
  (was `MockData.devices`); "Sign out of other devices" really deletes rows.
  **No server-side single-device enforcement exists** ([BE-1]) — this makes
  the screen honest, it doesn't force another device to sign out.
- **Profile-view recording** — `shared/data/profile_view_repository.dart`
  inserts into `profile_views` (`{viewer_user_id, viewed_user_id}`,
  best-effort/silent) whenever `ProfilePreviewModal` opens. No quota
  enforcement exists server-side (`record_profile_view` RPC missing,
  [BE-10]) — this only logs the view.
- **Profile-detail view** — `ProfilePreviewModal` (shared by Likes/Explore)
  rebuilt from a small fixed sheet into a `DraggableScrollableSheet` full
  detail view: real multi-photo gallery (same `cardPhotosProvider` Discover's
  card carousel uses) + every profile field. Discover's "Show more" now opens
  this same shared modal (its old separate hobbies-only `_showMore` sheet
  was deleted) — one profile-detail surface everywhere.
- Also fixed (blocking ALL builds, unrelated to the above): enabled Android
  core library desugaring in `build.gradle.kts` — `flutter_local_notifications`
  (added earlier for FCM) needs it and it was never turned on.
- Verified: `flutter analyze` clean (same baseline + 1 new same-style info),
  `flutter test` green (2), `flutter build apk --debug` BUILT. Not run
  on-device — needs a live signed-in session to exercise meaningfully.

**LAUNCH TIER LIST (2026-07-14) — READ THIS FIRST IN A NEW SESSION.** Full
detail + how it was derived is in `developer.log`'s 2026-07-14 entry; this is
the actionable summary. User wants the whole app taken line-by-line, top
tier first, **subscription/payments deliberately excluded until the very
end**. A fresh ground-truth audit (not just this changelog) confirmed: the
Android package rename to `com.loveme.international` is fully complete
(git-status ambiguity was just uncommitted work, not a stuck migration);
Firebase (Android) config is real and present; iOS is 100% untouched since
the initial scaffold commit; payments are 100% mock (zero payment SDK, the
"purchase" flow is a 900ms delay that flips a local bool); `moderate-image`
(NSFW gate) is still fully absent client+server side.

- **S-TIER (do first, ground-truth checks):** (1) fresh `flutter analyze` +
  `flutter test`; (2) a real device/emulator `flutter run` walkthrough of the
  full flow (sign-up→onboarding→Discover→match→chat→call→notifications) —
  almost everything so far has only been analyze/test/build-verified, never
  actually used; (3) confirm in the Supabase dashboard whether "Confirm
  email" + the redirect allow-list were ever actually fixed
  (`BACKEND_CONFIRM_EMAIL_HANDOFF.md`).
- **A-TIER (safety/trust blockers) — FRONTEND + BACKEND DONE BY
  DESIGN/INSPECTION; ONLY A LIVE-DEVICE VERIFICATION PASS REMAINS
  (2026-07-14).** Full 3-round exchange with backend (see
  `app doctumant/BACKEND_ATIER_HANDOFF.md` →
  `Safety.Trust Backend.md` → `ATIER_FOLLOWUP_TO_BACKEND.md` →
  `a-tierfollow up.md` → `ATIER_CLOSEOUT_TO_BACKEND.md`, and 3 developer.log
  2026-07-14 entries for the full trace) resolved every open item:
  1. `reports` table + RLS — ✅ done, no client changes needed.
  2. `blocked_users` — ✅ **fully done now.** Schema/RLS + filtering both
     shipped: `matches`/`conversations` got the block-exclusion folded into
     their existing RLS (zero client change); `profiles` was deliberately
     left open (needed elsewhere — Blocked Users screen, viewing a blocked
     user's own profile page) and instead backend added a
     `profiles_discoverable` view with the same exclusion logic.
     **Client change made**: `SupabaseProfileRepository.discoverFeed()`
     (`lib/shared/data/repositories.dart`) now queries
     `profiles_discoverable` instead of `profiles`. Verified via
     `flutter analyze`/`test`.
  3. `delete-account` Edge Function — ✅ done. A real client bug was found
     + fixed while verifying: `ChatMessage.senderId` was non-nullable, but
     backend's design (anonymize a deleted user's messages via
     `sender_id = NULL`) makes null sender a real reachable state — now
     `senderId` is `String?`, `isMine()` treats null as "not mine", chat
     bubbles show a "Deleted user" label. Conversations stay orphaned (not
     hard-deleted), confirmed. **Chat-media storage cleanup: decided
     against it** — backend found cleaning up media would leave broken
     image/video/audio icons (message row survives per "history intact",
     but its file would be gone), so the user chose to keep orphaned
     media in place rather than build a new placeholder-flag mechanism.
     `delete-account` needs no further change.
  4. 4 quota RPCs — ✅ done, including the `record_profile_view`
     return-type change (`void`→`json`) — client was already coded against
     the `json` contract, no action needed.
  5. `moderate-image` — 🟡 infra/schema done, classifier stubbed
     (intentionally, no provider chosen yet) — no timeline pressure, as
     originally scoped.
  - **What's left:** a live-device/emulator walkthrough that actually
    exercises blocking end-to-end (two real accounts, one blocks the
    other, confirm they vanish from Discover/matches/chat) — everything
    above is verified by code inspection and `flutter analyze`/`test`
    only, never run against a live Supabase session. This is folded into
    S-TIER item 2 (the standing "run the app on a real device" item) —
    once that pass specifically confirms blocking works, A-TIER is fully
    closed and B-TIER can start.
- **B-TIER — FRONTEND + BACKEND DONE FOR ALL 4 CODE ITEMS (2026-07-14); 2
  REMAINING ITEMS ARE MANUAL DEVICE TESTS.** Full round-trip with backend
  (`app doctumant/BACKEND_BTIER_HANDOFF.md` → `B-TIER Backend Response.md`,
  developer.log's 3rd/4th 2026-07-14 entries) closed every backend-dependent
  item same-day. Correction to older entries: Discover was NOT "still 5 mock
  profiles" by the time this tier started — `discoverFeed()` already
  queried real `profiles_discoverable` rows (done as part of A-TIER's
  blocking fix). The real gap was ranking/geo/pagination + Explore's
  genuinely-still-mock `byCountry()`/country counts.
  1. Discovery feed — ✅ **fully done now.** `discoverFeed()` calls the
     real `get_discover_profiles_page(p_limit, p_offset)` RPC (not
     `get_discover_profiles()` — a same-named-but-different, pre-existing
     0-arg function this client has never used; backend's first attempt
     overloaded that name and broke it via a PostgREST ambiguity error,
     caught via their own smoke test and fixed same-day under the new name
     `get_discover_profiles_page`). Self/suspended/already-liked/passed/
     matched/blocked exclusion all happen server-side now via
     `profiles_discoverable`. Distance is still client-side
     (`lib/core/utils/geo_distance.dart`, Haversine against each user's
     onboarding GPS fix) — display-only, no server-side geo-ranking (that
     needs a product decision on scope + optionally PostGIS, deliberately
     not built this pass).
  2. Explore — ✅ done. Real per-country counts via `get_country_counts()`
     RPC (exact spec match) + real `byCountry()` querying
     `profiles_discoverable`.
  3. `ProfileTile` presence — ✅ done. Was dead code (defined, never
     instantiated anywhere). Converted to `ConsumerWidget` reading real
     `presenceForProvider`, wired into Explore's country-user list as its
     first-ever live call site (2-col grid, was a `ListTile` list).
  4. Extended profile fields — ✅ done. `bio`/`interests`/`occupation`
     columns shipped (`036_extended_profile_fields.sql`, exact spec —
     500-char bio cap, `text[]` interests like `hobbies`). Edit Profile
     saves no longer throw. Roadmap's other extended fields (education/
     religion/languages/height/lifestyle/etc.) still deliberately not
     wired pending a product scope decision.
  5. Two-device Agora call test — manual, still not started (no code to
     write; user's to run whenever convenient).
  6. Push-notification "app fully closed" retest — manual, still not
     started (same as above).
- **C-TIER — CODE ITEMS DONE (2026-07-14), pending one backend
  confirmation.** Before building anything, re-verified the actual chat
  code rather than trusting this list — **3 of the 4 listed chat items
  were already fully built**, a second instance of a stale tier-list claim
  (same pattern as B-TIER's Discover correction). See
  `app doctumant/BACKEND_CTIER_HANDOFF.md` and developer.log's 2026-07-14
  entry for the full trace.
  1. Emoji picker — ✅ already done (not missing). Two hand-rolled pickers
     (20-emoji reactions, 48-emoji composer), no package, already live
     against `message_reactions`.
  2. Edit message — ✅ already done (not missing). Long-press → dialog →
     real `messages.is_edited`/`edited_at` columns.
  3. Delete message — ✅ already done (not missing). Long-press → confirm →
     soft-delete via `is_deleted`/`deleted_at`, already filtered server-side.
  4. Onboarding GPS — ✅ verified genuinely real, not faked. Real
     `geolocator` calls, real error handling, real persisted coordinates.
     Struck from future tier lists — nothing to fix.
  5. Typing indicator — ✅ **the one item that was actually missing, now
     built.** Supabase Realtime Broadcast (ephemeral, no new table) — see
     `ChatRepository.broadcastTyping`/`subscribeToTyping` +
     `chat_screen.dart`'s debounced composer hook + 4s silence timeout.
     Pending: backend confirming whether Realtime Authorization (private
     channels) is active on this project — if not (the common default),
     this needs zero backend action and already works end-to-end.
  - **Not attempted this pass** (need user-supplied content/assets/
    decisions, not more frontend code): Refund Policy copy (only legal
    page not transcribed from a real screenshot — turned out to already
    be real prose, see below); ringtone preview audio (needs 3 real audio
    files); the unanswered `BACKEND_SCHEMA_VERIFICATION_QUESTIONS.md`
    thread (just needs resending); real release signing config (needs a
    real keystore).

**iOS is explicitly OUT OF SCOPE — not a target platform right now**
(user decision, 2026-07-15). Do not plan or flag iOS work; Android is the
only target until this changes.

**POST-TIER GROUND-TRUTH AUDIT (2026-07-15) — READ THIS FOR "WHAT'S LEFT."**
After A/B/C-TIER, the user asked for a fresh full-app audit rather than
trusting this file (proven stale twice already). Confirmed: Refund Policy
copy is actually already real prose (not a placeholder — the old note
above was stale); Settings screen toggles are all real (an old
FRONTEND_REMAINING.md claim of "every toggle mock" is stale); the
"calling shows not available" toast in chat/messages is correct, deliberate
behavior gated on `AgoraConfig.isConfigured` (only fires in builds without
a real Agora App ID), not a bug. **One real gap was found and fixed this
session: identity verification had no backend to submit to.**

- **Identity verification — REBUILT FOR REAL (2026-07-15), BACKEND LIVE
  (confirmed same-day, migrations `040`/`041`).** Was uploading to the
  **public** `avatars` bucket (a real privacy issue — ID documents/
  selfies could have been publicly reachable by URL) with purely local
  `setState` status that reset on navigation. Now: uploads go to a private
  `verification-documents` bucket (10MB limit, image/jpeg+png+webp,
  owner-scoped INSERT only, deliberately **no SELECT policy for any
  client role** — reads are service-role/reviewer-tooling only, per spec),
  submissions insert into a live `verification_requests` table, and status
  (`Verified`/`Under review`/`Rejected — resubmit`/`Not verified`)
  persists across sessions and reads from the real, already-live
  `profiles.is_verified` column as the authoritative source for the
  verified badge. `VerificationFeatureUnavailableException` should no
  longer trigger. See `app doctumant/BACKEND_VERIFICATION_HANDOFF.md`.
  **Not yet built (explicitly out of scope of that doc): an approval
  pipeline** — today, approving a request means directly flipping
  `verification_requests.status` + `profiles.is_verified` by hand
  (service role/Supabase Studio); no admin UI/trigger/Edge Function
  exists for this yet. Every submission sits at `pending` until that's
  built — flagged for whenever it becomes a priority, not blocking.

**Remaining known gaps (none fixed yet, all flagged, user's call on
priority):**
- **Zero real test coverage** — 1 file, 2 trivial `AuthState` unit tests,
  no widget/integration/repository tests anywhere. The single biggest
  quality-risk item on this list.
- **Android release signing** — still debug-signed
  (`android/app/build.gradle.kts` still has the stock `// TODO: Add your
  own signing config` comment). Blocks any real Play Store upload.
- **`BACKEND_SCHEMA_VERIFICATION_QUESTIONS.md`** — sent 2026-07-11, still
  unanswered. Just needs resending/following up with backend.
- **Ringtone preview audio** — cosmetic; all 3 options still play the
  same system sound pending 3 real audio files.

- **FINAL TIER — REAL GOOGLE PLAY BILLING BUILT (2026-07-15), BLOCKED ON
  BACKEND.** User supplied the real, locked 5-tier pricing table with
  Google Play product IDs (`basic_plus_monthly`/`gold_monthly`/
  `platinum_monthly`/`premium_elite_monthly`/`vip_elite_monthly`) and
  asked for real billing integration — tackled last, as planned. See
  `app doctumant/BACKEND_PAYMENTS_HANDOFF.md` and developer.log's
  2026-07-15 entry for full detail.
  - Added `in_app_purchase` (official Flutter package) — the only new
    dependency. `lib/core/billing/billing_service.dart` (NEW) wraps real
    Google Play Billing (query products, launch purchase, purchase
    stream, restore). `lib/shared/data/purchase_repository.dart` (NEW)
    sends completed purchases to a proposed `verify-purchase` Edge
    Function — this client never grants premium itself, only backend can
    (needs the Google Play Developer API + a service account, server-only).
  - `subscription_screen.dart` rewritten: real per-plan "Subscribe"
    buttons launching the actual Play purchase sheet, real prices from
    the Play Console when available, real plan/premium status shown
    (renewal banner, "CURRENT" ribbon). The pre-existing mock M-PESA
    button and dead-end Wise receipt-upload button are **unchanged** —
    kept per explicit user decision, not part of this pass.
  - **Found and fixed a real wiring gap**: `isPremiumProvider` was a bare
    `StateProvider<bool>` completely disconnected from the real, already-
    live `profiles.is_premium` column — the old mock "activation" just
    flipped this local flag, and every premium gate app-wide (Discover,
    Likes, Profile, Settings) read only from it. Now a derived provider
    reading the real column; same call sites, zero call-site changes
    needed since they only ever did a plain bool watch.
  - New `Profile.planId` field (`profiles.plan_id`, proposed column,
    read-only — only backend's `verify-purchase` function sets it).
  - Android: added the required `com.android.vending.BILLING` permission.
  - Verified: `flutter analyze`/`test` clean, `flutter build apk --debug`
    BUILT. **Not testable further without backend** — Google Play Billing
    doesn't work against side-loaded debug builds at all; needs a real
    Play Console listing + signed build on at least an internal-testing
    track once backend ships the verification piece.
  - **Blocked on backend**: `profiles.plan_id` column + the
    `verify-purchase` Edge Function (both schema+logic spelled out in the
    handoff doc, including the easy-to-miss "acknowledge the purchase
    within ~3 days or Google auto-refunds it" requirement). Real-Time
    Developer Notifications (renewals/cancellations/refunds) flagged as a
    recommended fast-follow, not a launch blocker.
  - **This closes out the original A/B/C/Final tier list** — every
    planned feature area now has a frontend pass done. Remaining gaps are
    the pre-existing ones below, plus whatever backend flags in response
    to the payments handoff doc.

**Tooling note (Windows):** Flutter SDK **3.44.4 / Dart 3.9** lives at **`C:\flutter`**
(moved off `D:\app dev\tute\flutter` because the space in that path broke the
native-assets build hook). It is NOT on PATH; git is also not on the sandbox PATH but
IS at `C:\Program Files\Git\cmd`. Flutter needs git, so run everything in ONE command:
`$env:PATH="C:\Program Files\Git\cmd;"+$env:PATH; Set-Location "d:\app dev paid pro\loveme\love_me"; & "C:\flutter\bin\flutter.bat" <cmd>`
(git safe.directory already configured for the SDK). Windows-desktop build needs a VS
C++ workload we don't have — irrelevant; target is Android/web. Icons use
`lucide_icons_flutter` (the old `lucide_icons` is incompatible with Flutter 3.44).

**Locked:** palette = pink `#FF1F8E` + gold `#FFB800` (Roboto, 448px max width;
warmed from the original `#E6287A` in Phase 1 to match the old app). Plan names are
resolved (see above) — Basic+/Gold/Platinum/Premium Elite/VIP Elite are final.

## The source of truth

All product/design/engineering detail is in `app doctumant/`. Read the relevant one
before building — do not invent behavior.

- `app.docx` — product roadmap (28 phases, features, plan tiers). **It's Markdown, not Word.**
- `LoveMe-Backend-API-Documentation.docx` — tables, RLS, RPCs, 29 Edge Functions, storage, realtime.
- `LoveMe-Flutter-Rebuild-Documentation.docx` — architecture, folder structure, pubspec, providers, roadmap.
- `LoveMe-UI-Documentation.docx` — design system, 23 screens, components, states, validation, a11y.
- `screens-json/00_INDEX.json` + `01..23_*.json` — **per-screen build specs**: components,
  apiCalls, stateManagement, validation, loading/empty/error/success states, tokens.
  When building a screen, open its JSON first.

`README.md` is the human-facing summary of all the above. `developer.log` is the
running build journal.

## Working rules

1. **Never touch the backend.** No SQL, no Edge Function code, no schema changes.
   The app calls existing REST/RPC/functions/storage/realtime endpoints only.
0. **Front-end phase = mock data only.** Until all 4 `FRONTEND_PLAN.md` phases are
   done, repositories return fake in-memory data — do NOT add `supabase_flutter`,
   Firebase, WebRTC, geolocator, or payment SDKs yet. Keep the repository seam clean
   so the backend track can swap data sources without touching UI.
2. **Build to the spec.** Each screen has a JSON spec in `screens-json/` and prose in
   the UI doc. Match components, API calls, providers, and all four UI states
   (loading/empty/error/success).
3. **Client never holds secret keys.** Payment/moderation secrets live in Supabase.
   The app only uses `SUPABASE_ANON_KEY` and public provider keys via `--dart-define`.
4. **Enforce the business caps** client-side AND rely on server gates: 18+ age gate,
   50 likes/24h free, 50 profile views/month free, matches-only messaging for free tier,
   mandatory `moderate-image` before image commit, single-device session.
5. **After any real change, append an entry to `developer.log`** (dated, what/why/result).
   This is a standing instruction from the user.
6. **Update this file's "Current state" and README** when the build materially advances.

## Unresolved decisions (raise with user before building the affected area)

- **Refund Policy copy** — the only legal page not transcribed from a real old-app
  screenshot (see "UI PARITY TRACK" above). Ask for the real screenshot if/when
  available; current text is a reasonable placeholder following the same real-content
  pattern as the other 3 (now-real) legal pages.
- **Ringtone preview** — Classic/Modern/Marimba all currently play the same device
  system-notification sound (`flutter_ringtone_player`) since no actual per-ringtone
  audio files exist. Ask the user for 3 real short audio clips if distinct previews
  are wanted.
- **Free tier's profile limit** — the other 5 plan tiers are locked (see above), but
  the Free tier's monthly profile-view cap was never confirmed. Ask before it matters
  (e.g. enforcing a real free-tier gate server-side).

*(Plan names and palette, previously listed here as unresolved, were locked in the
2026-07-10 UI-parity track — see above.)*

## Conventions when you do start building

- Folder layout per Flutter Rebuild doc §3 (`lib/core`, `lib/features/<feature>/{data,domain,presentation}`, `lib/shared`).
- Models via `freezed` + `json_serializable`; one per table plus DTOs where wire shape differs.
- All data access through repositories; presentation talks to Riverpod providers, never Supabase directly.
- Map Supabase errors to a sealed `Failure` hierarchy (see Rebuild doc §15).
- Theme from `AppColors`/`AppTextStyles`; widgets take `ThemeData` from context — no hardcoded colors.
