# CLAUDE.md — Love Me International (Flutter)

Read this first every session. It tells you what this project is, where the truth
lives, and the rules for working on it.

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

The next slice is **messages** (once that migration lands), or wiring
unmatch/block into the Matches tab UI. Reconcile plan names before touching
Subscription.

**Tooling note (Windows):** Flutter SDK **3.44.4 / Dart 3.9** lives at **`C:\flutter`**
(moved off `D:\app dev\tute\flutter` because the space in that path broke the
native-assets build hook). It is NOT on PATH; git is also not on the sandbox PATH but
IS at `C:\Program Files\Git\cmd`. Flutter needs git, so run everything in ONE command:
`$env:PATH="C:\Program Files\Git\cmd;"+$env:PATH; Set-Location "d:\app dev paid pro\loveme\love_me"; & "C:\flutter\bin\flutter.bat" <cmd>`
(git safe.directory already configured for the SDK). Windows-desktop build needs a VS
C++ workload we don't have — irrelevant; target is Android/web. Icons use
`lucide_icons_flutter` (the old `lucide_icons` is incompatible with Flutter 3.44).

**Locked:** palette = pink `#E6287A` + gold `#FFB800` (Roboto, 448px max width).
Plan-name conflict remains deferred (placeholder tiers in Phase 3).

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

- **Plan names** conflict: Backend doc = Premium/VIP/Elite; roadmap = Free/Basic+/Gold/
  Platinum/Premium Elite/VIP Elite. Resolve before SubscriptionScreen.
- **Palette** drift between docs. README/target uses pink `#E6287A` + gold `#FFB800`,
  Roboto, 448px max-width. Confirm one canonical `AppColors` set before theming.

## Conventions when you do start building

- Folder layout per Flutter Rebuild doc §3 (`lib/core`, `lib/features/<feature>/{data,domain,presentation}`, `lib/shared`).
- Models via `freezed` + `json_serializable`; one per table plus DTOs where wire shape differs.
- All data access through repositories; presentation talks to Riverpod providers, never Supabase directly.
- Map Supabase errors to a sealed `Failure` hierarchy (see Rebuild doc §15).
- Theme from `AppColors`/`AppTextStyles`; widgets take `ThemeData` from context — no hardcoded colors.
