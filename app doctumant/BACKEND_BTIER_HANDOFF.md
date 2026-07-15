# Love Me International — B-TIER Backend Requirements

**Date:** 2026-07-14
**From:** Flutter (client) team
**Purpose:** Everything Supabase (Postgres + RLS + RPCs) needs to build so
the **already-built** client-side discovery-ranking/Explore/extended-profile
UI can go from "functionally correct but unranked/client-computed" to "real
backend-driven." The client is done and merged (see developer.log
2026-07-14); this doc is the server-side contract it's written against.
This is the **B-TIER** pass of the launch tier list (see CLAUDE.md "LAUNCH
TIER LIST" and developer.log). Subscription/payments remain out of scope
(final tier). Two B-TIER items — the two-device Agora call test and the
push-notification "app fully closed" retest — are manual verification tasks
with no backend dependency and aren't covered by this doc.

**Project ref:** `tamlbnmihdcjiptbezjm`

**Important correction to prior docs:** `BACKEND_REMAINING.md` [BE-9] and
`FRONTEND_REMAINING.md` §2.1/§6 both describe Discover as "still 5 hardcoded
mock profiles." **That's stale.** As of the A-TIER blocking work
(`035_blocked_users_table_level_gating.sql`), `discoverFeed()` already
queries the real `profiles_discoverable` view — Discover has been showing
real candidate profiles for a while, just with **no ranking, geo-sort,
pagination, or daily cap** applied server-side. This doc is about closing
that ranking gap and the two genuinely-still-mock Explore pieces
(`byCountry()`/country counts), not about "making Discover real" from
scratch.

---

## 0. TL;DR — what you need to build

| # | Item | Type | Blocker? |
|---|---|---|---|
| 1 | `get_country_counts()` RPC | RPC | No — client has a working fallback |
| 2 | Real discovery ranking/pagination/daily-cap RPC (`get_discover_profiles`) | RPC | No — current plain query works, just unranked |
| 3 | `profiles.bio` / `profiles.interests` / `profiles.occupation` columns | Schema | No — client no-ops gracefully without them |
| 4 | (Optional, lower priority) PostGIS-backed distance instead of client-side Haversine | Schema/RPC | No |

None of these are hard blockers — every client change in this pass degrades
gracefully to its current (already-shipped, real-data) behavior if you don't
build the corresponding piece. This is a quality/completeness pass, not a
"feature is broken without this" pass, unlike A-TIER's safety items.

---

## 1. `get_country_counts()` RPC

### 1.1 Why

Explore's country grid needs a real per-country user count. Today the
client computes this itself: `SupabaseProfileRepository.countryCounts()`
(`lib/shared/data/repositories.dart`) first tries `rpc('get_country_counts')`,
and if that fails (doesn't exist yet), falls back to paging through
`profiles_discoverable` in batches of 1000 rows and counting client-side by
`country`. This works today — it's honest (only counts real discoverable
profiles, never fabricates a number) — but it's O(all profiles) client-side
work that a single aggregate query would do far more cheaply server-side.

### 1.2 Proposed RPC

```sql
create or replace function public.get_country_counts()
returns table(country text, count bigint)
language sql
security invoker
as $$
  select country, count(*) as count
  from public.profiles_discoverable
  where country is not null and country <> ''
  group by country
  order by count desc;
$$;

grant execute on function public.get_country_counts() to authenticated;
```

`security invoker` (not `definer`) is intentional — this should run under
the calling user's own `profiles_discoverable` view grants, so a blocked
user is correctly excluded from another user's country counts the same way
it's excluded from their Discover feed (consistent with the A-TIER blocking
work).

### 1.3 Wire shape the client expects

```json
[{"country": "Kenya", "count": 42}, {"country": "Nigeria", "count": 108}, ...]
```

Client code (`SupabaseProfileRepository.countryCounts()`) reads `country`/
`count` keys from each row exactly as above — no other shape accepted.

### 1.4 Client code already wired

