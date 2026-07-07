# Love Me International — Dating App (Flutter)

A mobile-first global dating application. This repository is the **Flutter rebuild** of an
existing React 18 + Vite + TypeScript web app (delivered inside an Android WebView). The
Flutter client consumes the **same Supabase (Lovable Cloud) backend** — no server work is
re-implemented here; the app is purely a client.

- **App name:** Love Me International
- **Domain:** Online dating / social discovery (adults 18+)
- **Target platforms:** Android (min SDK 24), iOS 13+ (future)
- **Target stack:** Flutter 3.24+ · Dart 3.5+ · `supabase_flutter`
- **Backend (unchanged):** Supabase — Postgres 15, Auth, Storage, Realtime, 29 Deno Edge Functions
- **Design language:** Pink `#E6287A` + Gold `#FFB800`, Roboto, 448px max-width mobile container

> ⚠️ **Current repo state:** This is a fresh `flutter create` scaffold. `lib/` contains only
> the default `main.dart`, and `pubspec.yaml` has **none** of the documented dependencies yet.
> All architecture below is the *target* per the specs in `app doctumant/`. See
> [developer.log](developer.log) for what has actually been built.

---

## 1. Source of truth (the spec bundle)

Everything about this app is specified in [`app doctumant/`](app%20doctumant/):

| File | What it is |
| --- | --- |
| `app.docx` (actually Markdown) | **Product roadmap** — 28 phases, feature list, plan tiers, timeline |
| `LoveMe-Backend-API-Documentation.docx` | **Backend reference** — 30 tables, RLS, RPCs, 29 Edge Functions, storage, realtime |
| `LoveMe-Flutter-Rebuild-Documentation.docx` | **Engineering blueprint** — Clean Architecture, folder structure, pubspec, providers, roadmap |
| `LoveMe-UI-Documentation.docx` | **UI handover** — design system, 23 screens, components, states, validation, a11y |
| `screens-json/00_INDEX.json` | Design tokens + index of 23 screen specs |
| `screens-json/01..23_*.json` | Per-screen build specs (components, apiCalls, state, validation, states, tokens) |

> The three `.docx` files are real Word documents. `app.docx` is **Markdown misnamed as
> `.docx`** — open it as text, not in Word.

---

## 2. Architecture

Feature-first **Clean Architecture**, three layers per feature plus a shared `core/`:

```
Presentation (Screens · Widgets · Riverpod providers)
        │
Domain       (Models · UseCases · Repository interfaces)   ← pure Dart, testable
        │
Data         (Repository impls · Supabase data sources · cache)
        │
Core         (theme · router · env · errors · utils)
```

Rules: presentation never touches Supabase directly (always via a repository); the domain
layer is pure Dart (no Flutter/plugins); the data layer holds all Supabase/REST code.

### Target folder structure (`lib/`)

```
lib/
├── main.dart · app.dart · bootstrap.dart
├── core/            config · constants · theme · router · network · storage · errors · utils · permissions
├── features/        auth · onboarding · discover · likes · messages · chat · explore · profile ·
│                    subscription · notifications · settings · devices · safety · calls ·
│                    delete_account · legal   (each: data/ domain/ presentation/)
├── shared/          widgets · models · services
└── l10n/            arb files
```

---

## 3. Technology stack

| Concern | Choice |
| --- | --- |
| State / DI | Riverpod 2 (`flutter_riverpod`, `riverpod_annotation`, `hooks_riverpod`) |
| Routing | `go_router` 14+ (ShellRoute for the 5 tabs, auth + profile-complete guards) |
| Backend SDK | `supabase_flutter` |
| Networking (3rd-party) | `dio` + interceptors; `connectivity_plus` |
| Local storage | `shared_preferences`, `flutter_secure_storage`, `hive_flutter` (offline feed cache) |
| Auth | Supabase email/password + `google_sign_in` + `sign_in_with_apple` |
| Push | `firebase_messaging` + `flutter_local_notifications` (Web Push is dropped) |
| Media | `image_picker`, `image_cropper`, `cached_network_image`, `record`, `just_audio`, `camera` |
| Calls | `flutter_webrtc` (Supabase Realtime as signalling) |
| Location | `geolocator`, `geocoding`, `permission_handler` |
| Payments | `webview_flutter` + provider SDKs; secrets stay server-side in Edge Functions |
| Models | `freezed` + `json_serializable` |
| Analytics | `firebase_analytics`, `firebase_crashlytics`, `sentry_flutter` (optional) |

