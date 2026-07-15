# Love Me International — Schema Verification: Response

**To:** Flutter (client) team
**From:** Backend team
**Date:** 2026-07-15
**Project ref:** `tamlbnmihdcjiptbezjm`
**Status:** 🟢 Answered with the actual migration SQL, as requested. One real
bug found and fixed while checking. `FRONTEND_INTEGRATION_GUIDE.md`'s
"Next Steps" section is confirmed stale — see §5.2.

Good questions to ask before writing client code against a prose doc.
Answering all 5 sections below with the exact SQL, not paraphrased.

---

## 1. `profiles` table

### 1.1 The disputed columns are real and live

All of `photo_verification`, `is_suspended`/`suspension_reason`/
`suspended_at`/`policy_violations`, `profiles_viewed_count`/
`profiles_viewed_reset_at`, and all 4 `notify_safety_*` columns are live —
**they were in the original `001_auth_profiles.sql`, not added later and
not aspirational.** `migration_001.md` (your source) appears to be a
partial/outdated transcription of that file. Full current column list:

```sql
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  -- identity
  name text not null default '',
  gender text check (gender in ('male', 'female')),
  orientation text,
  interested_in text,
  birthday date,
  marital_status text,
  relationship_goal text,
  hobbies text[] not null default '{}',

  -- location
  city text not null default '',
  country text not null default '',
  location_lat double precision check (location_lat between -90 and 90),
  location_lng double precision check (location_lng between -180 and 180),
  location_accuracy_m double precision check (location_accuracy_m >= 0),
  distance_preference_km integer not null default 50 check (distance_preference_km > 0),

  -- media / verification
  photo_url text,
  is_verified boolean not null default false,
  photo_verification jsonb not null default '{}'::jsonb,
  ringtone text not null default '',

  -- profile lifecycle
  profile_complete boolean not null default false,

  -- discovery limits
  profiles_viewed_count integer not null default 0 check (profiles_viewed_count >= 0),
  profiles_viewed_reset_at timestamptz not null default now(),

  -- trust & safety
  is_suspended boolean not null default false,
  suspension_reason text,
  suspended_at timestamptz,
  policy_violations integer not null default 0 check (policy_violations >= 0),

  -- safety notification preferences
  notify_safety_email boolean not null default true,
  notify_safety_push boolean not null default true,
  notify_safety_on_triaged boolean not null default true,
  notify_safety_on_resolved boolean not null default true,

  -- monetization
  is_premium boolean not null default false,
  premium_until timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_user_id_key unique (user_id),
  constraint profiles_suspension_reason_requires_suspended
    check (is_suspended or suspension_reason is null)
);
```

Plus, from `036_extended_profile_fields.sql` (2026-07-14, likely after
your `migration_001.md` was written): `bio text` (check: `char_length(bio)
<= 500`), `interests text[] not null default '{}'`, `occupation text`.

