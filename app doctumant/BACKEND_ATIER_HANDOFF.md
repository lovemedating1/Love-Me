# Love Me International — A-TIER Backend Requirements

**Date:** 2026-07-14
**From:** Flutter client team
**Purpose:** Everything Supabase (Postgres + RLS + RPCs + Edge Functions)
needs to build so the **already-built** client-side safety/quota/deletion/
moderation-status UI can go live. The client is done and merged (see
developer.log 2026-07-14); this doc is the server-side contract it's written
against. This is the **A-TIER** pass of the launch tier list (see CLAUDE.md
"LAUNCH TIER LIST" and developer.log 2026-07-14) — safety/trust blockers.
Subscription/payments are explicitly **out of scope** here (final tier,
tackled separately).

**Project ref:** `tamlbnmihdcjiptbezjm`

---

## 0. TL;DR — the 5 things you need to build

| # | Item | Type | Blocker? |
|---|---|---|---|
| 1 | `reports` table + RLS (insert-own, select-own) | Schema + RLS | **Yes** |
| 2 | `blocked_users` table + RLS (insert/select/delete-own) + Discover/matching filtering | Schema + RLS + query change | **Yes** |
| 3 | `delete-account` Edge Function (service-role account teardown) | Edge Function | **Yes** |
| 4 | Quota RPCs: `can_send_like`, `get_like_quota`, `record_profile_view`, `get_view_quota` | RPCs | **Yes** |
| 5 | `moderate-image` Edge Function + `profile_photos.moderation_status` column + storage trigger | Schema + Edge Function + trigger | **Yes** |

All 5 are genuinely blocking — this is the safety/trust tier, not a nice-to-have
tier. Client-side UI, error handling, and graceful "not available yet"
fallbacks are **already built and merged** for every one of these; nothing
further is needed from the client once you ship the server side.

---

## 1. Reports (`reports` table)

### 1.1 Why

Users need to report other users for inappropriate photos, fake profiles,
harassment, spam/scam, or being underage. This is the single most-flagged
missing safety feature across every prior backend doc
(`BACKEND_REMAINING.md` [BE-5]).

### 1.2 Schema

```sql
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  reported_name text,               -- display-only convenience, client-supplied
  reason text not null check (reason in (
    'inappropriate_photos', 'fake_profile', 'harassment',
    'spam_or_scam', 'underage', 'other'
  )),
  description text,                 -- optional free-text, client caps at 500 chars
  status text not null default 'pending' check (status in ('pending', 'resolved', 'dismissed')),
  admin_response text,              -- filled in by whatever admin tooling you build
  created_at timestamptz not null default now()
);

create index reports_reporter_idx on public.reports(reporter_user_id);
create index reports_reported_idx on public.reports(reported_user_id);
```

### 1.3 RLS

```sql
alter table public.reports enable row level security;

-- Users can insert reports where they are the reporter.
create policy "insert own reports" on public.reports
  for insert with check (reporter_user_id = auth.uid());

-- Users can only see reports they submitted (not reports against them,
-- and not other users' reports).
create policy "select own reports" on public.reports
  for select using (reporter_user_id = auth.uid());

-- No client UPDATE/DELETE policy — status/admin_response are admin-only,
-- managed via the service role from whatever admin tooling you build.
```

### 1.4 Exact wire shape the client sends

`POST /rest/v1/reports`:
```json
{
  "reporter_user_id": "<uuid, auth.uid()>",
  "reported_user_id": "<uuid>",
  "reported_name": "Jane Doe",
  "reason": "inappropriate_photos",
  "description": "optional free text, omitted if empty",
  "status": "pending"
}
```

Client reads via `GET /rest/v1/reports?reporter_user_id=eq.<uuid>&order=created_at.desc`.

### 1.5 Client code already wired

- `lib/shared/models/safety_report.dart` — `SafetyReport`, `ReportReason` enum
  (6 values matching the `reason` check constraint exactly).
