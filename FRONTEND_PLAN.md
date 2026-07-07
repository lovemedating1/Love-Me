# Love Me International — Front-End Build Plan (4 Phases)

**Goal:** Build the *complete* front end first — every screen, widget, and UI state —
driven by **mock/in-memory data only**. No Supabase calls. Backend integration is a
separate effort that comes *after* all four phases below are done.

**Why mock-first works:** all data access goes through repositories. In this plan the
repositories return fake data; in the backend phase we swap the fake data source for the
real `supabase_flutter` one — **screen and widget code does not change.**

**Locked decisions**
- Palette: **pink `#E6287A` + gold `#FFB800`**, Roboto, 448px max-width mobile container.
- Plan-name conflict (Subscription screen) is deferred; use placeholder tiers in Phase 3
  and reconcile with the user before backend wiring.

**Scope of "front end" (each phase):** build UI to the screen JSON specs, wire navigation,
implement all four states (loading / empty / error / success) with mock data, form
validation, animations. Out of scope until backend phase: real auth, real network calls,
FCM push, WebRTC calls, real payments.

---

## Phase 1 — Foundation & Design System

Everything the rest of the app stands on. No feature screens yet.

- [ ] Add front-end dependencies to `pubspec.yaml` (Riverpod, go_router, freezed,
      google_fonts/Roboto, cached_network_image, flutter_svg, shimmer, lucide_icons,
      flutter_form_builder + validators, intl, uuid). Defer backend/native-only packages
      (supabase_flutter, firebase_*, webrtc, geolocator, payment SDKs) to backend phase.
- [ ] Folder scaffold per Rebuild doc §3 (`lib/core`, `lib/features/*`, `lib/shared`).
- [ ] `core/theme`: `AppColors`, `AppTextStyles`, `AppGradients`, light + dark `ThemeData`.
- [ ] `core/constants`: `AppConstants`, `RoutePaths`.
- [ ] `core/router`: `go_router` config with all 23 routes + ShellRoute for 5 tabs +
      guard stubs (auth/profile-complete return mock values for now).
- [ ] `main.dart` / `app.dart` / `bootstrap.dart` wired to `MaterialApp.router`.
- [ ] Base reusable widgets: `AppShell`, `AppHeader`, `BottomNav`, `NavItem`,
      `OptimizedAvatar`, primary button/input styles, skeleton/shimmer, empty/error state
      widgets, toast helper.
- [ ] Mock-data layer: sample profiles, conversations, notifications JSON + a
      `MockRepository` pattern the feature phases will consume.

**Exit criteria:** app launches, shows the 5-tab shell with themed header/nav, can navigate
between empty placeholder screens; theme + typography match the design system.

---

## Phase 2 — Auth, Onboarding & Discover

The entry funnel and the primary tab.

- [ ] `01 AuthPage` — Sign In / Sign Up tabs, email/password, remember-me, Google button
      (UI only), forgot-password dialog, 18+ age gate, all states + validation.
- [ ] `02 EmailVerifiedPage`, `03 ResetPasswordPage`.
- [ ] `04 ProfileSetupPage` — 4-step wizard (basics, location, photos, about) with progress
      dots, per-step validation, photo-slot UI (mock upload), interests chips.
- [ ] `05 IndexShell` behaviors (trial banner, gates) as UI overlays.
- [ ] `06 DiscoverPage` — profile card stack, like/pass/super-like/message actions,
      `DiscoverFilters` bottom sheet (age/distance/gender/country), pull-to-refresh,
      infinite scroll, match celebration overlay, all four states — all on mock feed.

**Exit criteria:** full unauth → onboarding → Discover flow is walkable end-to-end with
mock data; filters, swipe, and match animation work visually.

---

## Phase 3 — Likes, Messages, Chat, Explore, Profile & Subscription

The core engaged-user surface (the remaining tabs + chat + monetization UI).

- [ ] `07 LikesPage` — 3 tabs (Liked You / You Liked / Matches), premium-gated blur,
      match celebration.
- [ ] `08 MessagesPage` — conversation list, search, swipe-to-delete, long-press sheet, states.
- [ ] `09 ExplorePage` — country flag chips + profile grid, per-country states.
- [ ] `10 ProfilePage` — banner, stats, settings rows, trial usage bars, edit-profile sheet.
- [ ] `11 ChatPage` — message bubbles (in/out), read receipts, reactions bar, image/voice
      message UI, composer (emoji/attach/mic/send), call icons (UI only), all states.
- [ ] `15 SubscriptionPage` — plan cards, coin packs, payment-method tabs (UI only),
      receipts list, success screen. (Placeholder plan tiers — flag names for user.)

**Exit criteria:** every primary tab and chat is fully built and navigable with mock data;
subscription screen renders all plans/methods visually.

---

## Phase 4 — Settings, Safety, Legal, Admin & Polish

The remaining screens plus the finishing pass.

- [ ] `12 NotificationsPage` — activity feed, mark-all-read, deep-link taps.
- [ ] `13 SettingsPage` — discovery/privacy/notifications/account/safety sections, save bar.
- [ ] `14 DevicesPage` — current device + other sessions (single-device UI).
- [ ] `20 SafetyReportsPage`, `BlockReportDialog`, `ReportCsaeDialog`.
- [ ] `21 DeleteAccountPage` — two-step confirm ("type DELETE").
- [ ] `16–19` Legal pages (Privacy, Terms, Refund, Child Safety) — Markdown/prose.
- [ ] `22 AdminDiagnosticsPage` — tabbed diagnostics (role-gated UI).
- [ ] `23 NotFoundPage`.
- [ ] Polish: dark-mode pass, animations/haptics, accessibility (labels, tap targets,
      contrast, reduced-motion), empty/error consistency, responsive 448px check.

**Exit criteria:** all 23 screens built; app is a complete, navigable, themed, mock-driven
front end ready for backend integration.

---

## After the 4 phases: Backend Integration (separate track)

Swap `MockRepository` implementations for real `supabase_flutter` data sources; add
supabase/firebase/webrtc/geolocator/payment packages; wire auth, realtime, storage, RPCs,
Edge Functions, push, calls, payments. Resolve plan-name + any remaining spec conflicts first.

---

## Execution rule

We do **one phase at a time**. After each phase: append a dated `developer.log` entry
(what changed, what was produced, timestamp, what's next), and update the "Current state"
in `CLAUDE.md`. Do not start the next phase until the user says go.