Full dependency list is in the Flutter Rebuild doc §5.

---

## 4. Screens (23 routes, 5 tabs)

Tabs share an `AppShell` (AppHeader + BottomNav): **Discover · Likes · Messages · Explore · Profile**.

| Route | Screen | Access |
| --- | --- | --- |
| `/auth` | AuthScreen | Public |
| `/email-verified` | EmailVerifiedScreen | Public |
| `/reset-password` | ResetPasswordScreen | Public |
| `/profile-setup` | ProfileSetupScreen (4-step wizard) | Auth |
| `/` | DiscoverScreen (tab) | Auth |
| `/likes` | LikesScreen (tab) | Auth |
| `/messages` | MessagesScreen (tab) | Auth |
| `/explore` | ExploreScreen (tab) | Auth |
| `/profile` | ProfileScreen (tab) | Auth |
| `/chat/:id` | ChatScreen | Auth |
| `/notifications` | NotificationsScreen | Auth |
| `/settings` | SettingsScreen | Auth |
| `/devices` | DevicesScreen | Auth |
| `/subscription` | SubscriptionScreen | Auth |
| `/safety-reports` | SafetyReportsScreen | Auth |
| `/delete-account` | DeleteAccountScreen | Auth |
| `/privacy-policy`, `/terms`, `/refund-policy`, `/child-safety` | Legal screens | Public/Auth |
| `/admin/diagnostics` | AdminDiagnosticsScreen (`has_role('admin')` gate) | Admin |
| `*` | NotFoundScreen | Any |

Per-screen build specs (components, API calls, providers, validation, all UI states) live in
[`app doctumant/screens-json/`](app%20doctumant/screens-json/).

---

## 5. Backend at a glance (do not re-implement)

- **Postgres 15**, RLS on every table. ~30 tables: `profiles` (37 cols), `likes`, `passes`,
  `matches`, `messages`, `message_reactions`, `notifications`, `calls`, `subscriptions`,
  `payment_events`, `wise_payment_requests`, `reports`, `blocked_users`, `user_roles`,
  presence/session/push/email infra tables. See Backend doc §4.
- **RBAC** via `user_roles` + `has_role(uuid, app_role)` SECURITY DEFINER (`admin` / `moderator` / `user`).
- **Key RPCs:** `get_conversations`, `record_profile_view`, `can_send_message`, `can_send_like`,
  `has_active_premium`, `has_role`, `get_country_counts`, `get_my_private_profile`, `generate_receipt_number`.
- **29 Edge Functions** for payments (Paystack/PayPal/Checkout.com/Flutterwave/Wise/IAP),
  moderation (`moderate-image`, `verify-identity`, `verify-profile-photo`), push, email queue,
  account deletion, subscription expiry.
- **Storage buckets:** `avatars` (public), `chat-files`, `chat-images`, `chat-file-thumbs`,
  `voice-messages`, `wise-proofs`, `email-assets`.
- **Realtime channels:** `messages`, `notifications`, `calls`, `user_presence`, `active_sessions`.
- **Triggers:** like→match, message→notification, notification→FCM push, subscription tamper guards.

---

## 6. Business rules (free tier caps)