- `lib/shared/data/safety_repository.dart` — `SupabaseSafetyRepository.submitReport()`/`myReports()`.
- `lib/shared/widgets/report_user_sheet.dart` — the one shared report-submission
  bottom sheet (reason chips + optional description + "also block" checkbox),
  used from: Discover's "Report" chip, the chat safety modal's "Report & Block",
  and the profile-detail preview modal's report icon.
- `lib/features/safety/safety_reports_screen.dart` — "My Reports" history
  screen (already existed, now reads real data).

**Until this table exists**, `SupabaseSafetyRepository` catches Postgrest
`42P01`/`PGRST205` (relation/table not found) and throws
`SafetyFeatureUnavailableException`; the report sheet shows "Reporting isn't
available yet" and `safetyReportsProvider` falls back to an empty list rather
than an error screen. **No other client change is needed when you ship this**
— it starts working immediately.

---

## 2. Blocking (`blocked_users` table)

### 2.1 Why

This is distinct from the existing `matches.status = 'blocked'`
(`MatchRepository.block()`, migration 003/004 — already live): that only
covers blocking someone you were matched with, and is scoped to the match
row. `blocked_users` is a standalone block that also works from Discover (a
card you were never matched with) and persists even if the match is later
deleted/unmatched.

### 2.2 Schema

```sql
create table public.blocked_users (
  id uuid primary key default gen_random_uuid(),
  blocker_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_name text,                -- display-only convenience, client-supplied
  created_at timestamptz not null default now(),
  unique (blocker_user_id, blocked_user_id)
);

create index blocked_users_blocker_idx on public.blocked_users(blocker_user_id);
```

### 2.3 RLS

```sql
alter table public.blocked_users enable row level security;

create policy "insert own blocks" on public.blocked_users
  for insert with check (blocker_user_id = auth.uid());

create policy "select own blocks" on public.blocked_users
  for select using (blocker_user_id = auth.uid());

create policy "delete own blocks" on public.blocked_users
  for delete using (blocker_user_id = auth.uid());
```

### 2.4 Wire shape

Insert: `{"blocker_user_id": "<uuid>", "blocked_user_id": "<uuid>", "blocked_name": "Jane Doe"}`.
Unblock: `DELETE /rest/v1/blocked_users?blocker_user_id=eq.<uuid>&blocked_user_id=eq.<uuid>`.
Client treats a `23505` (already blocked) unique-violation on insert as success.

### 2.5 Open question for backend: filtering blocked users out of Discover/likes/matches

The client's `blockedUsersProvider` exists and the "Blocked Users" screen
(Profile → Blocked Users) works standalone, but **`discoverFeed()` does not
currently exclude blocked users** (`lib/shared/data/repositories.dart`,
`SupabaseProfileRepository.discoverFeed()`), and neither does `likedYou()`/
`matches()`. Recommended: once this table exists, either (a) add a Postgres
RLS policy or view that filters `profiles`/`likes`/`matches` results against
`blocked_users` server-side (preferred — can't be bypassed by a modified
client), or (b) confirm with the client team that filtering should happen
client-side against `blockedUsersProvider` instead. **Flagging this now so
it doesn't get lost — please advise which approach you want and we'll wire
the client side to match.**

### 2.6 Client code already wired

- `lib/shared/models/blocked_user.dart` — `BlockedUser` model.
- `lib/shared/data/safety_repository.dart` — `blockUser()`/`unblockUser()`/
  `myBlockedUsers()`/`hasBlocked()`.
- `lib/features/safety/blocked_users_screen.dart` (NEW) — list + unblock,
  reachable from Profile → "Blocked Users" row.
- Chat safety modal's "Block" action and the report sheet's "also block"
  checkbox both call `blockUser()` for real now.

Same not-yet-live fallback as reports: `blockedUsersProvider` returns an
empty list (not an error) until this table exists.

---

## 3. Account deletion (`delete-account` Edge Function)

### 3.1 Why

The Delete Account screen (`lib/features/delete_account/delete_account_screen.dart`)
previously just waited 900ms and signed out locally — no data was ever
actually deleted. This is now wired to call a real Edge Function; **the
function itself doesn't exist yet**.

### 3.2 What the client calls

```dart
await Supabase.instance.client.functions.invoke('delete-account');
```