- `lib/shared/data/repositories.dart` — `ProfileRepository.countryCounts()`
  interface method, `SupabaseProfileRepository.countryCounts()` RPC-first/
  client-fallback implementation, `countryCountsProvider`.
- `lib/features/explore/explore_screen.dart` — REWRITTEN to read
  `countryCountsProvider` instead of the old hardcoded `MockData.countries`
  (8 fake countries with fabricated counts like 1240/3180 — now deleted from
  `mock_data.dart`). Only countries with ≥1 real discoverable profile
  appear in the grid; no zero-padding.

**Nothing further needed from the client once this RPC ships** — same
provider, same call site, it'll just get real numbers back faster.

---

## 2. Real discovery ranking/pagination/daily-cap RPC

### 2.1 Why

`discoverFeed()` is real-data but not real-ranking: it's a plain `SELECT ...
ORDER BY created_at DESC LIMIT 100` against `profiles_discoverable`, with
distance filled in **client-side** (see §2.2) and age/gender/online/verified
filters applied **client-side** in `discoverFiltersProvider`. There's no
per-plan daily profile cap enforced here either (that's separate from the
A-TIER `can_send_like` quota — this would be a cap on how many *candidate
profiles* a free user can be shown per day/month, if that's still in scope
per the roadmap — confirm with product if this cap is still wanted, it
wasn't part of A-TIER's quota RPCs).

### 2.2 Distance — now computed client-side, not server-side

New: `lib/core/utils/geo_distance.dart` — a plain Haversine great-circle
calculation. `discoverFeed()`/`byCountry()` now call
`GeoDistance.betweenKm()` against the current user's own
`location_lat`/`location_lng` (real GPS captured at onboarding) vs. each
candidate's, filling in `Profile.distanceKm` for display. This was
previously always `null` for real profiles (only mock data had a hardcoded
distance) — the "X km away" chip on Discover cards and the distance-based
filter now work for any two users who've both captured a location.

**This is not sorting or filtering by distance** — just display + the
existing client-side `maxDistanceKm` filter. If real geo-ranking (nearest
first) or server-side distance filtering (don't even send back candidates
outside X km) is wanted, that needs PostGIS or an equivalent — see §4.

### 2.3 Proposed RPC (optional — replaces the plain query, not required)

If/when you want server-side ranking instead of the client's plain
newest-first query:

```sql
create or replace function public.get_discover_profiles(
  p_limit int default 100,
  p_offset int default 0
)
returns setof public.profiles_discoverable
language sql
security invoker
as $$
  select * from public.profiles_discoverable
  order by created_at desc
  limit p_limit offset p_offset;
$$;

grant execute on function public.get_discover_profiles(int, int) to authenticated;
```

This is intentionally a thin wrapper matching today's client query exactly
— a real ranking algorithm (distance-weighted, activity-weighted, premium
boost, etc.) is a product decision, not something this doc prescribes.
**Confirm with product whether real ranking is even in scope for this
release** before building anything beyond pagination — the client's
current newest-first order may be an acceptable v1.

### 2.4 Client code already wired

- `lib/shared/data/repositories.dart` — `discoverFeed()`'s doc comment
  explicitly notes "still no server-side ranking RPC" and describes exactly
  what would need to change (swap the plain `.from().select()` call for an
  `rpc()` call) if/when this ships. No structural client change needed
  beyond that single call-site swap, same pattern as A-TIER's
  `profiles_discoverable` migration.

---

## 3. Extended profile columns: `bio`, `interests`, `occupation`

### 3.1 Why

`Profile.bio`/`Profile.interests` existed as **local-only** fields since
Phase 1 (never sent to or read from Supabase) — an earlier session's Edit
Profile sheet literally had a bio text field wired to nothing, which was
later removed as "more honest than silently discarding input." This pass
restores that UI now that the fields properly round-trip through
`fromJson`/`toInsertJson`/`updateMyProfile`, plus adds `occupation` as a new
field (roadmap mentions education/religion/languages/height/lifestyle/etc.
too — this pass only wires the 3 most immediately visible ones; the rest
are still explicitly out of scope, see §3.4).

### 3.2 Schema

```sql
alter table public.profiles
  add column if not exists bio text,
  add column if not exists interests text[] default '{}',
  add column if not exists occupation text;