- Age gate **18+** (birthday required; enforced client-side + DB trigger).
- Likes: **50 / 24h** free (`can_send_like`).
- Profile views: **50 / month** free (`record_profile_view`).
- Free users can only message **matches**; premium unlocks direct message + "who liked you".
- Mandatory NSFW moderation (`moderate-image`) before any image commit.
- Single-device session for free users (`active_sessions` + realtime sign-out).
- Data retention: 90 days inactive → automatic purge.

> ⚠️ **Plan-name conflict to resolve:** the Backend doc uses **Premium / VIP / Elite**; the
> product roadmap (`app.docx`) uses **Free / Basic+ / Gold / Platinum / Premium Elite / VIP Elite**.
> The `subscriptions` table stores `plan_name` as free text, so this must be reconciled before
> building the Subscription screen. See [developer.log](developer.log).

---

## 7. Payments

Client never handles secret keys — all sensitive calls go through Edge Functions.

| Provider | Client | Server function(s) |
| --- | --- | --- |
| Paystack (M-PESA) | `webview_flutter` / `flutter_paystack` | `paystack-checkout`, `paystack-webhook` |
| PayPal (card) | WebView approval URL | `paypal-checkout`, `paypal-webhook` |
| Flutterwave | WebView | `verify-flutterwave-payment` |
| Checkout.com | token charge | `checkout-com`, `checkout-com-webhook` |
| Wise (manual) | upload proof image | `verify-receipt-upload`, `wise-verify-ai`, `wise-admin` |
| Google/Apple IAP | `in_app_purchase` | `verify-purchase` |

---

## 8. Environment / secrets

Client vars via `--dart-define-from-file`:

```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable_anon_key>
GOOGLE_WEB_CLIENT_ID=<oauth-client>.apps.googleusercontent.com
PAYPAL_CLIENT_ID=<public>       PAYSTACK_PUBLIC_KEY=pk_live_...
FLUTTERWAVE_PUBLIC_KEY=FLWPUBK-...   SENTRY_DSN=...   APP_ENV=prod
```

Build: `flutter build apk --dart-define-from-file=.env.prod`

**Server-only secrets stay in Supabase — never ship them in the app:** all `*_SECRET_KEY`,
`FIREBASE_SERVICE_ACCOUNT`, `GOOGLE_SERVICE_ACCOUNT_JSON`, `LOVABLE_API_KEY`,
`SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVER_KEY`.

Three flavors: **dev / staging / prod** (own Supabase ref, Firebase project, bundle id
`com.loveme.international[.dev|.staging]`, `.env` file).

---

## 9. Getting started

```bash
flutter pub get
flutter run --dart-define-from-file=.env.dev
```

(Requires `.env.dev` with the client vars above, plus `google-services.json` /
`GoogleService-Info.plist` for Firebase, and a configured Supabase project.)

---

## 10. Build roadmap (~18 weeks, 2 engineers)

| Phase | Deliverable |
| --- | --- |
| 0. Setup | Repo, flavors, Firebase/Supabase config, theme, folder scaffold, CI |
| 1. Auth & Onboarding | Auth, ProfileSetup wizard, email verify, reset, single-device |
| 2. Shell + Discover | AppShell, BottomNav, Discover with filters, location, pagination |
| 3. Likes & Matches | Likes tabs, match celebration, gating |
| 4. Chat & Messages | Realtime chat, reactions, images, voice notes |
| 5. Explore + Profile | Explore grid, Profile, EditProfile |
| 6. Subscription & Payments | Plans, Paystack/PayPal/Wise/Flutterwave, receipts |
| 7. Calls | `flutter_webrtc`, signalling, IncomingCall |
| 8. Notifications & Push | FCM, in-app feed, ringtones, prefs |
| 9. Safety & Admin | Reports, blocks, delete account, admin diagnostics |
| 10. Polish & Store | A11y, animations, Crashlytics, store assets |

---

## 11. Related files

- [CLAUDE.md](CLAUDE.md) — context for AI assistant sessions (read first)
- [developer.log](developer.log) — running build journal (updated as work happens)