No body is sent — the function should resolve the caller from the request's
JWT (`auth.uid()` equivalent inside the function, via the service-role
client reading the caller's `Authorization` header). On success (2xx), the
client immediately calls its own `signOut()` teardown (clears local session,
presence, device registration, invalidates every cached provider). On a
non-2xx response the client surfaces a `FunctionException`; a 404
specifically shows "Account deletion isn't available yet — please contact
support" (i.e. safe to leave this unbuilt in a beta without breaking the
screen — it just won't work yet, no crash).

### 3.3 What the function needs to do (service-role, since RLS can't let a
user delete rows across tables they don't own, e.g. deleting a `matches` row
where they're `user2_id`)

1. Resolve the caller's `user_id` from the JWT.
2. Delete/anonymize, in dependency order (children before parents):
   - `profile_photos`, storage objects in `avatars`/`chat-images`/`chat-files`/
     `chat-file-thumbs`/`voice-messages` under the user's path prefix.
   - `messages` sent by the user (or anonymize `sender_id` if you'd rather
     keep the other participant's conversation history intact — your call,
     flag which you pick so the client can set expectations in the
     consequence-list copy on the delete screen).
   - `message_reads`, `message_reactions`, `conversations` (where the user
     is a participant and the other side is also gone, or just leave
     conversations orphaned — same call as above), `call_logs`.
   - `matches`, `likes`, `passes`, `profile_views`.
   - `notifications`, `notification_preferences`, `fcm_tokens`/`push_tokens`.
   - `active_sessions`, `user_presence`.
   - `reports`/`blocked_users` rows where the user is reporter/reported or
     blocker/blocked (once §1/§2 ship).
   - `profiles` row itself.
3. Finally, delete the `auth.users` row via the Admin API
   (`supabase.auth.admin.deleteUser(userId)`) — this is the step that
   requires the service-role key and can never happen from the client.

### 3.4 Client code already wired

- `lib/features/auth/auth_controller.dart` — `AuthController.deleteAccount()`
  (invokes the function, then reuses the exact same teardown path as
  `signOut()` — no separate/duplicate sign-out logic).
- `lib/features/delete_account/delete_account_screen.dart` — calls it,
  handles `FunctionException` (404 → "not available yet" messaging vs. any
  other status → generic retry messaging).

---

## 4. Quota-enforcement RPCs (free-tier caps)

### 4.1 Why

`AppConstants.dailyLikeCap = 50` and `AppConstants.monthlyFreeViewCap = 50`
have existed client-side as constants since Phase 1 but were **never
enforced anywhere** — free users have always had unlimited likes/views in
practice. This also blocked the Subscription screen's usage bars, which
previously would have needed fabricated numbers.

### 4.2 `can_send_like()` RPC — pre-flight check before a like insert

```sql
create or replace function public.can_send_like()
returns boolean
language plpgsql
security definer
as $$
declare
  is_premium boolean;
  likes_in_window int;
begin
  select coalesce(is_premium, false) into is_premium
  from public.profiles where user_id = auth.uid();

  if is_premium then
    return true;
  end if;

  select count(*) into likes_in_window
  from public.likes
  where from_user_id = auth.uid()
    and created_at > now() - interval '24 hours';

  return likes_in_window < 50; -- keep in sync with AppConstants.dailyLikeCap
end;
$$;

grant execute on function public.can_send_like() to authenticated;
```

Client calls this immediately before inserting into `likes`
(`lib/shared/data/swipe_repository.dart`, `SupabaseSwipeRepository.likeProfile()`).
If it returns `false`, the client throws `DailyLikeCapExceededException` and
shows an upgrade dialog instead of inserting. **If this RPC doesn't exist,
the client silently skips the check and behaves exactly as it does today**
(unlimited likes) — so this is safe to ship whenever ready, no urgency
beyond "sooner is better for the free-tier business model."

### 4.3 `get_like_quota()` RPC — for the Subscription screen's usage bar

```sql
create or replace function public.get_like_quota()
returns json
language plpgsql
security definer
as $$
declare
  is_premium boolean;
  likes_in_window int;
begin
  select coalesce(is_premium, false) into is_premium
  from public.profiles where user_id = auth.uid();

  if is_premium then
    return json_build_object('remaining', null); -- unlimited
  end if;

  select count(*) into likes_in_window
  from public.likes
  where from_user_id = auth.uid()
    and created_at > now() - interval '24 hours';

  return json_build_object('remaining', greatest(0, 50 - likes_in_window));
end;
$$;

grant execute on function public.get_like_quota() to authenticated;
```

Client reads `result['remaining']` (`lib/shared/data/swipe_repository.dart`,
`remainingLikesToday()`). A `null` remaining (or any error/missing RPC) means
"don't show a number" — the Subscription usage bar
(`lib/features/subscription/subscription_screen.dart`, `_usageCard`) shows
"Up to 50/period" instead of a fabricated count in that case.

### 4.4 `record_profile_view(viewed_user_id uuid)` RPC — atomic insert + quota check

```sql
create or replace function public.record_profile_view(viewed_user_id uuid)
returns json
language plpgsql
security definer
as $$
declare
  is_premium boolean;
  views_this_month int;
begin
  if viewed_user_id = auth.uid() then
    return json_build_object('allowed', true); -- no-op, viewing yourself
  end if;

  select coalesce(is_premium, false) into is_premium
  from public.profiles where user_id = auth.uid();

  if not is_premium then
    select count(*) into views_this_month
    from public.profile_views
    where viewer_user_id = auth.uid()
      and created_at > date_trunc('month', now());

    if views_this_month >= 50 then -- keep in sync with AppConstants.monthlyFreeViewCap
      return json_build_object('allowed', false);
    end if;
  end if;

  insert into public.profile_views (viewer_user_id, viewed_user_id)
  values (auth.uid(), viewed_user_id)
  on conflict do nothing; -- adjust if profile_views has no unique constraint to conflict on

  return json_build_object('allowed', true);
end;
$$;

grant execute on function public.record_profile_view(uuid) to authenticated;
```

Client calls this from `lib/shared/data/profile_view_repository.dart`,
`recordView()` — **prefers the RPC, but falls back to the old direct
best-effort insert if the RPC doesn't exist** (404/missing function), so
this is a zero-risk, backward-compatible ship whenever ready. When the RPC
returns `{"allowed": false}`, the client throws
`MonthlyViewCapExceededException` (not currently surfaced to the user
anywhere yet since it's silent/best-effort logging — flag if you want a UI
paywall added here too, symmetric with the like cap).

### 4.5 `get_view_quota()` RPC — same shape as `get_like_quota()`, monthly window

```sql
create or replace function public.get_view_quota()
returns json
language plpgsql
security definer
as $$
declare
  is_premium boolean;
  views_this_month int;
begin
  select coalesce(is_premium, false) into is_premium
  from public.profiles where user_id = auth.uid();

  if is_premium then
    return json_build_object('remaining', null);
  end if;

  select count(*) into views_this_month
  from public.profile_views
  where viewer_user_id = auth.uid()
    and created_at > date_trunc('month', now());

  return json_build_object('remaining', greatest(0, 50 - views_this_month));
end;
$$;

grant execute on function public.get_view_quota() to authenticated;
```

### 4.6 Client code already wired

- `lib/shared/data/swipe_repository.dart` — `DailyLikeCapExceededException`,
  `remainingLikesToday()`, pre-flight `can_send_like` call in `likeProfile()`.
- `lib/shared/data/profile_view_repository.dart` — `MonthlyViewCapExceededException`,
  `remainingViewsThisMonth()`, `record_profile_view` RPC call with fallback.
- `lib/shared/data/repositories.dart` — `remainingLikesTodayProvider`,
  `remainingViewsThisMonthProvider`.
- `lib/features/discover/discover_screen.dart` — like-cap-reached dialog
  (upgrade prompt) on `DailyLikeCapExceededException`.
- `lib/features/subscription/subscription_screen.dart` — `_usageCard`, real
  progress bars for likes/views (only shown for non-premium users).

---

## 5. Image moderation (`moderate-image` + `profile_photos.moderation_status`)

### 5.1 Why

This is the single most consistently-flagged item across every prior
backend doc (`BACKEND_REMAINING.md` [BE-5]/[BE-8],
`BACKEND_REQUIREMENTS_HANDOFF.md`) — **no NSFW/human-photo check exists
anywhere, client or server**. The client's on-device face detection
(`google_mlkit_face_detection`, `lib/core/media/photo_picker_service.dart`)
only rejects photos with *no detectable face* at pick-time — it is not a
substitute for real content moderation and was never meant to be (a person
could still upload an inappropriate photo that happens to contain a face).

### 5.2 Schema addition

```sql
alter table public.profile_photos
  add column moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected'));

create index profile_photos_moderation_idx on public.profile_photos(moderation_status);
```

**Important:** existing rows should be backfilled to `'approved'` (not
`'pending'`) when this migration runs, so already-live photos don't
suddenly disappear/get flagged:
```sql
update public.profile_photos set moderation_status = 'approved' where true;
-- then flip the column default to 'pending' for new rows going forward,
-- e.g. alter column moderation_status set default 'pending';
```

### 5.3 `moderate-image` Edge Function

Triggered on every new `profile_photos` insert (via a Postgres webhook/
`pg_net` trigger, or by having the client call it right after upload —
recommend the trigger approach so it can't be bypassed by a modified
client). Should:

1. Fetch the image from the `avatars` storage bucket.
2. Run it through an NSFW/content-safety classifier (your choice of
   provider — AWS Rekognition, Google Cloud Vision SafeSearch, Sightengine,
   etc. — out of scope for the client to prescribe).
3. `UPDATE profile_photos SET moderation_status = 'approved' | 'rejected' WHERE id = ...`.
4. Optionally insert a `notifications` row (`type` would need a new value,
   or reuse an existing generic one) so the user finds out their photo was
   rejected without having to reopen the Profile screen.

### 5.4 Client code already wired

- `lib/shared/models/profile_photo.dart` — `PhotoModerationStatus` enum
  (`pending`/`approved`/`rejected`), `ProfilePhoto.moderationStatus` field.
  **Defaults to `approved` when the column is absent from the JSON response**
  (`fromJson` treats a missing/unrecognized `moderation_status` as
  `approved`) — so this is fully backward-compatible; nothing breaks before
  you ship the column, and every existing photo keeps behaving exactly as
  it does today.
- `lib/features/profile/profile_screen.dart` — a small badge under the
  avatar ("Photo under review" / "Photo rejected — please update it") shown
  only when the primary photo's status isn't `approved`. Invisible today
  since every photo defaults to `approved`.

### 5.5 Open question for backend: should a `pending`/`rejected` photo be
usable elsewhere in the app (visible to other users in Discover, settable as
primary, etc.) while awaiting/failing moderation? Recommended: no — a
`rejected` photo should probably be excluded from `sync_primary_profile_photo`
and from whatever `discoverFeed()`/other-profile queries expose photos to
other users, until it's `approved`. This needs a server-side decision (RLS/
trigger logic), not just a client display change — **please advise and
we'll adjust the client's upload flow to match** (e.g. show a "your photo is
pending review, other users won't see it yet" message at upload time).

---

## 6. Summary for planning

None of these 5 items touch subscription/payments — that stays deliberately
out of scope until the final tier, per explicit instruction from the app
owner. All client-side work for this A-TIER pass is **done, merged, and
build-verified** (`flutter analyze` clean, `flutter test` green, `flutter
build apk --debug` succeeds) — every item above degrades gracefully to
today's exact behavior until you ship the corresponding server piece, so
there's no rush-risk in shipping these one at a time rather than all at once.
Recommended ship order given cross-dependencies: **§1 (reports) and §2
(blocking) first** (self-contained, no dependency on anything else), then
**§4 (quota RPCs)** (self-contained), then **§3 (account deletion)** (touches
the most tables, so benefits from §1/§2 already existing so the deletion
function has those tables to clean up too), then **§5 (image moderation)**
last (needs a third-party classifier integration decision, likely the
longest lead time).