-- Optional but recommended: cap bio length to match the client's own cap.
alter table public.profiles
  add constraint profiles_bio_length check (bio is null or char_length(bio) <= 500);
```

(`500` matches `AppConstants.maxBioChars` client-side — keep these in sync
if either changes.)

### 3.3 Wire shape

Already exactly what `Profile.toInsertJson()`/`fromJson()` produce/expect:
```json
{"bio": "Coffee, hiking, and good conversations.", "interests": ["Coffee", "Hiking", "Travel"], "occupation": "Software Engineer"}
```
`interests` is a plain Postgres `text[]`, same pattern as the existing
`hobbies` column — no new type needed.

### 3.4 Client code already wired

- `lib/shared/models/profile.dart` — `bio`/`interests` promoted from
  "local-only" to real fields (round-trip through `fromJson`/
  `toInsertJson`); new `occupation` field added the same way.
- `lib/shared/data/repositories.dart` — `ProfileRepository.updateMyProfile()`
  signature extended with `bio`/`interests`/`occupation` (all optional,
  backward compatible with existing call sites).
- `lib/features/profile/profile_screen.dart` — `_EditProfileSheet`
  REWRITTEN: restores a Bio field (properly wired this time), adds
  Occupation and a comma-separated Interests field (capped at
  `AppConstants.maxInterests`, currently 8). The profile card itself now
  displays occupation/bio/interests when non-empty.
  `lib/shared/widgets/profile_preview_modal.dart` — same 3 fields added to
  the shared profile-detail view other users see.
- **Not wired this pass** (explicitly deferred, not forgotten): education,
  religion, languages, height, lifestyle, smoking, drinking, children, pets
  — the rest of the roadmap's extended-onboarding field list. Confirm with
  product which of these are actually in scope before adding more columns;
  wiring 3 was enough to unblock the "Extended profile fields" B-TIER item
  without guessing at a long tail of fields nobody's confirmed are wanted
  for v1.

**Until these columns exist**, every read/write is a silent no-op exactly
like the rest of this app's graceful-degradation pattern: `fromJson` reads
`null`/empty (already the default), and the `update()` call in
`updateMyProfile` simply patches columns that exist — Postgrest will error
on an unknown column, so **this one is different from the others in this
doc**: unlike `get_country_counts`/`get_discover_profiles` (which are
optional RPCs the client gracefully falls back from), a missing `bio` column
will make `updateMyProfile()` throw when a user tries to save a bio, and the
Edit Profile sheet will show "Could not save — try again." **Recommend
prioritizing this schema change over §1/§2** since its failure mode is a
user-visible save error, not a silent gap.

---

## 4. Optional / lower priority: PostGIS-backed distance

Not requested for this pass, noting for completeness: if geo-ranking
becomes a real requirement (sort Discover by actual distance, not just
display it; filter server-side by radius instead of client-side), that
needs `location_lat`/`location_lng` backed by PostGIS (`geography` column +
`ST_DWithin`/`ST_Distance`) rather than plain `double precision` columns +
client-side Haversine. Out of scope unless product asks for it — the
client-side Haversine in `lib/core/utils/geo_distance.dart` is a reasonable
v1 for "show approximate distance," not for "rank/filter by distance at the
database level."

---

## 5. Summary for planning

Recommended order: **§3 (extended profile columns) first** — it's the only
item whose absence produces a user-visible error rather than a graceful
no-degrade. Then §1 (`get_country_counts`) — cheap, self-contained, directly
replaces client-side work with a faster query. §2 (ranking RPC) last and
only after confirming with product whether real ranking is even wanted for
this release, since building a ranking algorithm without that confirmation
risks wasted work.