**Full current column list, for your model reconciliation:** `id`,
`user_id`, `name`, `gender`, `orientation`, `interested_in`, `birthday`,
`marital_status`, `relationship_goal`, `hobbies`, `city`, `country`,
`location_lat`, `location_lng`, `location_accuracy_m`,
`distance_preference_km`, `photo_url`, `is_verified`,
`photo_verification`, `ringtone`, `profile_complete`,
`profiles_viewed_count`, `profiles_viewed_reset_at`, `is_suspended`,
`suspension_reason`, `suspended_at`, `policy_violations`,
`notify_safety_email`, `notify_safety_push`, `notify_safety_on_triaged`,
`notify_safety_on_resolved`, `bio`, `interests`, `occupation`,
`is_premium`, `premium_until`, `plan_id` (added 2026-07-15, see the
subscriptions doc if you haven't seen it), `created_at`, `updated_at`.

### 1.2 Answers to your 5 questions

1. **Live, not aspirational.** See §1.1 — they were in the founding
   migration.
2. **SQL sent above** — this is the exact, current `create table` (with
   the `036` additions noted separately since they came from a later
   migration, not the original).
3. **No RPC exists for `profiles_viewed_count`/`profiles_viewed_reset_at`
   today.** These two columns are dead weight right now — the actual live
   view-quota enforcement is `get_view_quota()`/`record_profile_view()`
   (both `security definer`, added/replaced in `032_quota_rpcs.sql`),
   which track quota via **counting rows in `profile_views`**, not via
   these two profile columns. Nothing reads or writes
   `profiles_viewed_count`/`profiles_viewed_reset_at` anywhere in the
   migration history. **Do not build client code that reads/writes these
   two columns directly** — use `get_view_quota()` and
   `record_profile_view()` instead; those are the real, live source of
   truth. We should probably drop these two columns as dead schema in a
   follow-up — flagging that as a cleanup item, not asking you to do
   anything about it now.
4. **Separate, profile-scoped toggles — not a replacement for
   `notification_preferences`.** `notification_preferences` (from
   `007_notifications.sql`) covers `like_notifications`,
   `match_notifications`, `message_notifications`, `call_notifications`,
   `profile_view_notifications` — day-to-day social notification types.
   The `notify_safety_*` columns on `profiles` are specifically for
   safety-report status updates (a report you filed getting triaged/
   resolved) — a different notification domain entirely, which is why
   they live on `profiles` rather than as more rows in
   `notification_preferences`. **Neither table currently has code that
   reads `notify_safety_*` to actually gate a send** — same "schema
   exists, not wired to a dispatcher" situation as `moderate-image`'s
   classifier (see the A-TIER response doc if you have it). Treat these 4
   columns as reserved/future for now.
5. **No admin flow sets these yet, and the client should NOT build UI for
   `is_suspended` yet.** There is no admin tooling, RPC, or trigger
   anywhere in the migration history that ever sets `is_suspended`,
   `suspension_reason`, `suspended_at`, or increments
   `policy_violations` — they're schema-only, same category as the
   `notify_safety_*` columns. **This is worth flagging back to us as a
   real gap**, not something to build against speculatively: if account
   suspension is meant to be part of trust & safety enforcement, that
   needs its own requirements pass (probably paired with the
   `moderate-image`/`content_flags` pipeline) before there's anything
   real for a "suspended account" screen to check.

---

## 2. `active_sessions` table

### 2.1 Current schema is yours, not your "earlier docs" version

```sql
create table if not exists public.active_sessions (
  user_id uuid not null references auth.users(id) on delete cascade,
  session_token uuid not null,
  device_label text,
  user_agent text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),  -- added by 024, see below

  constraint active_sessions_pkey primary key (user_id, session_token)
);
```

`user_id`/`session_token`/`device_label`/`user_agent`/`last_seen_at` —
your integration guide's version — is what's actually live.
`label`/`os`/`last_active`/`is_current` (your "migration 001" doc) does
not exist and never has; that doc was wrong, not the guide.

**Real bug found and fixed while answering this:** `active_sessions` had
an `active_sessions_set_updated_at` trigger (from `011_triggers_core.sql`)
firing `new.updated_at := now()` on every `UPDATE` since that trigger was
created — but the table had no `updated_at` column until just now.
**Every `UPDATE` to `active_sessions` (including your `session_service.dart`'s
`updateSessionHeartbeat()`) has been silently erroring.**
`024_active_sessions_updated_at_fix.sql` adds the missing column; this is
now fixed and live. If your heartbeat calls have been failing and getting
swallowed by a try/catch (your example code does exactly this — `catch (e)
{ print(...) }`), that's why: check your logs around that print statement
if you've tested this flow.

### 2.2 Answers to your 4 questions

1. **Yours is correct and live** — SQL above. `active_sessions_pkey` is
   `(user_id, session_token)`, not a surrogate `id`.
2. **Client-generated (`uuid.v4()`), not tied to the Supabase auth
   session/refresh token — this is intentional, not redundant.**
   `session_token` identifies **a device-session row for the multi-device
   tracking/single-device-enforcement feature**, which is a distinct
   concept from Supabase's own auth session (which handles actual
   request authentication and already rotates independently via refresh
   tokens). If `session_token` were tied to the Supabase refresh token,
   every silent token refresh would need a matching `active_sessions` row
   update just to keep the row's identity valid, which is unnecessary
   coupling. A per-login random UUID that lives for the lifetime of "this
   app install's login" is the right primitive here — keep the
   client-generated approach.
3. **The constraint is exactly `(user_id, session_token)`** — that's the
   primary key, not a separate unique index. **Inserting a new session
   for the same device does NOT update in place** — every `createSession()`
   call with a fresh `uuid.v4()` inserts a brand new row, since the PK
   includes `session_token` which is different every time. This means
   **your `createSession()` as written creates a new row on every app
   launch/token refresh that calls it**, never reusing an existing device
   row — worth checking whether that's the actual intended behavior,
   since "one row per device" and "one row per login event" are different
   models and the table as designed supports either, depending on when
   your client calls `createSession()`.
4. **No trigger/RPC enforces single-device for free-tier users — this
   does not exist anywhere in the migration history.** If this is a real
   business rule, the client currently has to check
   `getActiveSessions(userId)` and revoke (delete) older rows manually
   before/after creating a new one — nothing server-side stops a free
   user from accumulating unlimited concurrent session rows today. Flag
   to us if you want this enforced server-side (e.g. a trigger that
   deletes older sessions past some count for non-premium users) rather
   than trusting client-side enforcement, which a modified client could
   just skip.

---

## 3. `fcm_tokens` table

### 3.1 Current schema

```sql
create table if not exists public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text,                              -- added by 020
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),  -- added by 020

  constraint fcm_tokens_user_id_token_key unique (user_id, token)  -- changed by 025, see below
);
```

### 3.2 Answers to your 4 questions

1. **`updated_at`** tracks last-updated — added in `020_fcm_tokens_fix.sql`
   (2026-07-13) specifically because `created_at` alone can't tell you
   that, matching your own reasoning. It's bumped automatically by the
   `set_updated_at` trigger (`011_triggers_core.sql`) on every `UPDATE`
   (e.g. re-upserting the same token on refresh) — no client action
   needed beyond upserting normally.
2. **Changed to `(user_id, token)`, not global `token` — already fixed,
   and this is a breaking change for your current upsert code.**
   `025_fcm_tokens_composite_unique.sql` (2026-07-13) dropped the global
   `unique(token)` constraint and replaced it with `unique(user_id,
   token)`, for exactly the reason you flagged: a global-unique `token`
   meant a reissued/reused token could silently reassign an existing
   row to a different user. **This requires a client change: your
   `registerFcmToken()`'s `onConflict: 'token'` must become `onConflict:
   'user_id,token'`, or every call will error** (Postgres requires the
   `onConflict` target to name an actual constraint, and the old one no
   longer exists). Please confirm this shipped on your side — this was
   flagged as a coordinated change in the migration's own comment, and we
   want to make sure it didn't slip through.
3. **Confirmed explicitly: RLS is `to authenticated` only, owner-scoped,
   all operations.**
   ```sql
   create policy "Users manage own fcm token"
     on public.fcm_tokens
     for all
     to authenticated
     using (auth.uid() = user_id)
     with check (auth.uid() = user_id);
   ```
   Note this was **tightened** from the original `to public` scoping in
   `002_auth_profiles_rls.sql` — `021_fcm_tokens_rls_fix.sql` (2026-07-11)
   restricted it to `authenticated` for defense-in-depth (an anon request
   was already blocked by `auth.uid() = user_id` failing for a null
   `auth.uid()`, but this closes the gap explicitly).
4. **Table is live; the dispatcher is also live, not just the table.**
   `functions/send-fcm-push/index.ts` exists and is wired via a trigger:
   `023_notification_dispatch_trigger.sql` fires on `notifications`
   insert → enqueues to `notification_queue`
   (`011_triggers_core.sql`'s `enqueue_notification`) → dispatched to
   `send-fcm-push`, which reads `fcm_tokens`, checks
   `notification_preferences`, and calls the real Firebase Cloud
   Messaging HTTP v1 API (with actual FCM service-account JWT signing,
   not stubbed). Both the table and dispatcher from your original
   push-notifications handoff are done and live — not just the table.

---

## 4. `user_presence` table

### 4.1 Current schema — confirmed exactly as your guide describes

```sql
create table if not exists public.user_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_online boolean not null default false,
  last_seen timestamptz not null default now()
);
```

### 4.2 Answers to your 3 questions

1. **Confirmed** — exact shape above, upserted on `user_id` (the primary
   key, so `onConflict: 'user_id'` in your example code is correct as
   written).
2. **No staleness sweep exists anywhere** — no cron, no scheduled
   function, nothing. `is_online` is purely whatever the client last
   wrote. **You correctly identified a real gap**: a client that
   crashes, loses connectivity, or gets killed by the OS without calling
   `setOffline()` will show that user as online indefinitely. This is a
   real product bug waiting to happen, not something already handled
   server-side — if you want this fixed, it needs a follow-up (either a
   `pg_cron` job comparing `last_seen` against a threshold, or deriving
   "online" client-side from `last_seen` recency instead of trusting the
   `is_online` boolean at all, which sidesteps needing a sweep).
3. **No existing recommendation in any migration/doc** — this hasn't been
   specified anywhere before. A reasonable starting point: heartbeat
   every 30–60s while the app is foregrounded (matches typical presence-
   system intervals elsewhere), call `setOffline()` from
   `AppLifecycleState.paused`/`detached`, and treat `last_seen` older than
   ~2x your heartbeat interval as effectively offline in the UI regardless
   of what `is_online` says, as a client-side safety net until (or unless)
   a server-side sweep exists. This is a recommendation, not something
   already built — happy to build the server-side sweep if you'd rather
   not carry that client-side workaround.

---

## 5. General / process questions

### 5.1 Source of truth going forward

Yes — **the `supabase/migrations/*.sql` files themselves are the only
real source of truth**, and this exchange is a good example of why: your
own "migration 001" doc and our integration guide disagreed with each
other and both turned out to be partially wrong relative to what's
actually deployed (your doc missed real columns; our guide's "Next Steps"
section, see below, was stale). We don't currently have a clean way to
give you direct read access to this repo, but we can commit to: **any
schema-affecting migration gets a corresponding update to
`FRONTEND_INTEGRATION_GUIDE.md` in the same round**, and going forward we
can send you the actual `.sql` diff alongside any future integration doc
rather than a prose re-description of it, exactly like this response did.
If you do get read access to this repo at some point, `supabase/migrations/`
in numeric order is the complete, authoritative history — every backend
response doc in this folder (`*_BACKEND_RESPONSE.md`) also cross-references
which migration numbers correspond to which features.

### 5.2 "Next Steps" section is stale — confirmed, nothing regressed

**You're right, we're wrong — that section is outdated, not current.**
Likes, matches, messages/chat, call logging, and all 5 storage buckets
are genuinely live (`003`–`006`, `009`–`010`, `015`–`016`, `026`–`028`),
well before your 2026-07-06–07-10 usage window. `FRONTEND_INTEGRATION_GUIDE.md`
appears to be an early-stage doc (written before those migrations landed)
that never got its "Next Steps" section updated as more was shipped —
classic doc-drift, not a regression or a rollback. We'll update that
doc's "Next Steps" section to reflect current reality rather than leave it
misleading. For anything beyond the 4 tables in this response, treat our
various `*_BACKEND_RESPONSE.md`/`*_BACKEND_STATUS.md` docs (safety/trust,
discovery ranking, chat/typing, verification, subscriptions) as current —
those were all written after actually checking live migration state,
unlike this older guide.

### 5.3 Google Sign-In — cannot confirm from here, needs a direct check

**We can't fully answer this from the repo alone.** `supabase/config.toml`
(the file that would define local/pushed auth provider config) has no
`[auth.external.google]` block at all — only `[auth.external.apple]` is
templated — which strongly suggests Google OAuth has not been configured
via this repo's config. However, the Supabase CLI doesn't expose a way to
read back the *live* dashboard auth-provider settings (client ID/secret,
redirect URLs) from here, so we can't fully rule out that someone
configured it directly in the Supabase Dashboard outside of this repo's
`config.toml`. **Recommend treating `signInWithGoogle()` as NOT ready
until someone with Dashboard access confirms Authentication → Providers →
Google is enabled with a real client ID** — do not wire client-side Google
Sign-In UI against this yet. We'll check the dashboard directly and follow
up rather than have you guess.

---

## 6. Summary

- **§1 (profiles):** All disputed columns are real and live, not
  aspirational — your integration guide was right, your other doc was
  incomplete. `profiles_viewed_count`/`profiles_viewed_reset_at` are dead
  columns (use `get_view_quota()`/`record_profile_view()` instead).
  `notify_safety_*` and `is_suspended`/etc. are schema-only, nothing
  reads/writes them yet — don't build UI against them.
- **§2 (active_sessions):** Your guide's column set is correct. Found and
  fixed a real bug: heartbeat updates were silently erroring due to a
  missing `updated_at` column (now fixed, `024`). No single-device
  enforcement exists server-side yet.
- **§3 (fcm_tokens):** Your guide is correct, but flagging a **required
  client change**: the unique constraint changed from `token` to
  `(user_id, token)` — confirm your `onConflict` target was updated to
  match, or every upsert errors. Dispatcher is fully live, not just the
  table.
- **§4 (user_presence):** Shape confirmed as documented. No staleness
  sweep exists — real gap, your instinct was correct.
- **§5:** Migrations folder is the real source of truth going forward.
  "Next Steps" section was stale, nothing regressed — all the tables you
  listed as live really are live. Google Sign-In config can't be confirmed
  from this repo; needs a direct Dashboard check before you wire client
  code against it.